# Database Outputs
output "rds_endpoint" {
  value       = nonsensitive(module.database.db_endpoint)
  description = "RDS MySQL Host Address"
}

# Compute Tier Outputs
output "autoscaling_group_name" {
  value       = module.compute.autoscaling_group_name
  description = "Name of the Auto Scaling Group"
}

# Frontend / CDN Outputs
output "frontend_s3_bucket_name" {
  value       = module.frontend.s3_bucket_name
  description = "S3 bucket for frontend assets"
}

output "cloudfront_distribution_id" {
  value       = module.frontend.cloudfront_distribution_id
  description = "CloudFront distribution ID for cache invalidations"
}

output "cloudfront_domain_name" {
  value       = module.frontend.cloudfront_domain_name
  description = "Domain name / CDN URL of the CloudFront distribution"
}

# Application Load Balancer
output "alb_dns_name" {
  value       = module.network.alb_dns_name
  description = "Direct Application Load Balancer DNS endpoint"
}

# Container Registry Outputs
output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "ECR Repository URL for CI/CD Docker image push"
}

# Monitoring Outputs (Private SSM Tunnel Access)
output "monitoring_instance_id" {
  value       = module.monitoring.monitoring_instance_id
  description = "EC2 Instance ID for SSM Port Forwarding sessions"
}

output "monitoring_ssm_grafana_tunnel_command" {
  value       = "aws ssm start-session --target ${module.monitoring.monitoring_instance_id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"3000\"],\"localPortNumber\":[\"3000\"]}'"
  description = "Run this command to securely open Grafana at http://localhost:3000"
}

output "monitoring_ssm_prometheus_tunnel_command" {
  value       = "aws ssm start-session --target ${module.monitoring.monitoring_instance_id} --document-name AWS-StartPortForwardingSession --parameters '{\"portNumber\":[\"9090\"],\"localPortNumber\":[\"9090\"]}'"
  description = "Run this command to securely open Prometheus at http://localhost:9090"
}