data "aws_caller_identity" "current" {}

# Subredes públicas existentes.
data "aws_subnet" "us_east_2a" {
  id = "subnet-05314d72d93e65234"
}

data "aws_subnet" "us_east_2b" {
  id = "subnet-0c2c1e14ba72cbd26"
}

data "aws_subnet" "us_east_2c" {
  id = "subnet-0fcdc14922678c823"
}

data "aws_ecr_repository" "aws_sdk_s3_lab" {
  name = "aws-sdk-s3-lab"
}
