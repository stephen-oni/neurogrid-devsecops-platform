terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "stephenoni67"

    workspaces {
      name = "neurogrid"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "NeuroGrid"
      Environment = "var.environment"
      ManagedBy   = "Terraform"
    }
  }
}

provider "random" {}

provider "tls" {}

