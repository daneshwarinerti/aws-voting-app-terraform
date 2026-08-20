output "voting_app_ecr_repository_url" {
  description = "ECR repository URL for the voting application"
  value       = aws_ecr_repository.voting_app.repository_url
}

output "result_app_ecr_repository_url" {
  description = "ECR repository URL for the result application"
  value       = aws_ecr_repository.result_app.repository_url
}

output "worker_ecr_repository_url" {
  description = "ECR repository URL for the worker"
  value       = aws_ecr_repository.worker.repository_url
}

resource "aws_db_subnet_group" "main" {
  name = "voting-db-subnet-group"

  subnet_ids = [
    aws_subnet.db_a.id,
    aws_subnet.db_b.id
  ]

  tags = {
    Name = "voting-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "voting-postgres"

  engine         = "postgres"
  engine_version = "17"

  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"

  db_name  = "voting"
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  publicly_accessible = false

  backup_retention_period = 0

  skip_final_snapshot = true

  tags = {
    Name = "voting-postgres"
  }
}

output "postgres_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
}

output "redis_primary_endpoint" {
  description = "Primary endpoint for Redis"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "github_actions_role_arn" {
  description = "IAM role ARN used by GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}