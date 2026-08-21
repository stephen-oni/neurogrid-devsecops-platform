variable "vpc_id" {
  type        = string
  description = "VPC ID where the monitoring instance is deployed"
}

variable "public_subnet_id" {
  type        = string
  description = "Public Subnet ID to place the monitoring instance"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
  description = "EC2 Instance type for Prometheus and Grafana"
}