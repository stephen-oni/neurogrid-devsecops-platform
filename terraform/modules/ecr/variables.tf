variable "repository_name" {
  type        = string
  default     = "neurogrid-backend"
  description = "Name of the ECR repository"
}

variable "force_delete" {
  type        = bool
  default     = false
  description = "Allow deleting the repository even if it contains images"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment name"
}

variable "project_name" {
  type        = string
  default     = "neurogrid"
  description = "Project name tag"
}