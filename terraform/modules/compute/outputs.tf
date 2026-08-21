output "autoscaling_group_name" {
  value       = aws_autoscaling_group.backend_asg.name
  description = "The name of the Auto Scaling Group"
}

output "autoscaling_group_arn" {
  value       = aws_autoscaling_group.backend_asg.arn
  description = "The ARN of the Auto Scaling Group"
}

output "launch_template_id" {
  value       = aws_launch_template.backend.id
  description = "The ID of the backend Launch Template"
}

output "launch_template_latest_version" {
  value       = aws_launch_template.backend.latest_version
  description = "The latest version of the Launch Template"
}