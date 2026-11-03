resource "aws_security_group" "vpc_endpoints" {
  name        = "${local.app_name}-vpce-sg"
  description = "Allow ECS tasks to access AWS interface endpoints over HTTPS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR API Interface Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-2.ecr.api"
  vpc_endpoint_type = "Interface"

  subnet_ids         = [aws_subnet.private_a.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "aws-sdk-s3-lab-ecr-api"
  }
}

# ECR Docker Registry Interface Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-2.ecr.dkr"
  vpc_endpoint_type = "Interface"

  subnet_ids         = [aws_subnet.private_a.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "aws-sdk-s3-lab-ecr-dkr"
  }
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.us-east-2.logs"
  vpc_endpoint_type = "Interface"

  subnet_ids         = [aws_subnet.private_a.id]
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "aws-sdk-s3-lab-cloudwatch-logs"
  }
}