# One-time bootstrap: creates the S3 bucket and DynamoDB table that hold
# Terraform state for ONE AWS ACCOUNT. Run it once per account with local
# state, then never touch it again.
#
# All environments inside that account (env1, env2, env3 ...) share this one
# bucket and one lock table. They stay apart because each has its own KEY:
#   dev/env1/app/terraform.tfstate
#   dev/env2/app/terraform.tfstate
#
#   terraform init
#   terraform apply -var="project=demoapp" -var="account_alias=dev" -var="account_id=111111111111"

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "project" { type = string }
variable "account_alias" { type = string }
variable "account_id" { type = string }
variable "region" {
  type    = string
  default = "ap-south-1"
}

locals {
  state_bucket = "${var.project}-tfstate-${var.account_alias}-${var.account_id}"
  lock_table   = "${var.project}-tflock-${var.account_alias}"
}

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket

  # State is precious. Never allow Terraform to wipe it.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "lock" {
  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "state_bucket" { value = aws_s3_bucket.state.id }
output "lock_table" { value = aws_dynamodb_table.lock.name }
