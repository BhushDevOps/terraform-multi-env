# These outputs are the CONTRACT between the platform team (02-eks) and the
# app teams (env1/env2/env3). Keep it small; add here only what consumers need.

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.main.arn
}

output "cluster_version" {
  description = "Kubernetes version the control plane is running."
  value       = aws_eks_cluster.main.version
}

output "cluster_endpoint" {
  description = "API server endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA bundle for kubeconfig."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN. env1/env2 pass this to modules/irsa."
  value       = aws_iam_openid_connect_provider.main.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without https://, used in IRSA trust conditions."
  value       = replace(aws_iam_openid_connect_provider.main.url, "https://", "")
}

output "cluster_security_group_id" {
  description = "Security group on the control plane ENIs."
  value       = aws_security_group.cluster.id
}

output "platform_node_group_name" {
  description = "Managed node group that hosts platform tooling."
  value       = aws_eks_node_group.platform.node_group_name
}

output "karpenter_controller_role_arn" {
  description = "IRSA role for the Karpenter controller. Goes into the Helm values in gitops."
  value       = var.karpenter_enabled ? aws_iam_role.karpenter_controller[0].arn : null
}

output "karpenter_node_role_name" {
  description = "Node role name for the EC2NodeClass `role:` field."
  value       = var.karpenter_enabled ? aws_iam_role.karpenter_node[0].name : null
}
