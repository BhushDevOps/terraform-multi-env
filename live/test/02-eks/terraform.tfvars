# test / 02-eks - shared cluster for env1, env2, env3
# Same versions as dev once dev has soaked. Promoted here BEFORE prod.

cluster_version = "1.36"

vpc_id             = "vpc-0test000000000000"
private_subnet_ids = ["subnet-0test00000000000a", "subnet-0test00000000000b"]

endpoint_public_access = false

addon_versions = {
  vpc-cni                = "v1.20.1-eksbuild.1"
  kube-proxy             = "v1.36.0-eksbuild.2"
  coredns                = "v1.12.1-eksbuild.2"
  eks-pod-identity-agent = "v1.3.8-eksbuild.2"
  aws-ebs-csi-driver     = "v1.47.0-eksbuild.1"
}

platform_nodes = {
  instance_types = ["t3.medium"]
  desired_size   = 2
  min_size       = 2
  max_size       = 3
}

platform_node_release_version = null
