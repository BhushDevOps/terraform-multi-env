# =============================================================================
# 02-eks: the ONE shared EKS cluster for the dev AWS ACCOUNT.
#
# This is an ACCOUNT-level layer, not an environment-level one. env1, env2 and
# env3 do not get a cluster each; they get a namespace each on this cluster
# and read this layer's outputs (see live/dev/stack/eks.tf).
#
# Own state file:   dev/02-eks/terraform.tfstate   (backend.hcl)
# Owner:            platform-team                   (CODEOWNERS)
#
# THE MODULE VERSION IS PINNED HERE, ONCE PER ACCOUNT. Same promotion flow as
# the s3-bucket module: tag -> bump dev -> soak -> bump test -> bump prod.
#
# Upgrade order (docs/EKS_UPGRADE_RUNBOOK.md):
#   step 1  cluster_version          here, in terraform.tfvars
#   step 2  addon_versions           here, in terraform.tfvars, -target one at a time
#   step 3  node group               follows cluster_version automatically
#   step 4  Karpenter nodes          drift, nothing to do here
#   step 5  Helm tools               gitops repo, Argo CD
# =============================================================================

module "eks" {
  # Pinned by relative path while the module is still being written. Once
  # tagged it becomes: git::https://github.com/BhushDevOps/terraform-multi-env.git//modules/eks?ref=v2.0.0
  source = "../../../modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id                 = var.vpc_id
  subnet_ids             = var.private_subnet_ids
  endpoint_public_access = var.endpoint_public_access

  addon_versions = var.addon_versions

  platform_nodes                = var.platform_nodes
  platform_node_release_version = var.platform_node_release_version
  node_max_unavailable          = 1
  force_update_version          = false

  karpenter_enabled = true

  tags = {
    Name  = local.cluster_name
    Layer = "02-eks"
  }
}

locals {
  # No env_name here on purpose: the cluster is shared by every env.
  cluster_name = "${var.project}-${var.account_alias}-eks"
}
