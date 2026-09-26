# =============================================================================
# Root module for the test AWS ACCOUNT.
#
# All environments inside this account (env1, env2, env3 ...) run this same
# code. What makes them different is the two tfvars files passed at plan time.
#
# THE MODULE VERSION IS PINNED HERE, ONCE PER ACCOUNT:
#   test  -> v1.2.0   (same pin as prod until dev soak passes)
#
# Test remains pinned to the v1.2.0 baseline until dev has been verified.
# =============================================================================

module "app_bucket" {
  source = "git::https://github.com/BhushDevOps/terraform-multi-env.git//modules/s3-bucket?ref=v1.2.0"

  bucket_name               = local.bucket_name
  versioning_enabled        = var.versioning_enabled
  force_destroy             = var.force_destroy
  lifecycle_expiration_days = var.lifecycle_expiration_days
  block_public_access       = true
  sse_algorithm             = "AES256"

  tags = {
    Name = local.bucket_name
  }
}

locals {
  # env_name is part of every name, otherwise env1/env2/env3 would collide
  # inside the one shared AWS account.
  name_prefix = "${var.project}-${var.account_alias}-${var.env_name}"
  bucket_name = "${local.name_prefix}-app-${var.account_id}"
}

# The "application": a tiny static file, so each environment has something
# visible that is clearly its own.
resource "aws_s3_object" "app_index" {
  bucket       = module.app_bucket.bucket_id
  key          = "index.html"
  content      = "<h1>${var.project}</h1><p>account: ${var.account_alias}</p><p>environment: ${var.env_name}</p>"
  content_type = "text/html"
}
