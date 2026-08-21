# 1. Network Module (VPC, 6 Subnets, NAT Gateways, Security Groups, ALB)
module "network" {
  source = "./modules/network"

  vpc_cidr                  = var.vpc_cidr
  availability_zone_1       = var.availability_zone_1
  availability_zone_2       = var.availability_zone_2
  public_subnet_cidr_1      = var.public_subnet_cidr_1
  public_subnet_cidr_2      = var.public_subnet_cidr_2
  private_app_subnet_cidr_1 = var.private_app_subnet_cidr_1
  private_app_subnet_cidr_2 = var.private_app_subnet_cidr_2
  private_db_subnet_cidr_1  = var.private_db_subnet_cidr_1
  private_db_subnet_cidr_2  = var.private_db_subnet_cidr_2
}

# 2. Compute Module (Auto Scaling Group, Launch Template, SSM/ECR IAM Profile)
module "compute" {
  source = "./modules/compute"

  vpc_id                 = module.network.vpc_id
  private_app_subnet_ids = module.network.private_app_subnet_ids
  app_security_group_id  = module.network.app_security_group_id
  alb_target_group_arn   = module.network.alb_target_group_arn
  instance_type          = var.instance_type
}

# 3. Database Module (Multi-AZ RDS MySQL & Subnet Group)
module "database" {
  source = "./modules/database"

  private_db_subnet_ids = module.network.private_db_subnet_ids
  db_security_group_id  = module.network.db_security_group_id
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  db_instance_class     = var.db_instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
}

# 4. ECR Module (Container Registry & Lifecycle Retention)
module "ecr" {
  source = "./modules/ecr"

  repository_name = var.repository_name
  force_delete    = var.ecr_force_delete
  environment     = var.environment
  project_name    = var.project_name
}

# 5. Frontend Module (S3 Static Assets + CloudFront OAC + ALB Reverse Proxy)
module "frontend" {
  source = "./modules/frontend"

  alb_dns_name = module.network.alb_dns_name
}