# AWS EC2 Security Project - Usage Guide

## Overview

This project provides a comprehensive solution for securing AWS EC2 instances with automated deployment, hardening, and monitoring capabilities. It implements all the exercises from the original "Project-1-Securing-AWS-EC2-Instances.md" with additional security best practices.

## Project Structure

```
aws-ec2-security/
├── README.md
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Main Terraform configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output variables
│   └── security_groups.tf       # Security group configurations
├── scripts/                      # Automation scripts
│   ├── setup.sh                  # Complete setup script
│   ├── harden.sh                 # Instance hardening script
│   ├── monitor.sh                # Monitoring setup script
│   ├── key-management.sh         # SSH key management
│   ├── user-data.sh              # EC2 user data script
│   └── cleanup.sh                # Resource cleanup script
├── cloudformation/               # CloudFormation template (optional)
│   └── ec2-security-template.yaml
└── docs/                         # Documentation
    └── usage-guide.md
```

## Prerequisites

1. **AWS Account**: Free tier or paid account
2. **AWS CLI**: Installed and configured with appropriate permissions
3. **Terraform**: (Optional) For Infrastructure as Code deployment
4. **SSH Client**: For connecting to EC2 instances

### Required AWS IAM Permissions

The following IAM permissions are required:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "cloudwatch:*",
                "logs:*",
                "sns:*",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
```

## Quick Start

### Option 1: Using Setup Script (Recommended)

1. **Clone or download the project files**
2. **Navigate to the scripts directory**
3. **Run the setup script**:

```bash
cd scripts
chmod +x *.sh
./setup.sh
```

The setup script will:
- Create VPC, subnet, and networking components
- Generate SSH key pair
- Create security group with IP-restricted access
- Launch EC2 instance with security hardening
- Set up CloudWatch monitoring and alerts
- Provide connection details

### Option 2: Using Terraform

1. **Navigate to terraform directory**:
```bash
cd terraform
```

2. **Create SSH key pair**:
```bash
ssh-keygen -t rsa -b 4096 -f ec2-security-key
```

3. **Initialize and apply Terraform**:
```bash
terraform init
terraform apply
```

4. **Connect to the instance** using the provided SSH command

### Option 3: Using CloudFormation

1. **Deploy the CloudFormation stack**:
```bash
aws cloudformation create-stack \
    --stack-name ec2-security-stack \
    --template-body file://cloudformation/ec2-security-template.yaml \
    --parameters ParameterKey=KeyPairName,ParameterValue=your-key-name \
    --capabilities CAPABILITY_IAM
```

## Detailed Usage

### 1. Key Management

The `key-management.sh` script provides comprehensive SSH key management:

```bash
# Create new key pair
./key-management.sh create mykey

# List all keys
./key-management.sh list

# Test SSH connection
./key-management.sh test ec2-xxx.compute.amazonaws.com

# Show key fingerprint
./key-management.sh fingerprint

# Backup key pair
./key-management.sh backup

# Delete key pair
./key-management.sh delete mykey
```

### 2. Instance Hardening

After connecting to your instance, run the hardening script:

```bash
# Connect to instance first
ssh -i ec2-security-key.pem ec2-user@<instance-public-dns>

# Run hardening script
sudo ./scripts/harden.sh
```

The hardening script:
- Updates all system packages
- Creates a new secure user with sudo privileges
- Disables root SSH login
- Enforces key-based authentication only
- Configures firewall (UFW/firewalld)
- Sets up fail2ban
- Enables system auditing
- Secures kernel parameters
- Removes unnecessary services

### 3. Monitoring Setup

To set up comprehensive monitoring:

```bash
# Connect to instance
ssh -i ec2-security-key.pem ec2-user@<instance-public-dns>

# Run monitoring setup
sudo ./scripts/monitor.sh
```

This script configures:
- CloudWatch agent for detailed metrics
- Custom security metrics (SSH attempts, connections, etc.)
- CloudWatch alarms for critical thresholds
- SNS notifications for alerts
- Log aggregation to CloudWatch Logs
- Monitoring dashboard

### 4. Resource Cleanup

To clean up all resources:

```bash
cd scripts
./cleanup.sh
```

⚠️ **Warning**: This will permanently delete all resources created by the project.

## Security Features

### Network Security
- **VPC Isolation**: Dedicated VPC with private subnets
- **Security Groups**: IP-restricted SSH access
- **Firewall**: Host-based firewall configuration
- **Network ACLs**: Additional network layer protection

### Instance Security
- **Key-based Authentication**: SSH keys only, no passwords
- **User Management**: Dedicated user with minimal privileges
- **Root Login Disabled**: Prevents direct root access
- **System Hardening**: Comprehensive security configurations
- **Regular Updates**: Automated security patching

### Monitoring & Alerting
- **CloudWatch Metrics**: CPU, memory, disk, network monitoring
- **Security Metrics**: SSH attempts, failed logins, connections
- **Custom Alarms**: Threshold-based alerting
- **Log Aggregation**: Centralized log collection
- **Dashboard**: Visual monitoring interface

### Compliance Features
- **Audit Logging**: System audit trail
- **Access Control**: Principle of least privilege
- **Data Encryption**: EBS volume encryption
- **Backup Strategy**: Configuration backups

## Exercise Mapping

This project implements all exercises from the original project:

| Exercise | Implementation | Script |
|----------|----------------|--------|
| Exercise 1: Launch EC2 Instance | Automated with Terraform/CLI | `setup.sh`, `main.tf` |
| Exercise 2: Connect to Instance | Automated key management | `key-management.sh` |
| Exercise 3: Update and Secure Instance | Comprehensive hardening | `harden.sh` |
| Exercise 4: Configure Security Groups | IP-restricted security groups | `setup.sh`, `security_groups.tf` |
| Exercise 5: Set Up CloudWatch Monitoring | Advanced monitoring setup | `monitor.sh` |

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failed
```bash
# Check key permissions
chmod 400 ec2-security-key.pem

# Verify security group allows your IP
aws ec2 describe-security-groups --group-ids <sg-id>

# Check instance status
aws ec2 describe-instances --instance-ids <instance-id>
```

#### 2. Instance Not Responding
```bash
# Check system logs
aws ec2 get-console-output --instance-id <instance-id>

# Verify user data script execution
ssh -i key.pem ec2-user@<instance-dns> "sudo cat /var/log/user-data.log"
```

#### 3. CloudWatch Alarms Not Working
```bash
# Check CloudWatch agent status
ssh -i key.pem ec2-user@<instance-dns> "sudo systemctl status amazon-cloudwatch-agent"

# Verify IAM role permissions
aws iam list-attached-role-policies --role-name <instance-role>
```

#### 4. Hardening Script Issues
```bash
# Check hardening logs
ssh -i key.pem ec2-user@<instance-dns> "sudo cat /var/log/ec2-hardening.log"

# Verify user creation
ssh -i key.pem ec2-user@<instance-dns> "id secureuser"
```

### Debug Mode

For detailed debugging, modify scripts to include debug output:

```bash
# Add to beginning of scripts
set -x  # Enable debug mode
```

## Cost Management

### Estimated Costs (Free Tier Eligible)
- **EC2 Instance**: t2.micro (750 hours/month free)
- **Data Transfer**: 15 GB/month free
- **CloudWatch**: 10 custom metrics free
- **CloudWatch Logs**: 5 GB ingestion free
- **SNS**: 1 million notifications free

### Cost Optimization Tips
1. Use t2.micro instances for development
2. Set up CloudWatch billing alerts
3. Clean up resources when not in use
4. Use the cleanup script to avoid ongoing charges

## Best Practices

### Security
1. **Regular Updates**: Keep systems patched
2. **Key Rotation**: Rotate SSH keys periodically
3. **Access Review**: Regularly review user access
4. **Monitoring**: Set up comprehensive alerting
5. **Backup**: Regular configuration backups

### Operations
1. **Infrastructure as Code**: Use Terraform for reproducibility
2. **Automation**: Automate repetitive tasks
3. **Documentation**: Keep documentation updated
4. **Testing**: Test security configurations
5. **Monitoring**: Monitor system health and security

### Compliance
1. **Audit Trail**: Maintain comprehensive logs
2. **Access Control**: Implement least privilege
3. **Data Protection**: Encrypt sensitive data
4. **Regular Audits**: Conduct security assessments
5. **Incident Response**: Have response procedures

## Advanced Configuration

### Custom Security Groups

Modify `terraform/security_groups.tf` to add custom rules:

```hcl
# Custom application port
ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Application access from private network"
}
```

### Additional Monitoring

Extend `scripts/monitor.sh` with custom metrics:

```bash
# Add to custom-metrics.sh
# Database connections
DB_CONNECTIONS=$(netstat -an | grep :3306 | grep ESTABLISHED | wc -l)
publish_metric "DatabaseConnections" "$DB_CONNECTIONS" "Count"
```

### Multi-Region Deployment

Modify Terraform for multi-region:

```hcl
# Add to main.tf
provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

resource "aws_instance" "west_instance" {
  provider = aws.west
  # ... rest of configuration
}
```

## Support and Contributing

### Getting Help
1. Check the troubleshooting section
2. Review AWS documentation
3. Examine script logs
4. Test in development environment first

### Contributing
1. Fork the repository
2. Create feature branch
3. Test thoroughly
4. Submit pull request
5. Document changes

## License

This project is provided as educational material. Use at your own risk and ensure compliance with your organization's security policies.

## Version History

- **v1.0**: Initial implementation with all exercises
- **v1.1**: Added Terraform support and enhanced monitoring
- **v1.2**: Improved security hardening and documentation
- **v1.3**: Added cleanup script and cost optimization
