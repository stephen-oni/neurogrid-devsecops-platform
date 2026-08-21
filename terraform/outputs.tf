# 1. Frontend & CDN Outputs

output "cloudfront_domain_name" {
  value       = module.frontend.cloudfront_domain_name
  description = "The public CloudFront URL for accessing the application"
}

output "cloudfront_distribution_id" {
  value       = module.frontend.cloudfront_distribution_id
  description = "The CloudFront Distribution ID (used for CI/CD cache invalidation)"
}

output "frontend_s3_bucket_name" {
  value       = module.frontend.s3_bucket_name
  description = "The S3 bucket name for syncing static frontend files"
}

# 2. Network & Load Balancer Outputs

output "alb_dns_name" {
  value       = module.network.alb_dns_name
  description = "Public DNS name of the Application Load Balancer"
}

output "nat_gateway_public_ips" {
  value       = module.network.nat_gateway_public_ips
  description = "Public Elastic IPs of the NAT Gateways"
}

# 3. Backend, Compute & ECR Outputs

output "backend_repository_url" {
  value       = module.ecr.repository_url
  description = "ECR repository URL for Docker push in CI/CD"
}

output "autoscaling_group_name" {
  value       = module.compute.autoscaling_group_name
  description = "Name of the backend Auto Scaling Group"
}

# 4. Database (RDS) Outputs

output "rds_endpoint" {
  value       = module.database.db_endpoint
  description = "Connection endpoint (host) for the Multi-AZ RDS MySQL instance"
}

output "rds_port" {
  value       = module.database.db_port
  description = "Port number for the RDS MySQL instance"
}

output "rds_db_name" {
  value       = module.database.db_name
  description = "Default database name created in RDS"
}