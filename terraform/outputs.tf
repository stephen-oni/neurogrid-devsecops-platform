output "rds_endpoint" {
  value       = module.database.db_endpoint
  description = "RDS MySQL Host Address"
}

output "autoscaling_group_name" {
  value       = module.compute.autoscaling_group_name
  description = "Name of the Auto Scaling Group"
}

output "frontend_s3_bucket_name" {
  value       = module.frontend.s3_bucket_name
  description = "S3 bucket for frontend assets"
}

output "cloudfront_distribution_id" {
  value       = module.frontend.cloudfront_distribution_id
  description = "CloudFront distribution ID for cache invalidations"
}