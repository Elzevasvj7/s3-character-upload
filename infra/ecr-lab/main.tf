resource "aws_ecr_repository" "aws_sdk_s3_lab" {
  name                 = "aws-sdk-s3-lab"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = "aws-sdk-s3-lab"
    Environment = "Lab"
  }
  image_scanning_configuration {
    scan_on_push = true
  }
}

output "repository_url" {
  description = "URL del repositorio privado de ECR"
  value       = aws_ecr_repository.aws_sdk_s3_lab.repository_url
}
