# =============================================================================
# EKS module: the RESOURCE DEFINITIONS.
#
# live/<account>/02-eks only calls this module and passes values. The upgrade
# order lives in docs/EKS_UPGRADE_RUNBOOK.md and is mirrored by the file names:
#
#   main.tf      -> step 1  control plane   (version)
#   addons.tf    -> step 2  managed add-ons (addon_version)
#   nodes.tf     -> step 3  platform nodes  (version / release_version)
#   karpenter.tf -> step 4  IAM only; nodes roll themselves via drift
#   (step 5, Helm tools, is Git -> Argo CD, outside Terraform)
# =============================================================================

# ---- step 1: control plane -------------------------------------------------

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version # <-- UPGRADE STEP 1. One minor at a time. No rollback.
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = var.enabled_log_types

  # Upgrading the control plane does NOT touch add-ons or nodes.
  # AWS rolls the API servers; pods, ALB and RDS are not on this path.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster"
  description = "EKS control plane ENIs"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster" })
}

# ---- OIDC provider: lets pods assume IAM roles (IRSA) ----------------------
# env1 / env2 read oidc_provider_arn from this layer's outputs and build their
# own IRSA roles with modules/irsa.

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "main" {
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = var.tags
}
