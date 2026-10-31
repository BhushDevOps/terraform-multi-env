# Published for the env layers. live/<account>/stack/eks.tf reads these via
# terraform_remote_state. Keep the names stable: they are an API.

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value     = module.eks.cluster_certificate_authority_data
  sensitive = true
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks.oidc_provider_url
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "karpenter_controller_role_arn" {
  description = "Paste into gitops karpenter.yaml -> serviceAccount.annotations."
  value       = module.eks.karpenter_controller_role_arn
}

output "karpenter_node_role_name" {
  description = "Paste into gitops EC2NodeClass -> spec.role."
  value       = module.eks.karpenter_node_role_name
}

output "kubeconfig_command" {
  description = "Run this once to talk to the cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
