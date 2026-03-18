#!/bin/bash

# AWS EC2 Security Project - Key Management Script
# This script manages SSH key pairs for EC2 instances

set -euo pipefail

# Configuration
KEY_NAME="ec2-security-key"
KEY_DIR="$HOME/.ssh"
KEY_ALGORITHM="rsa"
KEY_BITS="4096"

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

# Create SSH key pair locally
create_local_key() {
    local key_name=${1:-$KEY_NAME}
    local key_path="$KEY_DIR/$key_name"
    
    log_info "Creating local SSH key pair: $key_name"
    
    if [ -f "$key_path" ]; then
        log_warn "Key file $key_path already exists."
        read -p "Do you want to overwrite it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing key."
            return
        fi
        rm -f "$key_path" "$key_path.pub"
    fi
    
    # Create .ssh directory if it doesn't exist
    mkdir -p "$KEY_DIR"
    chmod 700 "$KEY_DIR"
    
    # Generate key pair
    ssh-keygen -t "$KEY_ALGORITHM" -b "$KEY_BITS" -f "$key_path" -N "" -C "ec2-security-project"
    
    # Set correct permissions
    chmod 600 "$key_path"
    chmod 644 "$key_path.pub"
    
    log_info "Local SSH key pair created successfully."
    log_info "Private key: $key_path"
    log_info "Public key: $key_path.pub"
}

# Import public key to AWS
import_key_to_aws() {
    local key_name=${1:-$KEY_NAME}
    local public_key_path="$KEY_DIR/$key_name.pub"
    
    if [ ! -f "$public_key_path" ]; then
        log_error "Public key file not found: $public_key_path"
        exit 1
    fi
    
    log_info "Importing key pair to AWS: $key_name"
    
    # Check if key pair already exists
    if aws ec2 describe-key-pairs --key-names "$key_name" &>/dev/null; then
        log_warn "Key pair $key_name already exists in AWS."
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            aws ec2 delete-key-pair --key-name "$key_name"
            log_info "Deleted existing key pair from AWS."
        else
            log_info "Keeping existing AWS key pair."
            return
        fi
    fi
    
    # Import key pair
    aws ec2 import-key-pair \
        --key-name "$key_name" \
        --public-key-material "file://$public_key_path" \
        --tag-specifications "ResourceType=key-pair,Tags=[{Key=Name,Value=$key_name},{Key=Project,Value=AWS-EC2-Security}]" \
        --query "KeyFingerprint" \
        --output text > /dev/null
    
    log_info "Key pair imported to AWS successfully."
}

# List all key pairs
list_keys() {
    log_info "Listing AWS key pairs:"
    aws ec2 describe-key-pairs \
        --query "KeyPairs[*].[KeyName,KeyType,CreateTime]" \
        --output table
    
    echo
    log_info "Local SSH keys in $KEY_DIR:"
    if [ -d "$KEY_DIR" ]; then
        ls -la "$KEY_DIR"/*.pub 2>/dev/null || log_warn "No public keys found in $KEY_DIR"
    else
        log_warn "SSH directory $KEY_DIR does not exist."
    fi
}

# Delete key pair
delete_key() {
    local key_name=${1:-$KEY_NAME}
    
    log_warn "Deleting key pair: $key_name"
    
    # Delete from AWS
    if aws ec2 describe-key-pairs --key-names "$key_name" &>/dev/null; then
        aws ec2 delete-key-pair --key-name "$key_name"
        log_info "Deleted key pair from AWS."
    else
        log_warn "Key pair not found in AWS."
    fi
    
    # Delete local files
    local private_key="$KEY_DIR/$key_name"
    local public_key="$KEY_DIR/$key_name.pub"
    
    if [ -f "$private_key" ]; then
        rm -f "$private_key"
        log_info "Deleted private key: $private_key"
    fi
    
    if [ -f "$public_key" ]; then
        rm -f "$public_key"
        log_info "Deleted public key: $public_key"
    fi
}

# Test SSH connection
test_ssh_connection() {
    local instance_dns=${1:-}
    local key_name=${2:-$KEY_NAME}
    local key_path="$KEY_DIR/$key_name"
    
    if [ -z "$instance_dns" ]; then
        log_error "Instance DNS is required. Usage: $0 test <instance-dns> [key-name]"
        exit 1
    fi
    
    if [ ! -f "$key_path" ]; then
        log_error "Private key not found: $key_path"
        exit 1
    fi
    
    log_info "Testing SSH connection to $instance_dns"
    
    # Test SSH connection
    if ssh -i "$key_path" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes \
        ec2-user@"$instance_dns" "echo 'SSH connection successful'" 2>/dev/null; then
        log_info "SSH connection successful!"
    else
        log_error "SSH connection failed."
        exit 1
    fi
}

# Generate key fingerprint
show_fingerprint() {
    local key_name=${1:-$KEY_NAME}
    local public_key_path="$KEY_DIR/$key_name.pub"
    
    if [ ! -f "$public_key_path" ]; then
        log_error "Public key not found: $public_key_path"
        exit 1
    fi
    
    log_info "Key fingerprint for $key_name:"
    ssh-keygen -lf "$public_key_path"
    
    echo
    log_info "AWS key fingerprint:"
    aws ec2 describe-key-pairs --key-names "$key_name" --query "KeyPairs[0].KeyFingerprint" --output text 2>/dev/null || \
        log_warn "Key not found in AWS or fingerprint not available."
}

# Backup key pair
backup_key() {
    local key_name=${1:-$KEY_NAME}
    local backup_dir="$KEY_DIR/backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$backup_dir/${key_name}_backup_$timestamp.tar.gz"
    
    log_info "Creating backup of key pair: $key_name"
    
    mkdir -p "$backup_dir"
    
    if [ -f "$KEY_DIR/$key_name" ] && [ -f "$KEY_DIR/$key_name.pub" ]; then
        tar -czf "$backup_file" -C "$KEY_DIR" "$key_name" "$key_name.pub"
        log_info "Backup created: $backup_file"
    else
        log_error "Key files not found for backup."
        exit 1
    fi
}

# Restore key pair from backup
restore_key() {
    local backup_file=$1
    local key_name=${2:-$KEY_NAME}
    
    if [ -z "$backup_file" ]; then
        log_error "Backup file path is required."
        exit 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        exit 1
    fi
    
    log_info "Restoring key pair from: $backup_file"
    
    tar -xzf "$backup_file" -C "$KEY_DIR"
    
    # Set correct permissions
    chmod 600 "$KEY_DIR/$key_name"
    chmod 644 "$KEY_DIR/$key_name.pub"
    
    log_info "Key pair restored successfully."
}

# Show usage
show_usage() {
    echo "AWS EC2 Security Project - Key Management Script"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  create [key-name]           Create a new SSH key pair"
    echo "  import [key-name]           Import existing public key to AWS"
    echo "  list                       List all key pairs"
    echo "  delete [key-name]          Delete a key pair"
    echo "  test <instance-dns> [key]  Test SSH connection"
    echo "  fingerprint [key-name]     Show key fingerprint"
    echo "  backup [key-name]           Backup key pair"
    echo "  restore <backup-file> [key] Restore key pair from backup"
    echo "  help                       Show this help message"
    echo
    echo "Examples:"
    echo "  $0 create                   # Create default key pair"
    echo "  $0 create mykey            # Create key named 'mykey'"
    echo "  $0 test ec2-xxx.compute.amazonaws.com"
    echo "  $0 backup                   # Backup default key"
    echo "  $0 restore backup.tar.gz   # Restore from backup"
}

# Main execution
main() {
    case "${1:-help}" in
        create)
            create_local_key "${2:-$KEY_NAME}"
            import_key_to_aws "${2:-$KEY_NAME}"
            ;;
        import)
            import_key_to_aws "${2:-$KEY_NAME}"
            ;;
        list)
            list_keys
            ;;
        delete)
            delete_key "${2:-$KEY_NAME}"
            ;;
        test)
            test_ssh_connection "$2" "${3:-$KEY_NAME}"
            ;;
        fingerprint)
            show_fingerprint "${2:-$KEY_NAME}"
            ;;
        backup)
            backup_key "${2:-$KEY_NAME}"
            ;;
        restore)
            restore_key "$2" "${3:-$KEY_NAME}"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Unknown command: ${1:-}"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
