# 1. DB Subnet Group across the 2 Private DB Subnets

resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "neurogrid-db-subnet-group"
  subnet_ids  = var.private_db_subnet_ids
  description = "Subnet group for Multi-AZ RDS MySQL spanning private database subnets"

  tags = {
    Name = "neurogrid-db-subnet-group"
  }
}

# 2. Multi-AZ AWS Managed MySQL RDS Instance

resource "aws_db_instance" "mysql" {
  identifier             = "neurogrid-mysql-db"
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = var.db_instance_class
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [var.db_security_group_id]
  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "neurogrid-mysql-rds"
  }
}