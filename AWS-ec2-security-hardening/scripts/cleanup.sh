#!/bin/bash

# AWS EC2 Security Project - Cleanup Script
# This script cleans up all AWS resources created by the project

set -euo pipefail

# Configuration
PROJECT_NAME="ec2-security"
REGION="us-east-1"
LOG_FILE="/tmp/cleanup-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $message" >> "$LOG_FILE"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $message" >> "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ERROR]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $message" >> "$LOG_FILE"
}

log_step() {
    local message="$1"
    echo -e "${BLUE}[STEP]${NC} $message"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] STEP: $message" >> "$LOG_FILE"
}

# Confirmation prompt
confirm_cleanup() {
    echo -e "${RED}⚠️  WARNING: This will permanently delete all AWS resources created by this project!${NC}"
    echo -e "${RED}This action cannot be undone.${NC}"
    echo
    read -p "Are you sure you want to continue? (Type 'DELETE' to confirm): " -r
    echo
    if [[ "$REPLY" != "DELETE" ]]; then
        log_info "Cleanup cancelled by user."
        exit 0
    fi
}

# Check AWS CLI
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI is not configured."
        exit 1
    fi
}

# Delete EC2 instances
delete_instances() {
    log_step "Deleting EC2 instances..."
    
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Project,Values=AWS-EC2-Security" \
        --query "Reservations[*].Instances[*].InstanceId" \
        --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$instances" ]; then
        for instance_id in $instances; do
            log_info "Terminating instance: $instance_id"
            aws ec2 terminate-instances \
                --instance-ids "$instance_id" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
            
            # Wait for instance to terminate
            aws ec2 wait instance-terminated \
                --instance-ids "$instance_id" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
            
            log_info "Instance $instance_id terminated"
        done
    else
        log_info "No instances found with project tag"
    fi
}

# Delete key pairs
delete_key_pairs() {
    log_step "Deleting key pairs..."
    
    local key_pairs=$(aws ec2 describe-key-pairs \
        --filters "Name=tag:Project,Values=AWS-EC2-Security" \
        --query "KeyPairs[*].KeyName" \
        --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$key_pairs" ]; then
        for key_name in $key_pairs; do
            log_info "Deleting key pair: $key_name"
            aws ec2 delete-key-pair \
                --key-name "$key_name" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
        done
    else
        log_info "No key pairs found with project tag"
    fi
    
    # Also delete default key if it exists
    if aws ec2 describe-key-pairs --key-names "ec2-security-key" --region "$REGION" &>/dev/null; then
        log_info "Deleting default key pair: ec2-security-key"
        aws ec2 delete-key-pair --key-name "ec2-security-key" --region "$REGION" >> "$LOG_FILE" 2>&1
    fi
}

# Delete security groups
delete_security_groups() {
    log_step "Deleting security groups..."
    
    local security_groups=$(aws ec2 describe-security-groups \
        --filters "Name=tag:Project,Values=AWS-EC2-Security" \
        --query "SecurityGroups[*].GroupId" \
        --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$security_groups" ]; then
        for sg_id in $security_groups; do
            log_info "Deleting security group: $sg_id"
            aws ec2 delete-security-group \
                --group-id "$sg_id" \
                --region "$REGION" >> "$LOG_FILE" 2>&1 || true
        done
    else
        log_info "No security groups found with project tag"
    fi
}

# Delete VPC and related resources
delete_vpc_resources() {
    log_step "Deleting VPC resources..."
    
    # Get VPC ID
    local vpc_id=$(aws ec2 describe-vpcs \
        --filters "Name=tag:Project,Values=AWS-EC2-Security" \
        --query "Vpcs[0].VpcId" \
        --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$vpc_id" ] && [ "$vpc_id" != "None" ]; then
        log_info "Deleting VPC resources for: $vpc_id"
        
        # Delete subnets
        local subnets=$(aws ec2 describe-subnets \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query "Subnets[*].SubnetId" \
            --output text --region "$REGION" 2>/dev/null || true)
        
        if [ -n "$subnets" ]; then
            for subnet_id in $subnets; do
                log_info "Deleting subnet: $subnet_id"
                aws ec2 delete-subnet \
                    --subnet-id "$subnet_id" \
                    --region "$REGION" >> "$LOG_FILE" 2>&1 || true
            done
        fi
        
        # Delete route tables
        local route_tables=$(aws ec2 describe-route-tables \
            --filters "Name=vpc-id,Values=$vpc_id" \
            --query "RouteTables[?!(Associations[0].Main)].RouteTableId" \
            --output text --region "$REGION" 2>/dev/null || true)
        
        if [ -n "$route_tables" ]; then
            for rt_id in $route_tables; do
                log_info "Deleting route table: $rt_id"
                aws ec2 delete-route-table \
                    --route-table-id "$rt_id" \
                    --region "$REGION" >> "$LOG_FILE" 2>&1 || true
            done
        fi
        
        # Delete internet gateway
        local igw_id=$(aws ec2 describe-internet-gateways \
            --filters "Name=attachment.vpc-id,Values=$vpc_id" \
            --query "InternetGateways[*].InternetGatewayId" \
            --output text --region "$REGION" 2>/dev/null || true)
        
        if [ -n "$igw_id" ]; then
            log_info "Detaching and deleting internet gateway: $igw_id"
            aws ec2 detach-internet-gateway \
                --internet-gateway-id "$igw_id" \
                --vpc-id "$vpc_id" \
                --region "$REGION" >> "$LOG_FILE" 2>&1 || true
            
            aws ec2 delete-internet-gateway \
                --internet-gateway-id "$igw_id" \
                --region "$REGION" >> "$LOG_FILE" 2>&1 || true
        fi
        
        # Delete VPC
        log_info "Deleting VPC: $vpc_id"
        aws ec2 delete-vpc \
            --vpc-id "$vpc_id" \
            --region "$REGION" >> "$LOG_FILE" 2>&1 || true
        
    else
        log_info "No VPC found with project tag"
    fi
}

# Delete CloudWatch alarms
delete_cloudwatch_alarms() {
    log_step "Deleting CloudWatch alarms..."
    
    local alarms=$(aws cloudwatch describe-alarms \
        --alarm-name-prefix "EC2-Security" \
        --query "MetricAlarms[*].AlarmName" \
        --output text --region "$REGION" 2>/dev/null || true)
    
    if [ -n "$alarms" ]; then
        for alarm_name in $alarms; do
            log_info "Deleting CloudWatch alarm: $alarm_name"
            aws cloudwatch delete-alarms \
                --alarm-names "$alarm_name" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
        done
    else
        log_info "No CloudWatch alarms found"
    fi
    
    # Also delete CPU alarm if it exists
    if aws cloudwatch describe-alarms --alarm-names "ec2-security-cpu-high" --region "$REGION" &>/dev/null; then
        log_info "Deleting CPU alarm: ec2-security-cpu-high"
        aws cloudwatch delete-alarms --alarm-names "ec2-security-cpu-high" --region "$REGION" >> "$LOG_FILE" 2>&1
    fi
}

# Delete SNS topics
delete_sns_topics() {
    log_step "Deleting SNS topics..."
    
    local topics=$(aws sns list-topics \
        --region "$REGION" \
        --query "Topics[?contains(TopicArn, \`ec2-security\`)].TopicArn" \
        --output text 2>/dev/null || true)
    
    if [ -n "$topics" ]; then
        for topic_arn in $topics; do
            log_info "Deleting SNS topic: $topic_arn"
            aws sns delete-topic \
                --topic-arn "$topic_arn" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
        done
    else
        log_info "No SNS topics found"
    fi
}

# Delete CloudWatch dashboards
delete_dashboards() {
    log_step "Deleting CloudWatch dashboards..."
    
    local dashboards=$(aws cloudwatch list-dashboards \
        --region "$REGION" \
        --query "DashboardEntries[?contains(DashboardName, \`EC2-Security\`)].DashboardName" \
        --output text 2>/dev/null || true)
    
    if [ -n "$dashboards" ]; then
        for dashboard_name in $dashboards; do
            log_info "Deleting CloudWatch dashboard: $dashboard_name"
            aws cloudwatch delete-dashboards \
                --dashboard-names "$dashboard_name" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
        done
    else
        log_info "No CloudWatch dashboards found"
    fi
}

# Delete CloudWatch log groups
delete_log_groups() {
    log_step "Deleting CloudWatch log groups..."
    
    local log_groups=$(aws logs describe-log-groups \
        --log-group-name-prefix "/ec2-security" \
        --region "$REGION" \
        --query "logGroups[*].logGroupName" \
        --output text 2>/dev/null || true)
    
    if [ -n "$log_groups" ]; then
        for log_group in $log_groups; do
            log_info "Deleting log group: $log_group"
            aws logs delete-log-group \
                --log-group-name "$log_group" \
                --region "$REGION" >> "$LOG_FILE" 2>&1
        done
    else
        log_info "No CloudWatch log groups found"
    fi
}

# Clean up local files
cleanup_local_files() {
    log_step "Cleaning up local files..."
    
    # Remove key files
    if [ -f "ec2-security-key.pem" ]; then
        log_info "Removing local key file: ec2-security-key.pem"
        rm -f "ec2-security-key.pem"
    fi
    
    # Remove backup keys
    if [ -d "$HOME/.ssh/backups" ]; then
        log_info "Removing backup keys from $HOME/.ssh/backups"
        rm -rf "$HOME/.ssh/backups"
    fi
    
    # Remove any local key files with project name
    find "$HOME/.ssh" -name "*ec2-security*" -type f -delete 2>/dev/null || true
    
    log_info "Local files cleaned up"
}

# Generate cleanup report
generate_cleanup_report() {
    log_step "Generating cleanup report..."
    
    local report_file="/tmp/cleanup-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
AWS EC2 Security Project Cleanup Report
========================================
Generated: $(date)
Region: $REGION

========================================
Resources Deleted
========================================
✓ EC2 instances with project tags
✓ SSH key pairs
✓ Security groups
✓ VPC resources (VPC, subnets, route tables, internet gateways)
✓ CloudWatch alarms
✓ SNS topics
✓ CloudWatch dashboards
✓ CloudWatch log groups
✓ Local key files and backups

========================================
Cleanup Verification
========================================
To verify cleanup was successful, run:

aws ec2 describe-instances --filters "Name=tag:Project,Values=AWS-EC2-Security" --region $REGION
aws ec2 describe-key-pairs --filters "Name=tag:Project,Values=AWS-EC2-Security" --region $REGION
aws cloudwatch describe-alarms --alarm-name-prefix "EC2-Security" --region $REGION
aws sns list-topics --region $REGION

========================================
Notes
========================================
- Some resources may take a few minutes to be fully deleted
- Check your AWS console to confirm all resources are removed
- Local key files have been removed for security
- Log file for this cleanup: $LOG_FILE

========================================
EOF

    log_info "Cleanup report created: $report_file"
    echo
    log_info "Cleanup completed successfully!"
    log_info "Report saved to: $report_file"
}

# Main execution
main() {
    log_info "Starting AWS EC2 Security Project cleanup..."
    
    # Initial checks
    check_aws_cli
    confirm_cleanup
    
    # Delete resources in order (dependencies first)
    delete_instances
    delete_cloudwatch_alarms
    delete_dashboards
    delete_log_groups
    delete_sns_topics
    delete_security_groups
    delete_vpc_resources
    delete_key_pairs
    
    # Clean up local files
    cleanup_local_files
    
    # Generate report
    generate_cleanup_report
}

# Run main function
main "$@"
