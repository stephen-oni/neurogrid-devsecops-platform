# VPC Outputs 
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The ID of the VPC"
}

output "vpc_cidr_block" {
  value       = aws_vpc.main.cidr_block
  description = "The CIDR block of the VPC"
}

# Subnet Outputs 
output "public_subnet_ids" {
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  description = "List of public subnet IDs (ALB, NAT Gateways & Monitoring Host)"
}

output "private_app_subnet_ids" {
  value       = [aws_subnet.private_app_1.id, aws_subnet.private_app_2.id]
  description = "List of private app subnet IDs for the EC2 compute tier"
}

output "private_db_subnet_ids" {
  value       = [aws_subnet.private_db_1.id, aws_subnet.private_db_2.id]
  description = "List of private database subnet IDs for the RDS Multi-AZ DB subnet group"
}

# Security Group Outputs 
output "alb_security_group_id" {
  value       = aws_security_group.alb_sg.id
  description = "Security Group ID attached to the Application Load Balancer"
}

output "app_security_group_id" {
  value       = aws_security_group.app_sg.id
  description = "Security Group ID attached to backend EC2 instances"
}

output "db_security_group_id" {
  value       = aws_security_group.db_sg.id
  description = "Security Group ID attached to the RDS instance"
}

# Load Balancer Outputs
output "alb_arn" {
  value       = aws_lb.api_alb.arn
  description = "ARN of the Application Load Balancer"
}

output "alb_dns_name" {
  value       = aws_lb.api_alb.dns_name
  description = "Public DNS name of the Application Load Balancer"
}

output "alb_target_group_arn" {
  value       = aws_lb_target_group.api_tg.arn
  description = "ARN of the ALB Target Group"
}

# NAT Gateway Outputs 
output "nat_gateway_public_ips" {
  value       = [aws_eip.nat_1.public_ip, aws_eip.nat_2.public_ip]
  description = "Public Elastic IP addresses assigned to the NAT Gateways"
}