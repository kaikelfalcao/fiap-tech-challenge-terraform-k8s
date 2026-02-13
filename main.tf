terraform {
  backend "s3" {
    bucket         = "fiap-tech-challenge-tfstate-fase3"
    key            = "k8s-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fiap-tech-challenge-tflock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "fiap-tech-challenge-terraform-k8s"
    }
  }
}
