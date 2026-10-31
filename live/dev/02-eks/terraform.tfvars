# dev / 02-eks - shared cluster for env1, env2, env3
#
# DEV IS WHERE UPGRADES LAND FIRST. Compare with live/prod/02-eks/terraform.tfvars:
# prod is one version behind and pins the AMI release.

# ---- step 1: control plane -------------------------------------------------
cluster_version = "1.36" # 1.35 -> 1.36 being soaked here

# ---- network (replace with 01-network outputs once that layer exists) ------
vpc_id             = "vpc-02198915b9626acaa"
private_subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]

endpoint_public_access = true # dev convenience; false in prod

# ---- step 2: managed add-ons -----------------------------------------------
# Values from:
#   aws eks describe-addon-versions --kubernetes-version 1.36 --addon-name <name> \
#     --query 'addons[].addonVersions[].{v:addonVersion,default:compatibilities[0].defaultVersion}'
addon_versions = {
  vpc-cni                = "v1.20.1-eksbuild.1"
  kube-proxy             = "v1.36.0-eksbuild.2"
  coredns                = "v1.12.1-eksbuild.2"
  eks-pod-identity-agent = "v1.3.8-eksbuild.2"
  aws-ebs-csi-driver     = "v1.47.0-eksbuild.1"
}

# ---- step 3: platform node group -------------------------------------------
platform_nodes = {
  instance_types = ["t3.medium"]
  desired_size   = 2
  min_size       = 2
  max_size       = 3
}

# null = latest AMI for cluster_version. Nodes re-roll whenever AWS ships a
# new AMI, which is fine in dev.
platform_node_release_version = null
