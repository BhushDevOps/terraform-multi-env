# ---- step 2: managed add-ons -----------------------------------------------
# All five are PINNED via addon_version. Without it, they stay on whatever AWS
# picked at creation and Terraform never upgrades them.
#
# Apply ONE AT A TIME during an upgrade:
#   terraform apply -target=module.eks.aws_eks_addon.kube_proxy
#   terraform apply -target=module.eks.aws_eks_addon.vpc_cni     # one minor per step
#   terraform apply -target=module.eks.aws_eks_addon.coredns
#   terraform apply -target=module.eks.aws_eks_addon.pod_identity_agent
#   terraform apply -target=module.eks.aws_eks_addon.ebs_csi
#   terraform apply
#
# Rollback = put the previous addon_version back and apply.
# Never upgrade add-ons from the console: state drifts and the next apply undoes it.

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = var.addon_versions["kube-proxy"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = var.addon_resolve_conflicts_on_update

  # DaemonSet: rolls one node at a time, existing iptables rules stay in place.
  depends_on = [aws_eks_node_group.platform]
  tags       = var.tags
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = var.addon_versions["vpc-cni"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = var.addon_resolve_conflicts_on_update

  # DaemonSet: running pods keep their IPs, only new pods wait a few seconds.
  depends_on = [aws_eks_node_group.platform]
  tags       = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = var.addon_versions["coredns"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = var.addon_resolve_conflicts_on_update

  # Deployment, 2 replicas: rolls one pod at a time, one always answers DNS.
  depends_on = [aws_eks_node_group.platform]
  tags       = var.tags
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = var.addon_versions["eks-pod-identity-agent"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = var.addon_resolve_conflicts_on_update

  # DaemonSet: pods already hold cached credentials.
  depends_on = [aws_eks_node_group.platform]
  tags       = var.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.addon_versions["aws-ebs-csi-driver"]
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = var.addon_resolve_conflicts_on_update
  service_account_role_arn    = aws_iam_role.ebs_csi.arn

  # Deployment + DaemonSet: mounted volumes stay mounted, only new attach/detach pauses.
  depends_on = [aws_eks_node_group.platform]
  tags       = var.tags
}
