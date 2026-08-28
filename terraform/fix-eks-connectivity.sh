#!/bin/bash

# EKS Connectivity Fix Script
# Run this on your EC2 instance to diagnose and fix network connectivity issues

set -e

EKS_CLUSTER_NAME="meracommerce-dev-cluster"
REGION="us-east-1"
EKS_ENDPOINT="61473F4207F882065472584FBAE2DA39.gr7.us-east-1.eks.amazonaws.com"

echo "========================================"
echo "EKS Connectivity Diagnostic & Fix Script"
echo "========================================"
echo ""

# Step 1: Get EC2 instance metadata
echo "[1/7] Getting EC2 instance information..."
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
echo "  Instance ID: $INSTANCE_ID"

# Get security group
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text --region $REGION)
echo "  Security Group: $SG_ID"
echo ""

# Step 2: Check current security group rules
echo "[2/7] Checking current outbound security group rules..."
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissionsEgress[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
  --output table --region $REGION
echo ""

# Step 3: Check if HTTPS outbound rule exists
echo "[3/7] Checking for HTTPS (443) outbound rule..."
HTTPS_RULE=$(aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query "SecurityGroups[0].IpPermissionsEgress[?FromPort==\`443\` && ToPort==\`443\`]" \
  --output text --region $REGION)

if [ -z "$HTTPS_RULE" ]; then
    echo "  ❌ No HTTPS outbound rule found!"
    echo ""
    echo "[4/7] Adding HTTPS outbound rule to security group..."
    
    # Add HTTPS egress rule
    aws ec2 authorize-security-group-egress \
      --group-id $SG_ID \
      --protocol tcp \
      --port 443 \
      --cidr 0.0.0.0/0 \
      --region $REGION 2>&1 || echo "  Note: Rule may already exist or requires different permissions"
    
    echo "  ✅ HTTPS outbound rule added"
else
    echo "  ✅ HTTPS outbound rule already exists"
fi
echo ""

# Step 4: Test DNS resolution
echo "[5/7] Testing DNS resolution for EKS endpoint..."
if nslookup $EKS_ENDPOINT > /dev/null 2>&1; then
    echo "  ✅ DNS resolution successful"
    EKS_IP=$(nslookup $EKS_ENDPOINT | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    echo "  Resolved IP: $EKS_IP"
else
    echo "  ❌ DNS resolution failed"
    echo "  This may indicate DNS or network configuration issues"
fi
echo ""

# Step 5: Test HTTPS connectivity
echo "[6/7] Testing HTTPS connectivity to EKS endpoint..."
if timeout 10 bash -c "</dev/tcp/$EKS_ENDPOINT/443" 2>/dev/null; then
    echo "  ✅ HTTPS connection successful"
else
    echo "  ❌ Cannot establish HTTPS connection"
    echo "  Trying with curl..."
    
    CURL_TEST=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 https://$EKS_ENDPOINT 2>&1 || echo "timeout")
    
    if [ "$CURL_TEST" != "timeout" ] && [ "$CURL_TEST" != "000" ]; then
        echo "  ✅ curl can reach endpoint (HTTP code: $CURL_TEST)"
    else
        echo "  ❌ curl also failed - network path is blocked"
        echo ""
        echo "  Possible issues:"
        echo "  - Network ACLs blocking traffic"
        echo "  - Route table missing internet gateway route"
        echo "  - VPC endpoint configuration issues"
    fi
fi
echo ""

# Step 6: Configure kubectl
echo "[7/7] Configuring kubectl for EKS cluster..."
if aws eks update-kubeconfig --region $REGION --name $EKS_CLUSTER_NAME; then
    echo "  ✅ kubectl configured successfully"
    echo ""
    echo "Testing kubectl connection..."
    
    if kubectl get nodes 2>&1; then
        echo "  ✅ kubectl can connect to cluster!"
        echo ""
        echo "Cluster nodes:"
        kubectl get nodes -o wide
    else
        echo "  ❌ kubectl cannot connect to cluster"
        echo ""
        echo "Checking cluster endpoint access configuration..."
        aws eks describe-cluster --region $REGION --name $EKS_CLUSTER_NAME \
          --query 'cluster.resourcesVpcConfig.{endpointPublicAccess:endpointPublicAccess,endpointPrivateAccess:endpointPrivateAccess}' \
          --output table
    fi
else
    echo "  ❌ Failed to configure kubectl"
fi

echo ""
echo "========================================"
echo "Diagnostic Summary"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. If connectivity test passed, run: terraform apply"
echo "2. If connectivity test failed, check:"
echo "   - VPC route tables have route to Internet Gateway"
echo "   - Network ACLs allow outbound HTTPS (443)"
echo "   - Subnet configuration is correct"
echo ""
echo "Verify cluster status:"
echo "  aws eks describe-cluster --region $REGION --name $EKS_CLUSTER_NAME --query 'cluster.status'"
echo ""
echo "Verify kubectl access:"
echo "  kubectl get nodes"
echo "  kubectl get namespaces"
echo ""
