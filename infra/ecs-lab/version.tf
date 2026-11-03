terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68.0"
    }
  }
  backend "s3" {
    bucket       = "tfstate-aws-lab-489323024051-us-east-2"
    key          = "ecs-lab/terraform.tfstate"
    region       = "us-east-2"
    profile      = "default"
    use_lockfile = true
  }
}
