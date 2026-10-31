# ---- step 4: Karpenter -----------------------------------------------------
# Karpenter nodes are NOT Terraform resources. The controller launches plain
# EC2 from the NodePool / EC2NodeClass in the gitops repo. After a control
# plane upgrade the EC2NodeClass (alias: al2023@latest) resolves a new AMI,
# marks nodes DRIFTED and replaces them, paced by disruption.budgets.
#   -> al2023@latest   : you do nothing (dev)
#   -> al2023@v2026xxx : bump the date in Git, Argo CD syncs (prod)
#
# What DOES live here is IAM. New Karpenter versions sometimes need new
# permissions: apply this file BEFORE bumping the chart in Git.

# ---- controller role (IRSA) -----------------------------------------------

data "aws_iam_policy_document" "karpenter_controller_assume" {
  count = var.karpenter_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.main.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.karpenter_namespace}:karpenter"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.main.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "karpenter_controller" {
  count = var.karpenter_enabled ? 1 : 0

  name               = "${var.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "karpenter_controller" {
  count = var.karpenter_enabled ? 1 : 0

  statement {
    sid = "Karpenter"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstances",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "pricing:GetProducts",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassNodeIAMRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.karpenter_node[0].arn]
  }

  statement {
    sid       = "EKSClusterEndpointLookup"
    actions   = ["eks:DescribeCluster"]
    resources = [aws_eks_cluster.main.arn]
  }

  statement {
    sid = "InstanceProfile"
    actions = [
      "iam:CreateInstanceProfile",
      "iam:TagInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "karpenter_controller" {
  count = var.karpenter_enabled ? 1 : 0

  name   = "${var.cluster_name}-karpenter-controller"
  role   = aws_iam_role.karpenter_controller[0].id
  policy = data.aws_iam_policy_document.karpenter_controller[0].json
}

# ---- node role for Karpenter-launched EC2 ----------------------------------

resource "aws_iam_role" "karpenter_node" {
  count = var.karpenter_enabled ? 1 : 0

  name               = "${var.cluster_name}-karpenter-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "karpenter_node" {
  for_each = var.karpenter_enabled ? toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]) : toset([])

  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "karpenter_node" {
  count = var.karpenter_enabled ? 1 : 0

  name = "${var.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node[0].name
  tags = var.tags
}

# Karpenter node role must be allowed to join the cluster.
resource "aws_eks_access_entry" "karpenter_node" {
  count = var.karpenter_enabled ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.karpenter_node[0].arn
  type          = "EC2_LINUX"
}
