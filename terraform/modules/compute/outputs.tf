# Auto Scaling Group Outputs 

output "autoscaling_group_name" {
  value       = aws_autoscaling_group.backend_asg.name
  description = "Name of the Auto Scaling Group (used for targeting SSM deployments or monitoring)"
}

output "autoscaling_group_arn" {
  value       = aws_autoscaling_group.backend_asg.arn
  description = "ARN of the Auto Scaling Group"
}


# Launch Template Outputs 

output "launch_template_id" {
  value       = aws_launch_template.backend.id
  description = "ID of the Launch Template driving the ASG instances"
}

output "launch_template_latest_version" {
  value       = aws_launch_template.backend.latest_version
  description = "Latest version number of the EC2 Launch Template"
}


# IAM Profile Output 

output "iam_instance_profile_name" {
  value       = aws_iam_instance_profile.ec2_profile.name
  description = "IAM instance profile attached to backend instances"
}