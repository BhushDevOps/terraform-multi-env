terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region

  # Safety net: refuses to run if the credentials point at a different account
  # than the one this tfvars file describes.
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Account   = var.account_alias # dev / test / prod
      Layer     = "02-eks"          # shared by every env in the account
      Project   = var.project
      Owner     = var.owner
      ManagedBy = "terraform"
    }
  }
}
