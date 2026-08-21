variable "private_db_subnet_ids" {
  type        = list(string)
  description = "List of private DB subnet IDs spanning AZ-a and AZ-b for the RDS Subnet Group"
}

variable "db_security_group_id" {
  type        = string
  description = "Security group ID from the network module allowing MySQL 3306 from backend EC2s"
}

variable "db_name" {
  type        = string
  default     = "neurogrid_db"
  description = "Name of the default MySQL database to create"
}

variable "db_username" {
  type        = string
  default     = "admin"
  description = "Master username for RDS MySQL"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Master password for RDS MySQL"
}

variable "db_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "RDS instance compute type"
}

variable "allocated_storage" {
  type        = number
  default     = 20
  description = "Initial allocated storage in GB"
}

variable "max_allocated_storage" {
  type        = number
  default     = 100
  description = "Maximum storage limit in GB for autoscaling"
}