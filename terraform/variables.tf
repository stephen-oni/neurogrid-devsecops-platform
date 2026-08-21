# 1. AWS Region & VPC Variables

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "availability_zone_1" {
  description = "Primary availability zone (AZ-a)"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_2" {
  description = "Secondary availability zone (AZ-b)"
  type        = string
  default     = "us-east-1b"
}

# 2. Subnet CIDRs (6 Subnets Across 3 Tiers)

# Public Subnets (ALB & NAT Gateways)
variable "public_subnet_cidr_1" {
  description = "CIDR block for public subnet 1 (AZ-a)"
  type        = string
  default     = "192.168.1.0/24"
}

variable "public_subnet_cidr_2" {
  description = "CIDR block for public subnet 2 (AZ-b)"
  type        = string
  default     = "192.168.2.0/24"
}

# Private App Subnets (EC2 Backend ASG Nodes)
variable "private_app_subnet_cidr_1" {
  description = "CIDR block for private application subnet 1 (AZ-a)"
  type        = string
  default     = "192.168.10.0/24"
}

variable "private_app_subnet_cidr_2" {
  description = "CIDR block for private application subnet 2 (AZ-b)"
  type        = string
  default     = "192.168.20.0/24"
}

# Private Database Subnets (RDS Multi-AZ)
variable "private_db_subnet_cidr_1" {
  description = "CIDR block for private database subnet 1 (AZ-a)"
  type        = string
  default     = "192.168.30.0/24"
}

variable "private_db_subnet_cidr_2" {
  description = "CIDR block for private database subnet 2 (AZ-b)"
  type        = string
  default     = "192.168.40.0/24"
}

# 3. Compute (EC2 Backend Auto Scaling Group)

variable "instance_type" {
  description = "EC2 instance type for backend workloads"
  type        = string
  default     = "t3.small"
}

# 4. Monitoring (Dedicated Prometheus & Grafana Instance)

variable "monitoring_instance_type" {
  description = "EC2 instance type for the dedicated Prometheus and Grafana host"
  type        = string
  default     = "t3.small"
}

# 5. Database (RDS Multi-AZ MySQL)

variable "db_name" {
  description = "Name of the default MySQL database to create"
  type        = string
  default     = "neurogrid_db"
}

variable "db_username" {
  description = "Master username for the RDS MySQL instance"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the RDS MySQL instance"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance compute type"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage limit in GB for autoscaling"
  type        = number
  default     = 100
}

# 6. ECR Module Variables

variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "neurogrid-backend"
}

variable "ecr_force_delete" {
  description = "Allow deleting the repository even if it contains images"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name tag"
  type        = string
  default     = "neurogrid"
}