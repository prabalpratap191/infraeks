#!/bin/bash

# Emergency Security Group Fix
# This script manually adds the required security group rule to allow EC2 -> EKS communication

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="meracommerce-dev-cluster"
REGION="us-east-1"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Emergency Security Group Fix${NC}"
echo -e "${BLUE}======================================${NC}"

echo -e "\n${YELLOW}Step 1: Getting cluster security group...${NC}"

CLUSTER_SG=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' \
  --output text 2>/dev/null)

if [ -z "$CLUSTER_SG" ] || [ "$CLUSTER_SG" = "None" ]; then
    echo -e "${RED}ERROR: Could not get cluster security group${NC}"
    echo -e "${YELLOW}Trying alternative method...${NC}"
    
    # Try to get from security group IDs
    CLUSTER_SG=$(aws eks describe-cluster \
      --name "$CLUSTER_NAME" \
      --region "$REGION" \
      --query 'cluster.resourcesVpcConfig.securityGroupIds[0]' \
      --output text 2>/dev/null)
fi

if [ -z "$CLUSTER_SG" ] || [ "$CLUSTER_SG" = "None" ]; then
    echo -e "${RED}ERROR: Still could not find cluster security group${NC}"
    echo -e "${YELLOW}Let's list all security groups for the cluster:${NC}"
    
    aws ec2 describe-security-groups \
      --filters "Name=tag:Name,Values=*$CLUSTER_NAME*" \
      --region "$REGION" \
      --query 'SecurityGroups[*].[GroupId,GroupName,Tags[?Key==`Name`].Value|[0]]' \
      --output table
    
    echo -e "\n${YELLOW}Please select the cluster security group ID and run:${NC}"
    echo -e "${GREEN}export CLUSTER_SG=<security-group-id>${NC}"
    echo -e "${GREEN}Then run this script again.${NC}"
    
    if [ -z "$CLUSTER_SG" ]; then
        exit 1
    fi
fi

echo -e "${GREEN}Cluster Security Group: $CLUSTER_SG${NC}"

echo -e "\n${YELLOW}Step 2: Getting VPC CIDR...${NC}"

VPC_ID=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)

echo -e "${GREEN}VPC ID: $VPC_ID${NC}"

VPC_CIDR=$(aws ec2 describe-vpcs \
  --vpc-ids "$VPC_ID" \
  --region "$REGION" \
  --query 'Vpcs[0].CidrBlock' \
  --output text)

echo -e "${GREEN}VPC CIDR: $VPC_CIDR${NC}"

echo -e "\n${YELLOW}Step 3: Checking existing security group rules...${NC}"

# Check if rule already exists
EXISTING_RULE=$(aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=$CLUSTER_SG" \
  --region "$REGION" \
  --query "SecurityGroupRules[?IpProtocol=='tcp' && FromPort==\`443\` && ToPort==\`443\` && CidrIpv4=='$VPC_CIDR'].SecurityGroupRuleId" \
  --output text)

if [ -n "$EXISTING_RULE" ]; then
    echo -e "${GREEN}✓ Security group rule already exists (Rule ID: $EXISTING_RULE)${NC}"
    echo -e "${YELLOW}But connectivity still fails. Let's check more details...${NC}"
else
    echo -e "${YELLOW}! Security group rule does NOT exist. Adding it now...${NC}"
    
    # Add the security group rule
    aws ec2 authorize-security-group-ingress \
      --group-id "$CLUSTER_SG" \
      --protocol tcp \
      --port 443 \
      --cidr "$VPC_CIDR" \
      --region "$REGION" 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Security group rule added successfully!${NC}"
    else
        echo -e "${YELLOW}Note: Rule might already exist (this is OK)${NC}"
    fi
fi

echo -e "\n${YELLOW}Step 4: Getting current EC2 instance details...${NC}"

EC2_INSTANCE_ID=$(ec2-metadata --instance-id 2>/dev/null | cut -d ' ' -f 2)
EC2_PRIVATE_IP=$(ec2-metadata --local-ipv4 2>/dev/null | cut -d ' ' -f 2)

if [ -n "$EC2_INSTANCE_ID" ]; then
    echo -e "${GREEN}Current EC2 Instance: $EC2_INSTANCE_ID${NC}"
    echo -e "${GREEN}Private IP: $EC2_PRIVATE_IP${NC}"
    
    # Get EC2 security groups
    EC2_SGS=$(aws ec2 describe-instances \
      --instance-ids "$EC2_INSTANCE_ID" \
      --region "$REGION" \
      --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' \
      --output table)
    
    echo -e "\n${YELLOW}EC2 Security Groups:${NC}"
    echo "$EC2_SGS"
    
    # Check outbound rules
    echo -e "\n${YELLOW}Checking EC2 security group outbound rules...${NC}"
    EC2_SG_IDS=$(aws ec2 describe-instances \
      --instance-ids "$EC2_INSTANCE_ID" \
      --region "$REGION" \
      --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
      --output text)
    
    for sg in $EC2_SG_IDS; do
        echo -e "\n${BLUE}Security Group: $sg${NC}"
        aws ec2 describe-security-group-rules \
          --filters "Name=group-id,Values=$sg" "Name=is-egress,Values=true" \
          --region "$REGION" \
          --query 'SecurityGroupRules[*].[IpProtocol,FromPort,ToPort,CidrIpv4]' \
          --output table
    done
fi

echo -e "\n${YELLOW}Step 5: Adding EC2 instance to cluster security group (if needed)...${NC}"

if [ -n "$EC2_INSTANCE_ID" ]; then
    # Get current security groups
    CURRENT_SGS=$(aws ec2 describe-instances \
      --instance-ids "$EC2_INSTANCE_ID" \
      --region "$REGION" \
      --query 'Reservations[0].Instances[0].SecurityGroups[*].GroupId' \
      --output text)
    
    # Check if cluster SG is already attached
    if echo "$CURRENT_SGS" | grep -q "$CLUSTER_SG"; then
        echo -e "${GREEN}✓ EC2 instance already has cluster security group${NC}"
    else
        echo -e "${YELLOW}Adding cluster security group to EC2 instance...${NC}"
        
        # Add cluster SG to EC2 instance
        ALL_SGS="$CURRENT_SGS $CLUSTER_SG"
        
        aws ec2 modify-instance-attribute \
          --instance-id "$EC2_INSTANCE_ID" \
          --groups $ALL_SGS \
          --region "$REGION" 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Cluster security group added to EC2 instance!${NC}"
            echo -e "${YELLOW}This allows the EC2 instance to communicate with the cluster.${NC}"
        else
            echo -e "${RED}Failed to add security group to EC2 instance${NC}"
            echo -e "${YELLOW}You may need to add it manually in AWS Console${NC}"
        fi
    fi
fi

echo -e "\n${YELLOW}Step 6: Testing connectivity to cluster endpoint...${NC}"

CLUSTER_ENDPOINT=$(aws eks describe-cluster \
  --name "$CLUSTER_NAME" \
  --region "$REGION" \
  --query 'cluster.endpoint' \
  --output text)

CLUSTER_HOST=$(echo $CLUSTER_ENDPOINT | sed 's|https://||' | cut -d':' -f1)
CLUSTER_IP=$(dig +short $CLUSTER_HOST | head -1)

echo -e "${GREEN}Cluster Endpoint: $CLUSTER_ENDPOINT${NC}"
echo -e "${GREEN}Cluster Host: $CLUSTER_HOST${NC}"
echo -e "${GREEN}Cluster IP: $CLUSTER_IP${NC}"

echo -e "\n${YELLOW}Testing TCP connectivity to port 443...${NC}"
timeout 5 bash -c "</dev/tcp/$CLUSTER_IP/443" 2>/dev/null && echo -e "${GREEN}✓ Port 443 is reachable!${NC}" || echo -e "${RED}✗ Port 443 is NOT reachable${NC}"

echo -e "\n${YELLOW}Testing with curl...${NC}"
curl -k -m 5 "$CLUSTER_ENDPOINT" 2>&1 | head -5

echo -e "\n${YELLOW}Step 7: Testing kubectl connectivity...${NC}"
kubectl cluster-info 2>&1 | head -10

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}✓ SUCCESS! Cluster is now reachable!${NC}"
    echo -e "${GREEN}======================================${NC}"
    
    echo -e "\n${BLUE}Next steps:${NC}"
    echo -e "1. Test: ${GREEN}kubectl get nodes${NC}"
    echo -e "2. Deploy: ${GREEN}cd .. && terraform apply -var-file=environments/dev.tfvars${NC}"
else
    echo -e "\n${RED}======================================${NC}"
    echo -e "${RED}Still having connectivity issues${NC}"
    echo -e "${RED}======================================${NC}"
    
    echo -e "\n${YELLOW}Diagnosis:${NC}"
    echo "1. Cluster Security Group: $CLUSTER_SG"
    echo "2. VPC CIDR: $VPC_CIDR"
    echo "3. Cluster IP: $CLUSTER_IP"
    echo "4. EC2 Instance: $EC2_INSTANCE_ID"
    echo "5. EC2 Private IP: $EC2_PRIVATE_IP"
    
    echo -e "\n${YELLOW}Possible issues:${NC}"
    echo "1. Network ACLs blocking traffic"
    echo "2. Route table issues"
    echo "3. Subnet configuration"
    echo "4. DNS resolution issues"
    
    echo -e "\n${YELLOW}Manual fixes to try:${NC}"
    echo "1. Check network ACLs:"
    echo "   aws ec2 describe-network-acls --region $REGION"
    echo ""
    echo "2. Add cluster SG to EC2 manually:"
    echo "   AWS Console -> EC2 -> Instances -> $EC2_INSTANCE_ID -> Actions -> Security -> Change Security Groups"
    echo "   Add: $CLUSTER_SG"
    echo ""
    echo "3. Ensure cluster endpoint is public:"
    echo "   aws eks update-cluster-config --name $CLUSTER_NAME --region $REGION --resources-vpc-config endpointPublicAccess=true"
fi

echo -e "\n${BLUE}Complete security group information saved to: sg-debug-info.txt${NC}"

# Save debug info
cat > sg-debug-info.txt << EOF
EKS Connectivity Debug Information
===================================
Date: $(date)

Cluster Information:
-------------------
Cluster Name: $CLUSTER_NAME
Cluster Security Group: $CLUSTER_SG
Cluster Endpoint: $CLUSTER_ENDPOINT
Cluster IP: $CLUSTER_IP
VPC ID: $VPC_ID
VPC CIDR: $VPC_CIDR

EC2 Information:
---------------
Instance ID: $EC2_INSTANCE_ID
Private IP: $EC2_PRIVATE_IP
Security Groups: $CURRENT_SGS

Connectivity Test:
-----------------
$(kubectl cluster-info 2>&1)

Cluster Security Group Rules:
----------------------------
$(aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$CLUSTER_SG" --region $REGION --output table 2>&1)

EC2 Security Group Rules:
------------------------
$(for sg in $EC2_SG_IDS; do echo "\nSecurity Group: $sg"; aws ec2 describe-security-group-rules --filters "Name=group-id,Values=$sg" --region $REGION --output table 2>&1; done)
EOF

echo -e "${BLUE}Debug info saved. Share this file if you need further assistance.${NC}"
