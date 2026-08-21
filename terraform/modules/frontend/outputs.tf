output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.cdn.domain_name
  description = "The public domain URL of the CloudFront distribution"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.cdn.id
  description = "The ID of the CloudFront distribution (used for CI/CD cache invalidation)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.bucket
  description = "The name of the frontend S3 bucket for build artifact upload"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.frontend.arn
  description = "ARN of the frontend S3 bucket"
}