terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Get current IP address for security group
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "ec2-security-vpc"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "ec2-security-public-subnet"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "ec2-security-igw"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "ec2-security-rt"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Associate route table with subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create key pair
resource "aws_key_pair" "deployer" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  tags = {
    Name        = "ec2-security-keypair"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create security group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-sg"
  description = "Security group for EC2 instance with SSH access restricted to current IP"
  vpc_id      = aws_vpc.main.id

  # SSH access from current IP only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
    description = "SSH access from current IP"
  }

  # HTTP access (optional)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access from anywhere"
  }

  # HTTPS access (optional)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access from anywhere"
  }

  # Egress - allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "ec2-security-sg"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create EC2 instance
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name               = aws_key_pair.deployer.key_name

  # User data script for initial setup
  user_data = base64encode(templatefile("${path.module}/../scripts/user-data.sh", {
    new_username = var.new_username
  }))

  # Root block device
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = "ec2-security-instance"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create CloudWatch alarm for CPU utilization
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "ec2-security-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_sns_topic.cloudwatch_alerts.arn]

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = {
    Name        = "ec2-security-cpu-alarm"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Create SNS topic for CloudWatch alerts
resource "aws_sns_topic" "cloudwatch_alerts" {
  name = "ec2-security-alerts"

  tags = {
    Name        = "ec2-security-sns"
    Project     = "AWS EC2 Security"
    Environment = var.environment
  }
}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
