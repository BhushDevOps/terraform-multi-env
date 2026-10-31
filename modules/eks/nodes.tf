# ---- step 3: platform managed node group -----------------------------------
# Runs Argo CD, Karpenter controller, CoreDNS, LBC, ESO, monitoring.
# App pods do NOT run here: they run on Karpenter nodes (nodes.tf has nothing
# for them, Karpenter launches plain EC2 with no ASG).
#
# What EKS does after `terraform apply` bumps the version:
#   1. new launch template version with the new AMI
#   2. scale up: new nodes launch first, old nodes cordoned
#   3. each old node drained via Eviction API (respects PDBs), then terminated
#   4. scale back to desired
# Terraform waits for all of it.
#
# Failure mode: pod not evictable in 15 min -> PodEvictionFailure.
# force_update_version pushes through but causes downtime.

resource "aws_eks_node_group" "platform" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-platform"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = var.platform_nodes.instance_types
  capacity_type  = "ON_DEMAND"

  # <-- UPGRADE STEP 3. Follows the control plane. Without this line the
  # nodes stay on the OLD version after a control plane upgrade.
  version = aws_eks_cluster.main.version

  # Optional exact AMI pin (e.g. "1.36.0-20261001"). Pin in prod so a node
  # roll only happens when someone changes this value.
  release_version = var.platform_node_release_version

  force_update_version = var.force_update_version

  scaling_config {
    desired_size = var.platform_nodes.desired_size
    min_size     = var.platform_nodes.min_size
    max_size     = var.platform_nodes.max_size
  }

  update_config {
    max_unavailable = var.node_max_unavailable # 1 = one node at a time
  }

  labels = {
    role = "platform"
  }

  # Karpenter controller must be able to schedule here even when the
  # workload NodePool is empty, so platform nodes carry no taint.

  lifecycle {
    # Cluster autoscaler / manual scaling may change desired_size; don't fight it.
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]

  tags = merge(var.tags, { Name = "${var.cluster_name}-platform" })
}
