# prod / 02-eks - shared cluster for env1, env2, env3
#
# PROD IS ONE VERSION BEHIND DEV until the upgrade has run in dev and test.
# The promotion PR changes ONLY this file. Dev and test plans stay empty.

# ---- step 1: control plane -------------------------------------------------
cluster_version = "1.35" # dev/test are on 1.36; bump here after they soak

# ---- network ---------------------------------------------------------------
vpc_id             = "vpc-0prod00000000000"
private_subnet_ids = ["subnet-0prod0000000000a", "subnet-0prod0000000000b", "subnet-0prod0000000000c"]

endpoint_public_access = false # VPN / bastion only

# ---- step 2: managed add-ons (compatible with 1.35) -----------------------
addon_versions = {
  vpc-cni                = "v1.19.6-eksbuild.1"
  kube-proxy             = "v1.35.0-eksbuild.3"
  coredns                = "v1.11.4-eksbuild.14"
  eks-pod-identity-agent = "v1.3.7-eksbuild.2"
  aws-ebs-csi-driver     = "v1.45.0-eksbuild.2"
}

# ---- step 3: platform node group -------------------------------------------
platform_nodes = {
  instance_types = ["m6i.large"]
  desired_size   = 3
  min_size       = 3
  max_size       = 5
}

# PINNED in prod. A node roll happens only when someone changes this line.
platform_node_release_version = "1.35.3-20260915"
