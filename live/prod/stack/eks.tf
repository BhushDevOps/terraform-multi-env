# =============================================================================
# How an ENVIRONMENT (env1 / env2 / env3) uses the SHARED cluster.
#
# This file runs once per env, like main.tf. It does not create a cluster. It
# reads the account-level 02-eks state and creates only this env's own,
# namespace-scoped pieces: an IRSA role that lets pods in namespace <env_name>
# reach this env's S3 bucket.
#
#   shared (02-eks state)          per env (this state)
#   ----------------------         --------------------------------
#   cluster, nodes, OIDC           namespace  env1 / env2 / env3
#                                  IRSA role  demoapp-dev-env1-app
#                                  S3 bucket  (main.tf)
#
# eks_enabled = false (default) keeps envs that have no cluster yet planning
# clean. Flip it in the env's terraform.tfvars once 02-eks has been applied.
# =============================================================================

data "terraform_remote_state" "eks" {
  count = var.eks_enabled ? 1 : 0

  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "${var.account_alias}/02-eks/terraform.tfstate"
    region = var.state_region
  }
}

locals {
  eks = var.eks_enabled ? data.terraform_remote_state.eks[0].outputs : null

  # One namespace per env on the shared cluster.
  k8s_namespace = var.env_name
}

# IAM role for this env's application pods. Trust is pinned to
# system:serviceaccount:<env_name>:app, so env2's pods cannot use env1's role.
module "app_irsa" {
  count = var.eks_enabled ? 1 : 0

  # Pinned by relative path until modules/irsa is tagged; then
  # git::https://github.com/BhushDevOps/terraform-multi-env.git//modules/irsa?ref=v1.0.0
  source = "../../../modules/irsa"

  role_name         = "${local.name_prefix}-app"
  oidc_provider_arn = local.eks.oidc_provider_arn
  oidc_provider_url = local.eks.oidc_provider_url
  namespace         = local.k8s_namespace
  service_account   = "app"

  inline_policy_json = data.aws_iam_policy_document.app_bucket_access[0].json

  tags = {
    Name      = "${local.name_prefix}-app"
    Namespace = local.k8s_namespace
  }
}

# Least privilege: only this env's bucket.
data "aws_iam_policy_document" "app_bucket_access" {
  count = var.eks_enabled ? 1 : 0

  statement {
    actions   = ["s3:ListBucket"]
    resources = [module.app_bucket.bucket_arn]
  }

  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.app_bucket.bucket_arn}/*"]
  }
}

output "eks_cluster_name" {
  description = "Shared cluster this env deploys to. null until eks_enabled = true."
  value       = var.eks_enabled ? local.eks.cluster_name : null
}

output "k8s_namespace" {
  description = "Namespace this env owns on the shared cluster."
  value       = var.eks_enabled ? local.k8s_namespace : null
}

output "app_irsa_role_arn" {
  description = "Annotate the service account with eks.amazonaws.com/role-arn = this."
  value       = var.eks_enabled ? module.app_irsa[0].role_arn : null
}
