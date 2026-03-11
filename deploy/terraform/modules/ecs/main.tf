# -----------------------------------------------------------------------------
# ECS Module - Fargate cluster and RAGFlow service
# -----------------------------------------------------------------------------
# ECS cluster, Fargate capacity, ALB, task definition with RAGFlow container.
# RAGFlow runs with DOC_ENGINE=opensearch, STORAGE_IMPL=AWS_S3, external MySQL/Redis/OpenSearch.
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.name_prefix}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "ragflow" {
  name              = "/ecs/${var.name_prefix}-ragflow"
  retention_in_days = 14

  tags = {
    Name = "${var.name_prefix}-ragflow-logs"
  }
}

# Task execution role (for ECR pull, CloudWatch, secrets)
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role (for S3 access from RAGFlow app)
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "ecs-tasks.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "task_s3" {
  name = "${var.name_prefix}-task-s3"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:HeadObject",
          "s3:CreateBucket",
          "s3:DeleteBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Security group for ALB
resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "ALB for RAGFlow"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-alb-sg"
  }
}

# Security group for ECS tasks
resource "aws_security_group" "ecs" {
  name_prefix = "${var.name_prefix}-ecs-"
  description = "ECS tasks for RAGFlow"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ecs-sg"
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.name_prefix}-alb"
  }
}

# Target group
resource "aws_lb_target_group" "ragflow" {
  name        = "${var.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/v1/system/healthz"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "${var.name_prefix}-tg"
  }
}

# HTTP listener (redirect to HTTPS if cert provided)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action = var.acm_certificate_arn != "" ? {
    type = "redirect"
    redirect = {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  } : {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ragflow.arn
  }
}

# HTTPS listener (optional)
resource "aws_lb_listener" "https" {
  count = var.acm_certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ragflow.arn
  }
}

# Task definition
resource "aws_ecs_task_definition" "ragflow" {
  family                   = "${var.name_prefix}-ragflow"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  execution_role_arn = aws_iam_role.execution.arn
  task_role_arn      = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "ragflow"
      image = "${var.ecr_repository_url}:${var.image_tag}"

      essential = true

      portMappings = [
        { containerPort = 80, protocol = "tcp" }
      ]

      environment = [
        { name = "DOC_ENGINE", value = "opensearch" },
        { name = "STORAGE_IMPL", value = "AWS_S3" },
        { name = "DEVICE", value = "cpu" },
        { name = "MYSQL_HOST", value = var.mysql_endpoint },
        { name = "MYSQL_PORT", value = tostring(var.mysql_port) },
        { name = "MYSQL_DBNAME", value = var.mysql_db_name },
        { name = "MYSQL_USER", value = "admin" },
        { name = "OS_HOSTS", value = var.opensearch_endpoint },
        { name = "OPENSEARCH_PASSWORD", value = var.opensearch_password },
        { name = "OS_USER", value = "admin" },
        { name = "REDIS_HOST", value = var.redis_endpoint },
        { name = "REDIS_PORT", value = tostring(var.redis_port) },
        { name = "REDIS_PASSWORD", value = var.redis_auth_token },
        { name = "S3_BUCKET", value = var.s3_bucket_name },
        { name = "AWS_REGION", value = var.aws_region }
      ]

      secrets = [
        { name = "MYSQL_PASSWORD", valueFrom = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/ragflow/${var.environment}/mysql-password" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ragflow.name
          "awslogs-region"       = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost/v1/system/healthz || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 120
      }
    }
  ])

  depends_on = [aws_ssm_parameter.mysql_password]

  tags = {
    Name = "${var.name_prefix}-ragflow"
  }
}

# Store MySQL password in SSM (needed for task definition secrets)
resource "aws_ssm_parameter" "mysql_password" {
  name  = "/ragflow/${var.environment}/mysql-password"
  type  = "SecureString"
  value = var.mysql_password

  tags = {
    Name = "${var.name_prefix}-mysql-password"
  }
}

# ECS service
resource "aws_ecs_service" "ragflow" {
  name            = "${var.name_prefix}-ragflow"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.ragflow.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ragflow.arn
    container_name   = "ragflow"
    container_port  = 80
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ssm_parameter.mysql_password
  ]

  tags = {
    Name = "${var.name_prefix}-ragflow"
  }
}

data "aws_caller_identity" "current" {}
