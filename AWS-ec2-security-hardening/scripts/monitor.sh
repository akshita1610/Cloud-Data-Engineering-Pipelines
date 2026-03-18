#!/bin/bash

# AWS EC2 Security Project - Monitoring Setup Script
# This script sets up comprehensive monitoring for EC2 instances

set -euo pipefail

# Configuration
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')
NAMESPACE="EC2-Security-Metrics"
ALARM_PREFIX="EC2-Security"
SNS_TOPIC_NAME="ec2-security-alerts"
LOG_FILE="/var/log/monitoring-setup.log"

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

# Check if AWS CLI is available
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    log_info "AWS CLI found: $(aws --version)"
}

# Install CloudWatch agent
install_cloudwatch_agent() {
    log_step "Installing CloudWatch agent..."
    
    # Detect OS and install accordingly
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    fi
    
    if [[ "$OS" == *"Amazon Linux"* ]] || [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
        # Amazon Linux/CentOS/RHEL
        yum install -y amazon-cloudwatch-agent >> "$LOG_FILE" 2>&1
    elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        # Ubuntu/Debian
        wget -O /tmp/amazon-cloudwatch-agent.deb https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb >> "$LOG_FILE" 2>&1
        dpkg -i /tmp/amazon-cloudwatch-agent.deb >> "$LOG_FILE" 2>&1
        rm -f /tmp/amazon-cloudwatch-agent.deb
    else
        log_warn "Unsupported OS for automatic CloudWatch agent installation"
        return
    fi
    
    log_info "CloudWatch agent installed successfully"
}

# Configure CloudWatch agent
configure_cloudwatch_agent() {
    log_step "Configuring CloudWatch agent..."
    
    # Create CloudWatch agent configuration
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "CWAgent",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            },
            "net": {
                "measurement": [
                    "bytes_sent",
                    "bytes_recv",
                    "packets_sent",
                    "packets_recv"
                ],
                "metrics_collection_interval": 60
            },
            "netstat": {
                "measurement": [
                    "tcp_connections",
                    "tcp_established",
                    "tcp_time_wait"
                ],
                "metrics_collection_interval": 60
            },
            "processes": {
                "measurement": [
                    "running",
                    "sleeping",
                    "dead"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/ec2-security/auth",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/auth.log",
                        "log_group_name": "/ec2-security/auth",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/ec2-security/system",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/syslog",
                        "log_group_name": "/ec2-security/system",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    },
                    {
                        "file_path": "/var/log/audit/audit.log",
                        "log_group_name": "/ec2-security/audit",
                        "log_stream_name": "{instance_id}",
                        "timezone": "UTC"
                    }
                ]
            }
        }
    }
}
EOF

    # Start CloudWatch agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s >> "$LOG_FILE" 2>&1
    
    log_info "CloudWatch agent configured and started"
}

# Create SNS topic for alerts
create_sns_topic() {
    log_step "Creating SNS topic for alerts..."
    
    # Check if topic already exists
    if aws sns list-topics --region "$REGION" | grep -q "$SNS_TOPIC_NAME"; then
        log_warn "SNS topic $SNS_TOPIC_NAME already exists"
        SNS_TOPIC_ARN=$(aws sns list-topics --region "$REGION" --query "Topics[?contains(TopicArn, \`$SNS_TOPIC_NAME\`)].TopicArn" --output text)
    else
        SNS_TOPIC_ARN=$(aws sns create-topic \
            --name "$SNS_TOPIC_NAME" \
            --region "$REGION" \
            --query "TopicArn" \
            --output text)
        
        log_info "SNS topic created: $SNS_TOPIC_ARN"
    fi
    
    echo "$SNS_TOPIC_ARN"
}

# Create CloudWatch alarms
create_cloudwatch_alarms() {
    local sns_topic_arn=$1
    log_step "Creating CloudWatch alarms..."
    
    # CPU Utilization Alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "${ALARM_PREFIX}-CPU-High" \
        --alarm-description "EC2 instance CPU utilization is above 80%" \
        --metric-name CPUUtilization \
        --namespace "AWS/EC2" \
        --statistic Average \
        --period 300 \
        --threshold 80 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 2 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --unit Percent \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    # Memory Utilization Alarm (if CloudWatch agent is running)
    aws cloudwatch put-metric-alarm \
        --alarm-name "${ALARM_PREFIX}-Memory-High" \
        --alarm-description "EC2 instance memory utilization is above 90%" \
        --metric-name mem_used_percent \
        --namespace "CWAgent" \
        --statistic Average \
        --period 300 \
        --threshold 90 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 2 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --unit Percent \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    # Disk Utilization Alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "${ALARM_PREFIX}-Disk-High" \
        --alarm-description "EC2 instance disk utilization is above 85%" \
        --metric-name used_percent \
        --namespace "CWAgent" \
        --statistic Average \
        --period 300 \
        --threshold 85 \
        --comparison-operator GreaterThanThreshold \
        --evaluation-periods 2 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID",Name=Device,Value="/" \
        --unit Percent \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    # Status Check Failed Alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "${ALARM_PREFIX}-Status-Check-Failed" \
        --alarm-description "EC2 instance status check failed" \
        --metric-name StatusCheckFailed \
        --namespace "AWS/EC2" \
        --statistic Average \
        --period 300 \
        --threshold 1 \
        --comparison-operator GreaterThanOrEqualToThreshold \
        --evaluation-periods 1 \
        --alarm-actions "$sns_topic_arn" \
        --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    log_info "CloudWatch alarms created successfully"
}

# Create custom metrics
create_custom_metrics() {
    log_step "Setting up custom metrics..."
    
    # Create script for custom metrics
    cat > /usr/local/bin/custom-metrics.sh << 'EOF'
#!/bin/bash

# Custom metrics script for EC2 security monitoring
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

# Function to publish custom metric
publish_metric() {
    local metric_name=$1
    local value=$2
    local unit=$3
    
    aws cloudwatch put-metric-data \
        --namespace "EC2-Security-Metrics" \
        --metric-data "MetricName=$metric_name,Value=$value,Unit=$unit,Dimensions=[{Name=InstanceId,Value=$INSTANCE_ID}]" \
        --region "$REGION"
}

# SSH failed login attempts
if [ -f /var/log/secure ]; then
    SSH_FAILED=$(grep "Failed password" /var/log/secure | grep "$(date '+%b %d')" | wc -l)
    publish_metric "SSHFailedLogins" "$SSH_FAILED" "Count"
elif [ -f /var/log/auth.log ]; then
    SSH_FAILED=$(grep "Failed password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
    publish_metric "SSHFailedLogins" "$SSH_FAILED" "Count"
fi

# SSH successful logins
if [ -f /var/log/secure ]; then
    SSH_SUCCESS=$(grep "Accepted password" /var/log/secure | grep "$(date '+%b %d')" | wc -l)
    publish_metric "SSHSuccessfulLogins" "$SSH_SUCCESS" "Count"
elif [ -f /var/log/auth.log ]; then
    SSH_SUCCESS=$(grep "Accepted password" /var/log/auth.log | grep "$(date '+%b %d')" | wc -l)
    publish_metric "SSHSuccessfulLogins" "$SSH_SUCCESS" "Count"
fi

# Number of running processes
RUNNING_PROCESSES=$(ps aux | wc -l)
publish_metric "RunningProcesses" "$RUNNING_PROCESSES" "Count"

# Network connections
ESTABLISHED_CONNECTIONS=$(netstat -an | grep ESTABLISHED | wc -l)
publish_metric "EstablishedConnections" "$ESTABLISHED_CONNECTIONS" "Count"

# Load average
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
publish_metric "LoadAverage" "$LOAD_AVG" "None"

# Disk I/O operations
if command -v iostat &> /dev/null; then
    DISK_IO=$(iostat -x 1 2 | tail -n +4 | grep -v "^$" | awk '{sum+=$4} END {print sum}')
    publish_metric "DiskIOOperations" "$DISK_IO" "Count"
fi
EOF

    chmod +x /usr/local/bin/custom-metrics.sh
    
    # Create cron job for custom metrics
    cat > /etc/cron.d/custom-metrics << 'EOF'
# Custom metrics collection every 5 minutes
*/5 * * * * root /usr/local/bin/custom-metrics.sh >/dev/null 2>&1
EOF
    
    log_info "Custom metrics setup completed"
}

# Create security monitoring dashboards
create_dashboard() {
    local sns_topic_arn=$1
    log_step "Creating CloudWatch dashboard..."
    
    cat > /tmp/dashboard.json << EOF
{
    "widgets": [
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["AWS/EC2", "CPUUtilization", "InstanceId", "$INSTANCE_ID"]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$REGION",
                "title": "CPU Utilization",
                "period": 300
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["CWAgent", "mem_used_percent", "InstanceId", "$INSTANCE_ID"]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$REGION",
                "title": "Memory Utilization",
                "period": 300
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["CWAgent", "used_percent", "InstanceId", "$INSTANCE_ID", "Device", "/"]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$REGION",
                "title": "Disk Utilization",
                "period": 300
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["EC2-Security-Metrics", "SSHFailedLogins", "InstanceId", "$INSTANCE_ID"],
                    [".", "SSHSuccessfulLogins", ".", "."]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$REGION",
                "title": "SSH Authentication Events",
                "period": 300
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["EC2-Security-Metrics", "RunningProcesses", "InstanceId", "$INSTANCE_ID"]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$REGION",
                "title": "Running Processes",
                "period": 300
            }
        },
        {
            "type": "metric",
            "properties": {
                "metrics": [
                    ["EC2-Security-Metrics", "EstablishedConnections", "InstanceId", "$INSTANCE_ID"]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "$REGION",
                "title": "Network Connections",
                "period": 300
            }
        }
    ]
}
EOF

    aws cloudwatch put-dashboard \
        --dashboard-name "EC2-Security-Dashboard-$INSTANCE_ID" \
        --dashboard-body file:///tmp/dashboard.json \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    rm -f /tmp/dashboard.json
    
    log_info "CloudWatch dashboard created"
}

# Setup log aggregation
setup_log_aggregation() {
    log_step "Setting up log aggregation..."
    
    # Create log groups
    aws logs create-log-group \
        --log-group-name "/ec2-security/auth" \
        --region "$REGION" >> "$LOG_FILE" 2>&1 || true
    
    aws logs create-log-group \
        --log-group-name "/ec2-security/system" \
        --region "$REGION" >> "$LOG_FILE" 2>&1 || true
    
    aws logs create-log-group \
        --log-group-name "/ec2-security/audit" \
        --region "$REGION" >> "$LOG_FILE" 2>&1 || true
    
    # Set retention policy (30 days)
    aws logs put-retention-policy \
        --log-group-name "/ec2-security/auth" \
        --retention-in-days 30 \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    aws logs put-retention-policy \
        --log-group-name "/ec2-security/system" \
        --retention-in-days 30 \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    aws logs put-retention-policy \
        --log-group-name "/ec2-security/audit" \
        --retention-in-days 30 \
        --region "$REGION" >> "$LOG_FILE" 2>&1
    
    log_info "Log aggregation setup completed"
}

# Create monitoring report
create_monitoring_report() {
    log_step "Creating monitoring setup report..."
    
    local report_file="/root/monitoring-setup-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
EC2 Instance Monitoring Setup Report
========================================
Generated: $(date)
Instance ID: $INSTANCE_ID
Region: $REGION

========================================
Monitoring Components Configured
========================================
✓ CloudWatch Agent installed and configured
✓ Custom metrics collection script
✓ CloudWatch alarms for critical metrics
✓ SNS topic for alert notifications
✓ CloudWatch dashboard
✓ Log aggregation setup

========================================
CloudWatch Alarms Created
========================================
- ${ALARM_PREFIX}-CPU-High: CPU > 80%
- ${ALARM_PREFIX}-Memory-High: Memory > 90%
- ${ALARM_PREFIX}-Disk-High: Disk > 85%
- ${ALARM_PREFIX}-Status-Check-Failed: System status check

========================================
Custom Metrics
========================================
- SSHFailedLogins: Count of failed SSH attempts
- SSHSuccessfulLogins: Count of successful SSH logins
- RunningProcesses: Number of running processes
- EstablishedConnections: Number of network connections
- LoadAverage: System load average
- DiskIOOperations: Disk I/O operations

========================================
Log Groups Created
========================================
- /ec2-security/auth (30-day retention)
- /ec2-security/system (30-day retention)
- /ec2-security/audit (30-day retention)

========================================
SNS Topic
========================================
Name: $SNS_TOPIC_NAME
ARN: $SNS_TOPIC_ARN

========================================
CloudWatch Dashboard
========================================
Name: EC2-Security-Dashboard-$INSTANCE_ID
URL: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=EC2-Security-Dashboard-$INSTANCE_ID

========================================
Next Steps
========================================
1. Subscribe to the SNS topic for alert notifications
2. Review the CloudWatch dashboard
3. Monitor the custom metrics and alarms
4. Adjust alarm thresholds as needed
5. Set up additional log shipping if required

========================================
Maintenance
========================================
- CloudWatch agent runs as a service
- Custom metrics collected every 5 minutes
- Log files automatically shipped to CloudWatch Logs
- Alarms will trigger notifications to SNS subscribers

========================================
Troubleshooting
========================================
- Check CloudWatch agent status: systemctl status amazon-cloudwatch-agent
- View agent logs: /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
- Test custom metrics: /usr/local/bin/custom-metrics.sh
- Verify alarms in CloudWatch console

========================================
EOF

    log_info "Monitoring setup report created: $report_file"
}

# Main execution
main() {
    log_info "Starting EC2 instance monitoring setup..."
    
    # Initial checks
    check_aws_cli
    
    # Setup monitoring components
    install_cloudwatch_agent
    configure_cloudwatch_agent
    
    # Create alerting infrastructure
    SNS_TOPIC_ARN=$(create_sns_topic)
    create_cloudwatch_alarms "$SNS_TOPIC_ARN"
    create_dashboard "$SNS_TOPIC_ARN"
    
    # Setup custom metrics and logging
    create_custom_metrics
    setup_log_aggregation
    
    # Generate report
    create_monitoring_report
    
    log_info "Monitoring setup completed successfully!"
    echo
    log_info "=== Monitoring Configuration Summary ==="
    log_info "Instance ID: $INSTANCE_ID"
    log_info "Region: $REGION"
    log_info "SNS Topic: $SNS_TOPIC_ARN"
    echo
    log_info "=== Dashboard Access ==="
    log_info "Dashboard: EC2-Security-Dashboard-$INSTANCE_ID"
    log_info "URL: https://$REGION.console.aws.amazon.com/cloudwatch/home?region=$REGION#dashboards:name=EC2-Security-Dashboard-$INSTANCE_ID"
    echo
    log_info "=== Next Steps ==="
    log_info "1. Subscribe to SNS topic for alerts: $SNS_TOPIC_ARN"
    log_info "2. Check CloudWatch dashboard for metrics"
    log_info "3. Verify alarms are working correctly"
    log_info "4. Monitor logs in CloudWatch Logs"
    echo
    log_warn "=== Important ==="
    log_warn "Make sure to subscribe to the SNS topic to receive alert notifications!"
}

# Run main function
main "$@"
