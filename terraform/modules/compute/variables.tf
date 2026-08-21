variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be deployed"
}

variable "private_app_subnet_ids" {
  type        = list(string)
  description = "List of private app subnet IDs across AZ-a and AZ-b for the Auto Scaling Group"
}

variable "app_security_group_id" {
  type        = string
  description = "Security Group ID allowing inbound traffic strictly from the ALB"
}

variable "alb_target_group_arn" {
  type        = string
  description = "ARN of the Application Load Balancer Target Group for health checks and traffic routing"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for backend workloads"
}