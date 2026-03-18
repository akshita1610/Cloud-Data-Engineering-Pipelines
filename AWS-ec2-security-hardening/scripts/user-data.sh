#!/bin/bash

# AWS EC2 Security Project - User Data Script
# This script runs during EC2 instance initialization

set -euo pipefail

# Configuration
NEW_USERNAME="${new_username:-secureuser}"
LOG_FILE="/var/log/user-data.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Create log file
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "Starting EC2 instance initialization..."

# Update system
log "Updating system packages..."
if command -v yum &> /dev/null; then
    yum update -y >> "$LOG_FILE" 2>&1
elif command -v apt-get &> /dev/null; then
    apt-get update >> "$LOG_FILE" 2>&1
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
fi

# Install basic tools
log "Installing basic tools..."
if command -v yum &> /dev/null; then
    yum install -y git wget curl htop >> "$LOG_FILE" 2>&1
elif command -v apt-get &> /dev/null; then
    apt-get install -y git wget curl htop >> "$LOG_FILE" 2>&1
fi

# Create new user
log "Creating user: $NEW_USERNAME"
if ! id "$NEW_USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash "$NEW_USERNAME"
    passwd -l "$NEW_USERNAME" >> "$LOG_FILE" 2>&1
    
    # Add to sudo group
    if command -v yum &> /dev/null; then
        usermod -aG wheel "$NEW_USERNAME"
    elif command -v apt-get &> /dev/null; then
        usermod -aG sudo "$NEW_USERNAME"
    fi
    
    # Create .ssh directory
    mkdir -p "/home/$NEW_USERNAME/.ssh"
    chmod 700 "/home/$NEW_USERNAME/.ssh"
    chown "$NEW_USERNAME:$NEW_USERNAME" "/home/$NEW_USERNAME/.ssh"
    
    # Copy authorized_keys from ec2-user
    if [ -f "/home/ec2-user/.ssh/authorized_keys" ]; then
        cp "/home/ec2-user/.ssh/authorized_keys" "/home/$NEW_USERNAME/.ssh/authorized_keys"
        chmod 600 "/home/$NEW_USERNAME/.ssh/authorized_keys"
        chown "$NEW_USERNAME:$NEW_USERNAME" "/home/$NEW_USERNAME/.ssh/authorized_keys"
    fi
    
    log "User $NEW_USERNAME created successfully"
else
    log "User $NEW_USERNAME already exists"
fi

# Basic SSH hardening
log "Applying basic SSH hardening..."
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config || true
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true

# Restart SSH service
if command -v systemctl &> /dev/null; then
    systemctl restart sshd >> "$LOG_FILE" 2>&1
elif command -v service &> /dev/null; then
    service sshd restart >> "$LOG_FILE" 2>&1
fi

# Create a welcome message
cat > /etc/motd << 'EOF'
========================================
AWS EC2 Security Instance
========================================

This instance has been configured with security best practices:

- System packages updated
- New user created with sudo privileges
- Basic SSH hardening applied
- Root login disabled
- Password authentication disabled

For full security hardening, run:
sudo /home/ec2-user/scripts/harden.sh

========================================
EOF

log "EC2 instance initialization completed successfully"
