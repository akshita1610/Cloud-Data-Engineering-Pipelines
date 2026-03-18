#!/bin/bash

# AWS EC2 Security Project - Setup Script
# This script automates the setup of a secure EC2 instance

set -euo pipefail

# Configuration
REGION="us-east-1"
INSTANCE_TYPE="t2.micro"
AMI_ID="ami-0c55b159cbfafe1f0"  # Amazon Linux 2
KEY_NAME="ec2-security-key"
SECURITY_GROUP_NAME="ec2-security-sg"
INSTANCE_NAME="ec2-security-instance"
VPC_CIDR="10.0.0.0/16"
SUBNET_CIDR="10.0.1.0/24"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed and configured
check_aws_cli() {
    log_info "Checking AWS CLI installation and configuration..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    log_info "AWS CLI is properly configured."
}

# Get current public IP
get_current_ip() {
    log_info "Getting current public IP address..."
    CURRENT_IP=$(curl -s https://checkip.amazonaws.com)
    if [ -z "$CURRENT_IP" ]; then
        log_error "Failed to get current IP address."
        exit 1
    fi
    log_info "Current IP: $CURRENT_IP"
}

# Create VPC
create_vpc() {
    log_info "Creating VPC..."
    
    VPC_ID=$(aws ec2 create-vpc \
        --cidr-block "$VPC_CIDR" \
        --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=$INSTANCE_NAME-vpc},{Key=Project,Value=AWS-EC2-Security}]" \
        --query "Vpc.VpcId" \
        --output text)
    
    log_info "VPC created with ID: $VPC_ID"
    
    # Enable DNS hostnames and support
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames "{\"Value\":true}"
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support "{\"Value\":true}"
    
    echo "$VPC_ID"
}

# Create Internet Gateway
create_internet_gateway() {
    local vpc_id=$1
    log_info "Creating Internet Gateway..."
    
    IGW_ID=$(aws ec2 create-internet-gateway \
        --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=$INSTANCE_NAME-igw},{Key=Project,Value=AWS-EC2-Security}]" \
        --query "InternetGateway.InternetGatewayId" \
        --output text)
    
    aws ec2 attach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$vpc_id"
    
    log_info "Internet Gateway created with ID: $IGW_ID"
    echo "$IGW_ID"
}

# Create Subnet
create_subnet() {
    local vpc_id=$1
    log_info "Creating Subnet..."
    
    SUBNET_ID=$(aws ec2 create-subnet \
        --vpc-id "$vpc_id" \
        --cidr-block "$SUBNET_CIDR" \
        --availability-zone "$REGION"a \
        --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=$INSTANCE_NAME-subnet},{Key=Project,Value=AWS-EC2-Security}]" \
        --query "Subnet.SubnetId" \
        --output text)
    
    # Enable public IP assignment
    aws ec2 modify-subnet-attribute --subnet-id "$SUBNET_ID" --map-public-ip-on-launch "{\"Value\":true}"
    
    log_info "Subnet created with ID: $SUBNET_ID"
    echo "$SUBNET_ID"
}

# Create Route Table
create_route_table() {
    local vpc_id=$1
    local igw_id=$2
    local subnet_id=$3
    log_info "Creating Route Table..."
    
    RT_ID=$(aws ec2 create-route-table \
        --vpc-id "$vpc_id" \
        --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=$INSTANCE_NAME-rt},{Key=Project,Value=AWS-EC2-Security}]" \
        --query "RouteTable.RouteTableId" \
        --output text)
    
    # Add route to Internet Gateway
    aws ec2 create-route \
        --route-table-id "$RT_ID" \
        --destination-cidr-block "0.0.0.0/0" \
        --gateway-id "$igw_id"
    
    # Associate route table with subnet
    aws ec2 associate-route-table \
        --route-table-id "$RT_ID" \
        --subnet-id "$subnet_id"
    
    log_info "Route Table created with ID: $RT_ID"
}

# Create Key Pair
create_key_pair() {
    log_info "Creating Key Pair..."
    
    if [ -f "$KEY_NAME.pem" ]; then
        log_warn "Key pair file $KEY_NAME.pem already exists. Skipping key pair creation."
        return
    fi
    
    # Create private key file
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query "KeyMaterial" \
        --output text > "$KEY_NAME.pem"
    
    chmod 400 "$KEY_NAME.pem"
    
    log_info "Key pair created: $KEY_NAME.pem"
    log_warn "Please keep this key file secure!"
}

# Create Security Group
create_security_group() {
    local vpc_id=$1
    log_info "Creating Security Group..."
    
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for EC2 instance with SSH access restricted to current IP" \
        --vpc-id "$vpc_id" \
        --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=$SECURITY_GROUP_NAME},{Key=Project,Value=AWS-EC2-Security}]" \
        --query "GroupId" \
        --output text)
    
    # Add SSH rule for current IP only
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr "$CURRENT_IP/32" \
        --description "SSH access from current IP"
    
    # Add HTTP rule (optional)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 80 \
        --cidr "0.0.0.0/0" \
        --description "HTTP access from anywhere"
    
    # Add HTTPS rule (optional)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 443 \
        --cidr "0.0.0.0/0" \
        --description "HTTPS access from anywhere"
    
    log_info "Security Group created with ID: $SG_ID"
    echo "$SG_ID"
}

# Launch EC2 Instance
launch_instance() {
    local subnet_id=$1
    local sg_id=$2
    log_info "Launching EC2 Instance..."
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$sg_id" \
        --subnet-id "$subnet_id" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=AWS-EC2-Security}]" \
        --block-device-mappings "[{\"DeviceName\":\"/dev/xvda\",\"Ebs\":{\"VolumeSize\":20,\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true,\"Encrypted\":true}}]" \
        --query "Instances[0].InstanceId" \
        --output text)
    
    log_info "Instance launched with ID: $INSTANCE_ID"
    log_info "Waiting for instance to be in running state..."
    
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    
    # Get instance details
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].PublicIpAddress" \
        --output text)
    
    PUBLIC_DNS=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query "Reservations[0].Instances[0].PublicDnsName" \
        --output text)
    
    log_info "Instance is running!"
    log_info "Public IP: $PUBLIC_IP"
    log_info "Public DNS: $PUBLIC_DNS"
    
    echo "$INSTANCE_ID:$PUBLIC_IP:$PUBLIC_DNS"
}

# Create CloudWatch Alarm
create_cloudwatch_alarm() {
    local instance_id=$1
    log_info "Creating CloudWatch alarm for CPU utilization..."
    
    # Create SNS topic for alerts
    SNS_TOPIC_ARN=$(aws sns create-topic \
        --name "ec2-security-alerts" \
        --query "TopicArn" \
        --output text)
    
    # Create CloudWatch alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "ec2-security-cpu-high" \
        --alarm-description "Alarm when CPU exceeds 80%" \
        --metric-name CPUUtilization \
        --namespace AWS/EC2 \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 2 \
        --alarm-actions "$SNS_TOPIC_ARN" \
        --dimensions Name=InstanceId,Value="$instance_id" \
        --unit Percent
    
    log_info "CloudWatch alarm created successfully"
    log_info "SNS Topic ARN: $SNS_TOPIC_ARN"
}

# Main execution
main() {
    log_info "Starting AWS EC2 Security Project setup..."
    
    check_aws_cli
    get_current_ip
    
    # Create infrastructure
    VPC_ID=$(create_vpc)
    IGW_ID=$(create_internet_gateway "$VPC_ID")
    SUBNET_ID=$(create_subnet "$VPC_ID")
    create_route_table "$VPC_ID" "$IGW_ID" "$SUBNET_ID"
    
    # Create security components
    create_key_pair
    SG_ID=$(create_security_group "$VPC_ID")
    
    # Launch instance
    INSTANCE_DETAILS=$(launch_instance "$SUBNET_ID" "$SG_ID")
    INSTANCE_ID=$(echo "$INSTANCE_DETAILS" | cut -d: -f1)
    PUBLIC_IP=$(echo "$INSTANCE_DETAILS" | cut -d: -f2)
    PUBLIC_DNS=$(echo "$INSTANCE_DETAILS" | cut -d: -f3)
    
    # Set up monitoring
    create_cloudwatch_alarm "$INSTANCE_ID"
    
    log_info "Setup completed successfully!"
    echo
    log_info "=== Connection Details ==="
    log_info "SSH Command: ssh -i \"$KEY_NAME.pem\" ec2-user@$PUBLIC_DNS"
    log_info "Instance ID: $INSTANCE_ID"
    log_info "Public IP: $PUBLIC_IP"
    log_info "Public DNS: $PUBLIC_DNS"
    echo
    log_info "=== Next Steps ==="
    log_info "1. Connect to the instance using the SSH command above"
    log_info "2. Run the hardening script: ./harden.sh"
    log_info "3. Set up monitoring: ./monitor.sh"
}

# Run main function
main "$@"
