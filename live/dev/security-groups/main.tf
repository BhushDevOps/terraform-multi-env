terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

module "security_groups_primary" {
  source = "../../../modules/security-groups"

  providers = {
    aws = aws
  }

  vpc_id = var.primary_vpc_id
}

module "security_groups_secondary" {
  source = "../../../modules/security-groups"

  providers = {
    aws = aws.secondary
  }

  vpc_id = var.secondary_vpc_id
}

moved {
  from = aws_security_group.app_sg
  to   = module.security_groups_primary.aws_security_group.app_sg
}

moved {
  from = aws_security_group.test
  to   = module.security_groups_primary.aws_security_group.test
}