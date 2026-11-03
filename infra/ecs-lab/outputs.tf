output "account_id" {
  description = "ID de la cuenta AWS utilizada por Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Región AWS configurada"
  value       = data.aws_region.current.name
}

output "vpc_id" {
  description = "VPC existente para el laboratorio ECS"
  value       = data.aws_vpc.default.id
}

output "ecr_repository_url" {
  description = "URI del repositorio ECR existente"
  value       = data.aws_ecr_repository.aws_sdk_s3_lab.repository_url
}

output "alb_dns_name" {
  description = "DNS público del Application Load Balancer"
  value       = aws_lb.api.dns_name
}

output "alb_url_http" {
  description = "URL HTTP de la API a través del ALB"
  value       = "http://${aws_lb.api.dns_name}"
}