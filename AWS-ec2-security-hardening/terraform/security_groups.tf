# Enhanced security group configuration with multiple security layers

# Main EC2 security group
resource "aws_security_group" "ec2_main" {
  name        = "ec2-security-main-sg"
  description = "Main security group for EC2 instances with strict access controls"
  vpc_id      = aws_vpc.main.id

  # SSH access restricted to specific IP ranges
  dynamic "ingress" {
    for_each = var.allowed_ssh_ips
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH access from ${ingress.value}"
    }
  }

  # HTTP access (if needed for web applications)
  dynamic "ingress" {
    for_each = var.enable_http ? [1] : []
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP access from anywhere"
    }
  }

  # HTTPS access (if needed for web applications)
  dynamic "ingress" {
    for_each = var.enable_https ? [1] : []
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS access from anywhere"
    }
  }

  # Custom application ports (if specified)
  dynamic "ingress" {
    for_each = var.custom_ports
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = "Custom port access: ${ingress.value.description}"
    }
  }

  # Egress rules - restrictive outbound access
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP outbound for package updates"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS outbound for package updates"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow DNS outbound"
  }

  # Allow NTP for time synchronization
  egress {
    from_port   = 123
    to_port     = 123
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow NTP outbound for time sync"
  }

  tags = {
    Name        = "ec2-security-main-sg"
    Project     = "AWS EC2 Security"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security group for load balancer (if needed)
resource "aws_security_group" "elb_sg" {
  count       = var.create_load_balancer ? 1 : 0
  name        = "ec2-security-elb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }

  # HTTPS from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  # Allow traffic to EC2 instances
  egress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_main.id]
    description     = "Allow SSH to EC2 instances"
  }

  egress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_main.id]
    description     = "Allow HTTP to EC2 instances"
  }

  egress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_main.id]
    description     = "Allow HTTPS to EC2 instances"
  }

  tags = {
    Name        = "ec2-security-elb-sg"
    Project     = "AWS EC2 Security"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Security group rule to allow traffic from ELB to EC2
resource "aws_security_group_rule" "elb_to_ec2_http" {
  count                     = var.create_load_balancer ? 1 : 0
  type                      = "ingress"
  from_port                 = 80
  to_port                   = 80
  protocol                  = "tcp"
  security_group_id        = aws_security_group.ec2_main.id
  source_security_group_id = aws_security_group.elb_sg[0].id
  description               = "Allow HTTP from ELB"
}

resource "aws_security_group_rule" "elb_to_ec2_https" {
  count                     = var.create_load_balancer ? 1 : 0
  type                      = "ingress"
  from_port                 = 443
  to_port                   = 443
  protocol                  = "tcp"
  security_group_id        = aws_security_group.ec2_main.id
  source_security_group_id = aws_security_group.elb_sg[0].id
  description               = "Allow HTTPS from ELB"
}
