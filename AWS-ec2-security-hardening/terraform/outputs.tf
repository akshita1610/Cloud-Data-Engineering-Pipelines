output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.ec2_sg.id
}

output "key_pair_name" {
  description = "Name of the key pair"
  value       = aws_key_pair.deployer.key_name
}

output "cloudwatch_alarm_name" {
  description = "Name of the CloudWatch alarm"
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.cloudwatch_alerts.arn
}

output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i \"${var.key_name}.pem\" ec2-user@${aws_instance.web.public_dns}"
}
