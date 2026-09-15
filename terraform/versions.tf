terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # O bucket e a tabela de lock são criados fora do Terraform (ovo e galinha).
  # bucket/region/dynamodb_table chegam via -backend-config no pipeline.
  backend "s3" {
    key = "infra-db/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Projeto   = var.projeto
      Repo      = "oficina-infra-db"
      ManagedBy = "terraform"
    }
  }
}
