output "monitoring_instance_id" {
  value       = aws_instance.monitoring.id
  description = "EC2 Instance ID of the Monitoring host"
}

output "monitoring_public_ip" {
  value       = aws_instance.monitoring.public_ip
  description = "Public IP address of the Monitoring server"
}

output "monitoring_sg_id" {
  value       = aws_security_group.monitoring_sg.id
  description = "Security Group ID of the Monitoring server"
}