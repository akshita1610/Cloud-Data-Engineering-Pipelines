# AWS EC2 Security Hardening & Monitoring

[![AWS](https://img.shields.io/badge/AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Security](https://img.shields.io/badge/Security-009639?style=for-the-badge&logo=security&logoColor=white)](https://aws.amazon.com/security/)
[![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)

A comprehensive AWS EC2 security implementation featuring automated hardening, real-time monitoring, and production-ready security controls. This project demonstrates advanced cloud security practices including intrusion prevention, firewall configuration, secure user management, and CloudWatch monitoring integration.

## 🎯 Project Overview

This project provides a complete solution for securing AWS EC2 instances with:
- **Automated Security Hardening**
- **Real-time Monitoring & Alerting**
- **Infrastructure as Code (IaC)**
- **Multiple Deployment Options**
- **Zero-Cost Implementation** (Free Tier)

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   AWS EC2 Instance                    │
│  ┌─────────────────────────────────────────────────┐    │
│  │           Security Hardening              │    │
│  │  ┌─────────────┐  ┌─────────────┐    │    │
│  │  │   Fail2ban  │  │     UFW     │    │    │
│  │  │ Intrusion   │  │  Firewall    │    │    │
│  │  │ Prevention  │  │ Protection   │    │    │
│  │  └─────────────┘  └─────────────┘    │    │
│  │  ┌─────────────────────────────────────┐    │    │
│  │  │     CloudWatch Monitoring       │    │    │
│  │  │  • Metrics  • Alerts         │    │    │
│  │  │  • Logs     • Dashboard       │    │    │
│  │  └─────────────────────────────────────┘    │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Option 1: AWS CLI Scripts (Recommended)
```bash
cd scripts
chmod +x *.sh
./setup.sh
```

### Option 2: Terraform
```bash
cd terraform
terraform init
terraform apply
```

### Option 3: CloudFormation
```bash
aws cloudformation create-stack \
    --stack-name ec2-security-stack \
    --template-body file://cloudformation/ec2-security-template.yaml \
    --capabilities CAPABILITY_IAM
```

## 🔒 Security Features

### 🛡️ Hardening Controls
- ✅ **System Updates**: Automated package management
- ✅ **Firewall Configuration**: UFW with restrictive rules
- ✅ **Intrusion Prevention**: Fail2ban with custom rules
- ✅ **SSH Security**: Key-based auth, disabled root login
- ✅ **User Management**: Secure user creation with sudo access
- ✅ **System Auditing**: Log monitoring and analysis

### 📊 Monitoring & Alerting
- ✅ **CloudWatch Integration**: Real-time metrics
- ✅ **Custom Dashboards**: Visual monitoring
- ✅ **Automated Alerts**: CPU, Memory, Disk thresholds
- ✅ **Log Aggregation**: Centralized log management
- ✅ **Performance Monitoring**: System health tracking

## 📁 Project Structure

```
aws-ec2-security-hardening/
├── 📄 README.md                 # This file
├── 🔧 scripts/                  # Automation scripts
│   ├── setup.sh               # Instance deployment
│   ├── harden.sh             # Security hardening
│   ├── monitor.sh             # Monitoring setup
│   ├── cleanup.sh             # Resource cleanup
│   └── key-management.sh       # SSH key management
├── 🏗️ terraform/               # Infrastructure as Code
│   ├── main.tf               # Main configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf            # Output values
│   └── security_groups.tf    # Security group rules
├── ☁️ cloudformation/           # AWS native IaC
│   └── ec2-security-template.yaml
├── 📚 docs/                    # Documentation
│   └── usage-guide.md        # Detailed usage guide
└── 📋 requirements.txt          # Python dependencies
```

## 🎯 What You'll Learn

- **AWS Security Best Practices**
- **Infrastructure as Code (IaC)**
- **Automated Security Hardening**
- **Cloud Monitoring & Observability**
- **Cost Optimization Strategies**
- **DevOps & Automation Skills**

## 🔧 Prerequisites

- **AWS Account** with Free Tier access
- **AWS CLI** configured with credentials
- **Terraform** (optional, for IaC deployment)
- **Basic Linux/SSH** knowledge

## 💰 Cost Breakdown

| Service | Cost (Monthly) | Free Tier Coverage |
|----------|-----------------|-------------------|
| EC2 (t3.micro) | ~$15 | ✅ Covered |
| CloudWatch | ~$5 | ✅ Covered |
| Data Transfer | ~$1 | ✅ Covered |
| **Total** | **$0** | ✅ **100% Free** |

## 🚀 Deployment Results

### ✅ Live Instance
- **URL**: `ec2-18-206-252-63.compute-1.amazonaws.com`
- **Status**: Running & Secured
- **Region**: us-east-1
- **Instance Type**: t3.micro (Free Tier)

### 🔒 Security Status
- **Firewall**: Active (UFW)
- **Intrusion Prevention**: Active (Fail2ban)
- **SSH Access**: Secure user only
- **Monitoring**: Active (CloudWatch)

## 📊 Monitoring Dashboard

Access your CloudWatch dashboard for:
- **CPU & Memory Metrics**
- **Network Performance**
- **Security Events**
- **Custom Alerts**

## 🔐 Security Verification

Test your secure instance:

```bash
# Connect as secure user
ssh -i ec2-security-key-v2.pem secureuser@ec2-18-206-252-63.compute-1.amazonaws.com

# Verify security services
sudo systemctl status fail2ban
sudo ufw status
```

## 🧹 Cleanup

Remove all resources when done:
```bash
./scripts/cleanup.sh
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏆 Project Showcase

### 🎯 Key Achievements
- ✅ **Production-Ready Security Implementation**
- ✅ **Zero-Cost Deployment** (Free Tier)
- ✅ **Comprehensive Monitoring**
- ✅ **Infrastructure as Code**
- ✅ **Automated Hardening**

### 💡 Skills Demonstrated
- **Cloud Security Architecture**
- **AWS Services Integration**
- **Automation & Scripting**
- **Monitoring & Observability**
- **Cost Optimization**
- **DevOps Best Practices**

---

**🚀 Ready to deploy your secured EC2 instance!**

*Built with ❤️ for cloud security enthusiasts*
│   ├── setup.sh
│   ├── harden.sh
│   ├── monitor.sh
│   └── cleanup.sh
├── cloudformation/
│   └── ec2-security-template.yaml
└── docs/
    └── usage-guide.md
```

## Prerequisites

1. AWS CLI installed and configured
2. Terraform installed (optional, for IaC approach)
3. SSH client installed

## Quick Start

### Option 1: Using AWS CLI Scripts (Recommended)
```bash
cd scripts
chmod +x *.sh
./setup.sh
```

### Option 2: Using Terraform
```bash
cd terraform
terraform init
terraform apply
```

### Option 3: Using CloudFormation
```bash
aws cloudformation create-stack \
    --stack-name ec2-security-stack \
    --template-body file://cloudformation/ec2-security-template.yaml \
    --parameters ParameterKey=KeyPairName,ParameterValue=your-key-name \
    --capabilities CAPABILITY_IAM
```

## Security Features Implemented

- ✅ Security group with IP-restricted SSH access
- ✅ Key pair management
- ✅ Instance hardening (disable root login, key-based auth only)
- ✅ System updates and security patches
- ✅ CloudWatch monitoring and alerts
- ✅ User management with sudo privileges

## Exercises Covered

1. **Exercise 1**: Launch EC2 Instance
2. **Exercise 2**: Connect to EC2 Instance
3. **Exercise 3**: Update and Secure Instance
4. **Exercise 4**: Configure Security Groups
5. **Exercise 5**: Set Up CloudWatch Monitoring

## Security Best Practices

- Principle of least privilege
- Regular security updates
- Monitoring and alerting
- Key-based authentication only
- IP-restricted access
