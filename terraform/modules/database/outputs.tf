output "db_endpoint" {
  value       = aws_db_instance.mysql.address
  description = "The connection host address (DNS endpoint) for the RDS MySQL instance"
}

output "db_port" {
  value       = aws_db_instance.mysql.port
  description = "The port the database is listening on"
}

output "db_name" {
  value       = aws_db_instance.mysql.db_name
  description = "The name of the default database created on RDS"
}

output "db_arn" {
  value       = aws_db_instance.mysql.arn
  description = "The ARN of the RDS MySQL instance"
}

output "db_subnet_group_name" {
  value       = aws_db_subnet_group.rds_subnet_group.name
  description = "The name of the RDS database subnet group"
}