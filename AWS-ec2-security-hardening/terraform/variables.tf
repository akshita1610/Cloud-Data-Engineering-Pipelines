variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag for resources"
  type        = string
  default     = "dev"
}

variable "ami_id" {
  description = "AMI ID for EC2 instance"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 AMI
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the AWS key pair"
  type        = string
  default     = "ec2-security-key"
}

variable "public_key_path" {
  description = "Path to the public key file"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "new_username" {
  description = "Username for the new user to create on the instance"
  type        = string
  default     = "secureuser"
}

variable "alert_email" {
  description = "Email address for CloudWatch alerts"
  type        = string
  default     = ""
}

variable "allowed_ssh_ips" {
  description = "List of CIDR blocks allowed to access SSH"
  type        = list(string)
  default     = []
}

variable "enable_http" {
  description = "Enable HTTP access"
  type        = bool
  default     = false
}

variable "enable_https" {
  description = "Enable HTTPS access"
  type        = bool
  default     = false
}

variable "custom_ports" {
  description = "List of custom ports to open"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "create_load_balancer" {
  description = "Create a load balancer security group"
  type        = bool
  default     = false
}
