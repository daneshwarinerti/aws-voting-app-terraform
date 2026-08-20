resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "voting-app-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "voting-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.availability_zones[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "voting-public-b"
    Tier = "public"
  }
}

resource "aws_subnet" "app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "voting-app-a"
    Tier = "app"
  }
}

resource "aws_subnet" "app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "voting-app-b"
    Tier = "app"
  }
}

resource "aws_subnet" "db_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "voting-db-a"
    Tier = "database"
  }
}

resource "aws_subnet" "db_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = var.availability_zones[1]

  tags = {
    Name = "voting-db-b"
    Tier = "database"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "voting-app-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "voting-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "voting-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  tags = {
    Name = "voting-nat-gateway"
  }

  depends_on = [
    aws_internet_gateway.main
  ]
}

resource "aws_route_table" "private_app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "voting-private-app-rt"
  }
}

resource "aws_route_table_association" "app_a" {
  subnet_id      = aws_subnet.app_a.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_route_table_association" "app_b" {
  subnet_id      = aws_subnet.app_b.id
  route_table_id = aws_route_table.private_app.id
}

resource "aws_security_group" "alb" {
  name        = "voting-alb-sg"
  description = "Security group for the voting application load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Result App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "voting-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "voting-app-sg"
  description = "Security group for voting application services"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Application traffic from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "voting-app-sg"
  }
}

resource "aws_security_group" "database" {
  name        = "voting-db-sg"
  description = "Security group for PostgreSQL database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from application"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "voting-db-sg"
  }
}

resource "aws_ecr_repository" "voting_app" {
  name                 = "voting-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "voting-app"
  }
}

resource "aws_ecr_repository" "result_app" {
  name                 = "result-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "result-app"
  }
}

resource "aws_ecr_repository" "worker" {
  name                 = "worker"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "worker"
  }
}

resource "aws_security_group" "redis" {
  name        = "voting-redis-sg"
  description = "Security group for Redis"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from application"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "voting-redis-sg"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name = "voting-redis-subnet-group"

  subnet_ids = [
    aws_subnet.app_a.id,
    aws_subnet.app_b.id
  ]

  tags = {
    Name = "voting-redis-subnet-group"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "voting-redis"
  description          = "Redis for the voting application"

  engine             = "redis"
  node_type          = "cache.t4g.micro"
  num_cache_clusters = 2

  port = 6379

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  automatic_failover_enabled = true
  multi_az_enabled           = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  tags = {
    Name = "voting-redis"
  }
}

resource "aws_ecs_cluster" "main" {
  name = "voting-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "voting-app-cluster"
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "voting-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "voting-ecs-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "ecs_secrets" {
  name = "voting-ecs-secrets-policy"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:us-east-1:552823821096:secret:rds!db-3335ef2d-fe1d-4bf8-a31a-3b429cad6fea-j08F6t"
      }
    ]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = {
    Name = "github-actions-oidc"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "voting-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }

        Action = "sts:AssumeRoleWithWebIdentity"

        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"

            "token.actions.githubusercontent.com:sub" = "repo:daneshwarinerti@185830653/aws-voting-app-terraform@1340267329:ref:refs/heads/main"
          }
        }
      }
    ]
  })

  tags = {
    Name = "voting-github-actions-role"
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  name = "voting-github-ecr-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },
      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = [
          aws_ecr_repository.voting_app.arn,
          aws_ecr_repository.result_app.arn,
          aws_ecr_repository.worker.arn
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "voting" {
  name              = "/ecs/voting-app"
  retention_in_days = 7

  tags = {
    Name = "voting-app-logs"
  }
}

resource "aws_ecs_task_definition" "voting" {
  family                   = "voting-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "voting-app"
      image     = "${aws_ecr_repository.voting_app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_replication_group.redis.primary_endpoint_address
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = "/ecs/voting-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "voting"
        }
      }
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.voting
  ]

  tags = {
    Name = "voting-app-task"
  }
}

resource "aws_cloudwatch_log_group" "result" {
  name              = "/ecs/result-app"
  retention_in_days = 7

  tags = {
    Name = "result-app-logs"
  }
}

resource "aws_ecs_task_definition" "result" {
  family                   = "result-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "result-app"
      image     = "${aws_ecr_repository.result_app.repository_url}:fix1"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "POSTGRES_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "POSTGRES_USER"
          value = var.db_username
        },
    
        {
          name  = "POSTGRES_DATABASE"
          value = "voting"
        }
      ]

       secrets = [
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = "/ecs/result-app"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "result"
        }
      }
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.result
  ]

  tags = {
    Name = "result-app-task"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/worker"
  retention_in_days = 7

  tags = {
    Name = "worker-logs"
  }
}

resource "aws_ecs_task_definition" "worker" {
  family                   = "worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn

  container_definitions = jsonencode([
    {
      name      = "worker"
      image     = "${aws_ecr_repository.worker.repository_url}:fix2"
      essential = true

      environment = [
        {
          name  = "POSTGRES_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "POSTGRES_USER"
          value = var.db_username
        },
      
        {
          name  = "POSTGRES_DATABASE"
          value = "voting"
        },
        {
          name  = "REDIS_HOST"
          value = aws_elasticache_replication_group.redis.primary_endpoint_address
        }
      ]

      secrets = [
  {
    name      = "POSTGRES_PASSWORD"
    valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
  }
]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = "/ecs/worker"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  depends_on = [
    aws_cloudwatch_log_group.worker
  ]

  tags = {
    Name = "worker-task"
  }
}
resource "aws_ecs_service" "voting" {
  name            = "voting-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.voting.arn

  desired_count = 2
  launch_type   = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.app_a.id,
      aws_subnet.app_b.id
    ]

    security_groups = [
      aws_security_group.app.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.voting.arn
    container_name   = "voting-app"
    container_port   = 80
  }

  tags = {
    Name = "voting-service"
  }
}

resource "aws_ecs_service" "worker" {
  name            = "worker-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.app_a.id,
      aws_subnet.app_b.id
    ]

    security_groups = [
      aws_security_group.app.id
    ]

    assign_public_ip = false
  }

  tags = {
    Name = "worker-service"
  }
}

resource "aws_ecs_service" "result" {
  name            = "result-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.result.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets = [
      aws_subnet.app_a.id,
      aws_subnet.app_b.id
    ]

    security_groups = [
      aws_security_group.app.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.result.arn
    container_name   = "result-app"
    container_port   = 80
  }

  tags = {
    Name = "result-service"
  }
}

resource "aws_lb" "main" {
  name               = "voting-app-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "voting-app-alb"
  }
}

resource "aws_lb_target_group" "voting" {
  name        = "voting-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "voting-target-group"
  }
}

resource "aws_lb_target_group" "result" {
  name        = "result-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "result-target-group"
  }
}

resource "aws_lb_listener" "voting" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.voting.arn
  }

  tags = {
    Name = "voting-http-listener"
  }
}

resource "aws_lb_listener_rule" "result" {
  listener_arn = aws_lb_listener.voting.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result.arn
  }

  condition {
    path_pattern {
      values = ["/result*"]
    }
  }
}

resource "aws_lb_listener" "result" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.result.arn
  }

  tags = {
    Name = "result-http-listener"
  }
}