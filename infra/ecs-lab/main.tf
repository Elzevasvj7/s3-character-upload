
locals {
  app_name    = "aws-sdk-s3-lab"
  bucket_name = "my-lab-bucket-nando"
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"
}

data "aws_region" "current" {}

data "aws_ecr_repository" "app" {
  name = local.app_name
}

data "aws_vpc" "default" {
  default = true
}

# Logs de la aplicación: los conservamos durante siete días.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${local.app_name}"
  retention_in_days = 7
}

# Clúster lógico de ECS.
resource "aws_ecs_cluster" "lab" {
  name = local.app_name
  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }
}

# Política de confianza compartida por ambos roles de ECS.
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Rol utilizado por ECS para descargar la imagen y enviar logs.
resource "aws_iam_role" "execution" {
  name               = "${local.app_name}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  description        = "Permite a ECS descargar la imagen de ECR y enviar logs a CloudWatch."
  tags = {
    Project = "aws-sdk-s3-lab"
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role = aws_iam_role.execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Rol que utilizará el código de NestJS dentro del contenedor.
resource "aws_iam_role" "task" {
  name               = "${local.app_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  description        = "Rol de ejecucion de NestJS con permisios limitados para S3"
}

resource "aws_iam_policy" "task_s3" {
  name        = "AWSDKSS3LabTaskS3Policy"
  description = "Permite a NestJS leer y listar cloudfront-demo y subir objetos a presigned-upload-demo."

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "ReadDemoObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${local.bucket_arn}/cloudfront-demo/*"]
      },
      {
        Sid      = "ListDemoPrefix"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [local.bucket_arn]

        Condition = {
          StringLike = {
            "s3:prefix" = [
              "cloudfront-demo/",
              "cloudfront-demo/*"
            ]
          }
        }
      },
      {
        Sid      = "UploadDemoObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${local.bucket_arn}/presigned-upload-demo/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_s3.arn
}

# Grupo de seguridad: permite acceder a la API desde la IP configurada.
resource "aws_security_group" "api" {
  name        = "${local.app_name}-sg"
  description = "Access to NestJS lab API from my public IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Allow ALB to reach ECS tasks"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Punto de entrada HTTP de la API.
resource "aws_security_group" "alb" {
  name        = "${local.app_name}-alb-sg"
  description = "Access to NestJS lab through ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Temporary HTTP access to ALB for lab"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.alb_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${local.app_name}-alb-sg"
    Project = local.app_name
  }
}
# Application Load Balancer 
resource "aws_lb" "api" {
  name               = "${local.app_name}-alb"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    data.aws_subnet.us_east_2a.id,
    data.aws_subnet.us_east_2b.id,
    data.aws_subnet.us_east_2c.id
  ]

  enable_deletion_protection = false

  tags = {
    Name    = "${local.app_name}-alb"
    Project = local.app_name
  }
}
# Target group del Balanceador de Carga
resource "aws_lb_target_group" "api" {
  name             = "${local.app_name}-tg"
  port             = 80
  protocol         = "HTTP"
  protocol_version = "HTTP1"
  target_type      = "ip"
  ip_address_type  = "ipv4"
  vpc_id           = data.aws_vpc.default.id

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/aws-s3/version"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "${local.app_name}-tg"
    Project = local.app_name
  }
}
# Listener del balanceador de carga
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn

    forward {
      stickiness {
        duration = 3600
      }
      target_group {
        arn = aws_lb_target_group.api.arn
      }
    }
  }
}

# Definición: especifica cómo se ejecuta el contenedor.
resource "aws_ecs_task_definition" "api" {
  family                   = local.app_name
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  enable_fault_injection   = false
  skip_destroy             = true

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = local.app_name
      image     = "${data.aws_ecr_repository.app.repository_url}:v2"
      cpu       = 0
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
          name          = "${local.app_name}-3000-tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "S3_BUCKET"
          value = local.bucket_name
        },
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.region
        }
      ]

      environmentFiles = []
      mountPoints      = []
      volumesFrom      = []
      ulimits          = []
      systemControls   = []

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-create-group"  = "true"
          "awslogs-region"        = data.aws_region.current.region
          "awslogs-stream-prefix" = "ecs"
        }

        secretOptions = []
      }
    }
  ])
}
# Servicio que mantiene una tarea Fargate ejecutándose.
resource "aws_ecs_service" "api" {
  enable_ecs_managed_tags           = true
  name                              = "${local.app_name}-service-vfg4nkkf"
  cluster                           = aws_ecs_cluster.lab.id
  task_definition                   = "${aws_ecs_task_definition.api.family}:${aws_ecs_task_definition.api.revision}"
  desired_count                     = 1
  launch_type                       = "FARGATE"
  wait_for_steady_state             = false
  health_check_grace_period_seconds = 60

  lifecycle {
    ignore_changes = [task_definition]
  }

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
    ]
    security_groups  = [aws_security_group.api.id]
    assign_public_ip = false
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = local.app_name
    container_port   = 3000
  }

  depends_on = [
    aws_route_table_association.private_a,
    aws_route_table_association.private_b,
    aws_route.private_default,
    aws_vpc_endpoint.s3,
    aws_iam_role_policy_attachment.execution_managed,
    aws_iam_role_policy_attachment.task_s3,
    aws_lb_listener.http
  ]
}

output "ecr_image" {
  description = "Imagen de ECR utilizada por la aplicación"
  value       = "${data.aws_ecr_repository.app.repository_url}:v2"
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.lab.name
}

output "ecs_service_name" {
  value = aws_ecs_service.api.name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.api.name
}
