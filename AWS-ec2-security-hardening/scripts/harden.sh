#!/bin/bash

# AWS EC2 Security Project - Instance Hardening Script
# This script secures an EC2 instance following security best practices

set -euo pipefail

# Configuration
NEW_USERNAME="secureuser"
SSH_CONFIG="/etc/ssh/sshd_config"
BACKUP_DIR="/etc/security-backups"
LOG_FILE="/var/log/ec2-hardening.log"

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root. Use 'sudo $0'"
        exit 1
    fi
}

# Create backup directory
setup_backups() {
    log_step "Setting up backup directory..."
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
    log_info "Backup directory created: $BACKUP_DIR"
}

# Backup file before modification
backup_file() {
    local file_path=$1
    local backup_name=$(basename "$file_path")
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/${backup_name}_$timestamp"
    
    if [ -f "$file_path" ]; then
        cp "$file_path" "$backup_file"
        log_info "Backup created: $backup_file"
    fi
}

# Update system packages
update_system() {
    log_step "Updating system packages..."
    
    # Detect package manager
    if command -v yum &> /dev/null; then
        yum update -y
        yum upgrade -y
        yum install -y epel-release
    elif command -v apt-get &> /dev/null; then
        apt-get update
        apt-get upgrade -y
        apt-get install -y software-properties-common
    else
        log_error "Unsupported package manager"
        exit 1
    fi
    
    log_info "System packages updated successfully"
}

# Install security tools
install_security_tools() {
    log_step "Installing security tools..."
    
    if command -v yum &> /dev/null; then
        yum install -y fail2ban ufw rkhunter chkrootkit auditd
    elif command -v apt-get &> /dev/null; then
        apt-get install -y fail2ban ufw rkhunter chkrootkit auditd
    fi
    
    log_info "Security tools installed"
}

# Create new user with sudo privileges
create_user() {
    local username=${1:-$NEW_USERNAME}
    
    log_step "Creating new user: $username"
    
    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_warn "User $username already exists"
        return
    fi
    
    # Create user
    useradd -m -s /bin/bash "$username"
    
    # Set password (disabled for security - will use key-based auth)
    passwd -l "$username"
    
    # Add to sudo group
    if command -v yum &> /dev/null; then
        usermod -aG wheel "$username"
    elif command -v apt-get &> /dev/null; then
        usermod -aG sudo "$username"
    fi
    
    # Create .ssh directory
    mkdir -p "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    chown "$username:$username" "/home/$username/.ssh"
    
    log_info "User $username created with sudo privileges"
}

# Setup SSH key authentication for new user
setup_ssh_keys() {
    local username=${1:-$NEW_USERNAME}
    
    log_step "Setting up SSH key authentication for $username"
    
    # Copy authorized_keys from ec2-user if exists
    if [ -f "/home/ec2-user/.ssh/authorized_keys" ]; then
        cp "/home/ec2-user/.ssh/authorized_keys" "/home/$username/.ssh/authorized_keys"
        chmod 600 "/home/$username/.ssh/authorized_keys"
        chown "$username:$username" "/home/$username/.ssh/authorized_keys"
        log_info "SSH keys copied from ec2-user to $username"
    else
        log_warn "No authorized_keys found for ec2-user"
        log_info "You will need to manually add SSH keys for $username"
    fi
}

# Harden SSH configuration
harden_ssh() {
    log_step "Hardening SSH configuration..."
    
    backup_file "$SSH_CONFIG"
    
    # Create hardened SSH config
    cat > "$SSH_CONFIG" << 'EOF'
# SSH Configuration - Hardened for Security

# Basic settings
Port 22
Protocol 2

# Authentication settings
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Key-based authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Logging
SyslogFacility AUTHPRIV
LogLevel VERBOSE

# Security settings
X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
PermitTunnel no

# User restrictions
AllowUsers ec2-user secureuser

# Subsystem configuration
Subsystem sftp /usr/libexec/openssh/sftp-server
EOF

    # Restart SSH service
    if command -v systemctl &> /dev/null; then
        systemctl restart sshd
        systemctl enable sshd
    elif command -v service &> /dev/null; then
        service sshd restart
        chkconfig sshd on
    fi
    
    log_info "SSH configuration hardened"
}

# Configure firewall
configure_firewall() {
    log_step "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian - UFW
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw --force enable
        log_info "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        # RHEL/CentOS - firewalld
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --reload
        log_info "Firewalld configured"
    else
        log_warn "No supported firewall found"
    fi
}

# Configure fail2ban
configure_fail2ban() {
    log_step "Configuring fail2ban..."
    
    backup_file "/etc/fail2ban/jail.local"
    
    cat > "/etc/fail2ban/jail.local" << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/secure
maxretry = 3
bantime = 3600
EOF

    # Enable and start fail2ban
    if command -v systemctl &> /dev/null; then
        systemctl enable fail2ban
        systemctl restart fail2ban
    fi
    
    log_info "Fail2ban configured and started"
}

# Configure system auditing
configure_auditd() {
    log_step "Configuring system auditing..."
    
    backup_file "/etc/audit/auditd.conf"
    
    # Configure auditd
    cat > "/etc/audit/auditd.conf" << 'EOF'
log_file = /var/log/audit/audit.log
log_format = RAW
log_group = root
priority_boost = 4
flush = INCREMENTAL
freq = 20
max_log_file = 100
num_logs = 5
max_log_file_action = ROTATE
space_left = 75
space_left_action = SYSLOG
action_mail_acct = root
admin_space_left = 50
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
EOF

    # Add audit rules
    cat > "/etc/audit/rules.d/audit.rules" << 'EOF'
# Delete all existing rules
-D

# Basic monitoring
-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b32 -S execve -k exec

# Monitor file access
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers

# Monitor system calls
-a always,exit -F arch=b64 -S chmod,chown,fchmod,fchown -k perm_mod
-a always,exit -F arch=b32 -S chmod,chown,fchmod,fchown -k perm_mod

# Monitor network configuration
-w /etc/hosts -p wa -k hosts
-w /etc/sysconfig/network -p wa -k network

# Make sure we don't miss anything
-e 2
EOF

    # Enable and start auditd
    if command -v systemctl &> /dev/null; then
        systemctl enable auditd
        systemctl restart auditd
    fi
    
    log_info "System auditing configured"
}

# Configure log monitoring
configure_logwatch() {
    log_step "Configuring log monitoring..."
    
    if command -v yum &> /dev/null; then
        yum install -y logwatch
    elif command -v apt-get &> /dev/null; then
        apt-get install -y logwatch
    fi
    
    # Configure logwatch
    cat > "/etc/logwatch/conf/logwatch.conf" << 'EOF'
LogDir = /var/log
TmpDir = /var/cache/logwatch
MailTo = root
Range = yesterday
Detail = Med
Service = All
Format = text
EOF
    
    log_info "Log monitoring configured"
}

# Secure kernel parameters
secure_kernel() {
    log_step "Securing kernel parameters..."
    
    backup_file "/etc/sysctl.conf"
    
    cat >> "/etc/sysctl.conf" << 'EOF'

# Security hardening - Kernel parameters

# IP spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore source-routed packets
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Disable ICMP ping responses
net.ipv4.icmp_echo_ignore_all = 1

# Enable SYN cookies
net.ipv4.tcp_syncookies = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# Core dump restrictions
fs.suid_dumpable = 0
kernel.core_pattern = |/bin/false

# Shared memory restrictions
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
kernel.shmmni = 4096

# ExecShield protection
kernel.exec-shield = 1
EOF

    # Apply kernel parameters
    sysctl -p
    
    log_info "Kernel parameters secured"
}

# Remove unnecessary services
remove_services() {
    log_step "Removing unnecessary services..."
    
    # List of services to disable
    local services_to_disable=(
        "bluetooth"
        "cups"
        "avahi-daemon"
        "sendmail"
        "telnet"
        "rsh"
        "rlogin"
        "ypbind"
    )
    
    for service in "${services_to_disable[@]}"; do
        if command -v systemctl &> /dev/null; then
            if systemctl is-enabled "$service" &>/dev/null; then
                systemctl disable "$service"
                systemctl stop "$service"
                log_info "Disabled service: $service"
            fi
        elif command -v chkconfig &> /dev/null; then
            if chkconfig --list "$service" &>/dev/null; then
                chkconfig "$service" off
                service "$service" stop
                log_info "Disabled service: $service"
            fi
        fi
    done
    
    log_info "Unnecessary services removed"
}

# Set file permissions
set_permissions() {
    log_step "Setting secure file permissions..."
    
    # Secure critical files
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    chmod 644 /etc/passwd
    chmod 644 /etc/group
    
    # Secure SSH directory
    chmod 700 /root/.ssh 2>/dev/null || true
    chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true
    
    # Secure log files
    chmod 640 /var/log/secure 2>/dev/null || true
    chmod 640 /var/log/auth.log 2>/dev/null || true
    
    log_info "File permissions secured"
}

# Generate security report
generate_report() {
    log_step "Generating security report..."
    
    local report_file="/root/security-hardening-report-$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
========================================
EC2 Instance Security Hardening Report
========================================
Generated: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')

========================================
System Information
========================================
Uptime: $(uptime -p)
Memory: $(free -h | grep Mem)
Disk: $(df -h / | tail -1)

========================================
Security Configuration
========================================
SSH Root Login: $(grep -i PermitRootLogin /etc/ssh/sshd_config || echo 'Not found')
Password Authentication: $(grep -i PasswordAuthentication /etc/ssh/sshd_config || echo 'Not found')
Fail2ban Status: $(systemctl is-active fail2ban 2>/dev/null || echo 'Not installed')
Firewall Status: $(systemctl is-active firewalld 2>/dev/null || systemctl is-active ufw 2>/dev/null || echo 'Not found')

========================================
User Accounts
========================================
$(awk -F: '$3 >= 1000 && $3 != 65534 {print $1 ":" $3}' /etc/passwd)

========================================
Listening Ports
========================================
$(netstat -tlnp 2>/dev/null | grep LISTEN || ss -tlnp | grep LISTEN)

========================================
Recent Login Attempts
========================================
$(grep -i 'accepted\|failed' /var/log/secure 2>/dev/null | tail -10 || grep -i 'accepted\|failed' /var/log/auth.log 2>/dev/null | tail -10 || echo 'No login logs found')

========================================
Hardening Steps Completed
========================================
- System packages updated
- Security tools installed
- New user created: $NEW_USERNAME
- SSH configuration hardened
- Firewall configured
- Fail2ban configured
- System auditing enabled
- Kernel parameters secured
- File permissions secured
- Unnecessary services removed

========================================
Recommendations
========================================
1. Regularly update system packages
2. Monitor system logs and security alerts
3. Use IAM roles instead of access keys when possible
4. Enable AWS CloudTrail for API logging
5. Regular security audits and penetration testing
6. Backup important data regularly
7. Use AWS Security Groups for network security
8. Enable Amazon Inspector for vulnerability assessments

========================================
Next Steps
========================================
1. Test SSH access with new user: ssh -i key.pem $NEW_USERNAME@<instance-ip>
2. Verify all services are working correctly
3. Set up monitoring and alerting
4. Document any custom configurations
5. Schedule regular security updates

========================================
Backup Files Location
========================================
$BACKUP_DIR

========================================
EOF

    log_info "Security report generated: $report_file"
}

# Main execution
main() {
    log_info "Starting EC2 instance security hardening..."
    
    # Pre-flight checks
    check_root
    setup_backups
    
    # Hardening steps
    update_system
    install_security_tools
    create_user "$NEW_USERNAME"
    setup_ssh_keys "$NEW_USERNAME"
    harden_ssh
    configure_firewall
    configure_fail2ban
    configure_auditd
    configure_logwatch
    secure_kernel
    remove_services
    set_permissions
    
    # Generate report
    generate_report
    
    log_info "Security hardening completed successfully!"
    echo
    log_info "=== Important Information ==="
    log_info "New user created: $NEW_USERNAME"
    log_info "Root login disabled"
    log_info "Password authentication disabled"
    log_info "Only key-based authentication allowed"
    echo
    log_warn "=== Action Required ==="
    log_warn "1. Test SSH access with new user before closing current session"
    log_warn "2. Command: ssh -i your-key.pem $NEW_USERNAME@<instance-ip>"
    log_warn "3. Keep the current session open until you confirm new user access works"
    echo
    log_info "=== Security Report ==="
    log_info "A detailed security report has been generated in /root/"
    log_info "Backup files are stored in: $BACKUP_DIR"
}

# Run main function
main "$@"
