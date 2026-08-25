#!/bin/bash

################################################################################
# EKS Node Group Stuck Diagnosis Script
# Purpose: Diagnose why node group creation is stuck
# Usage: Run this script when node group is stuck in creating state
################################################################################

set -e

CLUSTER_NAME="${1:-meracommerce-dev}"
NODE_GROUP_NAME="${CLUSTER_NAME}-ng"
REGION="${2:-us-east-1}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "EKS Node Group Stuck Diagnosis"
echo "========================================"
echo "Cluster: $CLUSTER_NAME"
echo "Node Group: $NODE_GROUP_NAME"
echo "Region: $REGION"
echo "========================================"
echo ""

################################################################################
# Check 1: Node Group Status
################################################################################
echo "[1/6] Checking node group status..."
NODE_GROUP_STATUS=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODE_GROUP_NAME" \
    --region "$REGION" \
    --query 'nodegroup.{Status:status,Health:health,CreatedAt:createdAt,DesiredSize:scalingConfig.desiredSize}' \
    --output json 2>/dev/null || echo '{}')

if [ "$NODE_GROUP_STATUS" != "{}" ]; then
    echo "$NODE_GROUP_STATUS" | jq .
    
    STATUS=$(echo "$NODE_GROUP_STATUS" | jq -r '.Status // "UNKNOWN"')
    if [ "$STATUS" == "CREATE_FAILED" ]; then
        echo -e "${RED}⚠ Node group is in FAILED state${NC}"
        echo "Getting detailed error..."
        aws eks describe-nodegroup \
            --cluster-name "$CLUSTER_NAME" \
            --nodegroup-name "$NODE_GROUP_NAME" \
            --region "$REGION" \
            --query 'nodegroup.health.issues[]' \
            --output json
    elif [ "$STATUS" == "CREATING" ]; then
        echo -e "${YELLOW}⏳ Still creating (this might indicate a stuck state)${NC}"
    fi
else
    echo -e "${RED}✗ Could not retrieve node group status${NC}"
fi
echo ""

################################################################################
# Check 2: Auto Scaling Group Status
################################################################################
echo "[2/6] Checking Auto Scaling Group..."
ASG_NAME=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODE_GROUP_NAME" \
    --region "$REGION" \
    --query 'nodegroup.resources.autoScalingGroups[0].name' \
    --output text 2>/dev/null || echo "")

if [ -n "$ASG_NAME" ] && [ "$ASG_NAME" != "None" ]; then
    echo -e "${GREEN}✓ ASG found: $ASG_NAME${NC}"
    
    # Get ASG details
    ASG_DETAILS=$(aws autoscaling describe-auto-scaling-groups \
        --auto-scaling-group-names "$ASG_NAME" \
        --region "$REGION" \
        --query 'AutoScalingGroups[0].{DesiredCapacity:DesiredCapacity,MinSize:MinSize,MaxSize:MaxSize,Instances:length(Instances),HealthCheckType:HealthCheckType}' \
        --output json 2>/dev/null)
    
    echo "ASG Configuration:"
    echo "$ASG_DETAILS" | jq .
    
    # Get instance count
    INSTANCE_COUNT=$(echo "$ASG_DETAILS" | jq -r '.Instances // 0')
    DESIRED=$(echo "$ASG_DETAILS" | jq -r '.DesiredCapacity // 0')
    
    if [ "$INSTANCE_COUNT" -lt "$DESIRED" ]; then
        echo -e "${YELLOW}⚠ ASG has $INSTANCE_COUNT instances but wants $DESIRED${NC}"
    fi
    
    # Get recent ASG activities
    echo ""
    echo "Recent ASG Activities (last 10):"
    aws autoscaling describe-scaling-activities \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$REGION" \
        --max-records 10 \
        --query 'Activities[].{Time:StartTime,Status:StatusCode,Cause:Cause,Description:Description}' \
        --output table
else
    echo -e "${RED}✗ No ASG found for node group${NC}"
fi
echo ""

################################################################################
# Check 3: EC2 Instances
################################################################################
echo "[3/6] Checking EC2 instances..."
INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query 'AutoScalingGroups[0].Instances[].{InstanceId:InstanceId,HealthStatus:HealthStatus,LifecycleState:LifecycleState}' \
    --output json 2>/dev/null || echo '[]')

if [ "$INSTANCES" != "[]" ] && [ -n "$INSTANCES" ]; then
    echo "Instances in ASG:"
    echo "$INSTANCES" | jq .
    
    # Get instance IDs
    INSTANCE_IDS=$(echo "$INSTANCES" | jq -r '.[].InstanceId' | tr '\n' ' ')
    
    if [ -n "$INSTANCE_IDS" ]; then
        echo ""
        echo "EC2 Instance Details:"
        aws ec2 describe-instances \
            --instance-ids $INSTANCE_IDS \
            --region "$REGION" \
            --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,StateReason:StateReason.Message,LaunchTime:LaunchTime,InstanceType:InstanceType}' \
            --output table
    fi
else
    echo -e "${RED}✗ No instances found in ASG${NC}"
    echo "This indicates instances are failing to launch!"
fi
echo ""

################################################################################
# Check 4: CloudWatch Logs
################################################################################
echo "[4/6] Checking CloudWatch logs for errors..."
LOG_GROUP="/aws/eks/${CLUSTER_NAME}/cluster"

# Check if log group exists
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --region "$REGION" | grep -q "$LOG_GROUP"; then
    echo "Recent logs (last 30 minutes):"
    aws logs tail "$LOG_GROUP" \
        --since 30m \
        --format short \
        --region "$REGION" \
        2>/dev/null | tail -20
else
    echo "Log group not found or not accessible"
fi
echo ""

################################################################################
# Check 5: Subnet Capacity
################################################################################
echo "[5/6] Checking subnet IP availability..."
SUBNETS=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODE_GROUP_NAME" \
    --region "$REGION" \
    --query 'nodegroup.subnets[]' \
    --output text 2>/dev/null || echo "")

if [ -n "$SUBNETS" ]; then
    for subnet in $SUBNETS; do
        SUBNET_INFO=$(aws ec2 describe-subnets \
            --subnet-ids "$subnet" \
            --region "$REGION" \
            --query 'Subnets[0].{SubnetId:SubnetId,AZ:AvailabilityZone,AvailableIPs:AvailableIpAddressCount,State:State}' \
            --output json 2>/dev/null)
        
        if [ -n "$SUBNET_INFO" ]; then
            AVAILABLE_IPS=$(echo "$SUBNET_INFO" | jq -r '.AvailableIPs // 0')
            AZ=$(echo "$SUBNET_INFO" | jq -r '.AZ // "unknown"')
            
            if [ "$AVAILABLE_IPS" -lt 5 ]; then
                echo -e "${RED}✗ $subnet ($AZ): Only $AVAILABLE_IPS IPs available${NC}"
            else
                echo -e "${GREEN}✓ $subnet ($AZ): $AVAILABLE_IPS IPs available${NC}"
            fi
        fi
    done
else
    echo "Could not retrieve subnet information"
fi
echo ""

################################################################################
# Check 6: Security Group Rules
################################################################################
echo "[6/6] Checking security groups..."
SG_IDS=$(aws eks describe-nodegroup \
    --cluster-name "$CLUSTER_NAME" \
    --nodegroup-name "$NODE_GROUP_NAME" \
    --region "$REGION" \
    --query 'nodegroup.resources.remoteAccessSecurityGroup' \
    --output text 2>/dev/null || echo "")

if [ -n "$SG_IDS" ] && [ "$SG_IDS" != "None" ]; then
    echo "Security Group: $SG_IDS"
    aws ec2 describe-security-groups \
        --group-ids "$SG_IDS" \
        --region "$REGION" \
        --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,InboundRules:length(IpPermissions),OutboundRules:length(IpPermissionsEgress)}' \
        --output table 2>/dev/null || echo "Could not retrieve security group details"
else
    echo "Using cluster-managed security group"
fi
echo ""

################################################################################
# Recommendations
################################################################################
echo "========================================"
echo "DIAGNOSIS COMPLETE"
echo "========================================"
echo ""
echo -e "${YELLOW}COMMON CAUSES FOR STUCK NODE GROUPS:${NC}"
echo "1. Insufficient subnet IP addresses"
echo "2. Instance type not available in AZ"
echo "3. Service limits/quotas exceeded"
echo "4. IMDSv2 configuration issues (http_tokens=required)"
echo "5. Security group blocking required traffic"
echo "6. Launch template issues"
echo ""
echo -e "${YELLOW}IMMEDIATE ACTIONS:${NC}"
echo "1. If stuck for >30 minutes, cancel deployment:"
echo "   Ctrl+C in Terraform terminal"
echo ""
echo "2. Delete the failed node group:"
echo "   aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP_NAME --region $REGION"
echo ""
echo "3. Check if our fixes were applied:"
echo "   grep 'http_tokens.*optional' terraform/modules/eks/main.tf"
echo ""
echo "4. Try alternative instance type in terraform/meracommerce-dev.tfvars:"
echo "   node_instance_type = \"t3a.medium\"  # or t3.small"
echo ""
echo "5. Re-run deployment after cleanup"
echo ""
