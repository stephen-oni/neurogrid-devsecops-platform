# VPC & Availability Zones
variable "vpc_cidr" {
  type        = string
  default     = "192.168.0.0/16"
  description = "Private IP block for the VPC"
}

variable "availability_zone_1" {
  type        = string
  default     = "us-east-1a"
  description = "Primary availability zone"
}

variable "availability_zone_2" {
  type        = string
  default     = "us-east-1b"
  description = "Secondary availability zone"
}

# 2 Public Subnets (ALB, NAT Gateways & Monitoring Host)
variable "public_subnet_cidr_1" {
  type        = string
  default     = "192.168.1.0/24"
  description = "CIDR block for public subnet 1"
}

variable "public_subnet_cidr_2" {
  type        = string
  default     = "192.168.2.0/24"
  description = "CIDR block for public subnet 2"
}

# 2 Private App Subnets (ASG Compute Tier)
variable "private_app_subnet_cidr_1" {
  type        = string
  default     = "192.168.10.0/24"
  description = "CIDR block for private app subnet 1"
}

variable "private_app_subnet_cidr_2" {
  type        = string
  default     = "192.168.20.0/24"
  description = "CIDR block for private app subnet 2"
}

# 2 Private Database Subnets (RDS Multi-AZ)
variable "private_db_subnet_cidr_1" {
  type        = string
  default     = "192.168.30.0/24"
  description = "CIDR block for private DB subnet 1"
}

variable "private_db_subnet_cidr_2" {
  type        = string
  default     = "192.168.40.0/24"
  description = "CIDR block for private DB subnet 2"
}