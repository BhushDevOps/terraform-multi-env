# ---- identity --------------------------------------------------------------

variable "cluster_name" {
  description = "Name of the EKS cluster. Carries account alias so dev/test/prod never collide."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes minor version, e.g. 1.36. UPGRADE STEP 1: bump this ONE minor at a time. No rollback."
  type        = string

  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.cluster_version))
    error_message = "cluster_version must look like 1.36 (major.minor only, no patch)."
  }
}

# ---- network ---------------------------------------------------------------

variable "vpc_id" {
  description = "VPC the cluster lives in."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the control plane ENIs and the node groups."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the API server publicly. Keep false in prod, reach it via VPN / bastion."
  type        = bool
  default     = false
}

# ---- managed add-ons (UPGRADE STEP 2) --------------------------------------
# Every add-on is PINNED. Without addon_version Terraform never upgrades them.
# Find versions:  aws eks describe-addon-versions --kubernetes-version 1.36 --addon-name coredns

variable "addon_versions" {
  description = "Exact version per managed add-on. Keys are the EKS add-on names."
  type = object({
    vpc-cni                = string
    kube-proxy             = string
    coredns                = string
    eks-pod-identity-agent = string
    aws-ebs-csi-driver     = string
  })
}

variable "addon_resolve_conflicts_on_update" {
  description = "PRESERVE keeps manual tweaks to add-on config, OVERWRITE resets them."
  type        = string
  default     = "PRESERVE"

  validation {
    condition     = contains(["PRESERVE", "OVERWRITE", "NONE"], var.addon_resolve_conflicts_on_update)
    error_message = "Must be PRESERVE, OVERWRITE or NONE."
  }
}

# ---- platform node group (UPGRADE STEP 3) ----------------------------------
# Small, stable managed group for Argo CD, Karpenter controller, CoreDNS,
# LBC, ESO, monitoring. Karpenter cannot create its own first node.

variable "platform_nodes" {
  description = "Sizing for the managed platform node group."
  type = object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
  })
}

variable "platform_node_release_version" {
  description = "Optional exact AMI release (e.g. 1.36.0-20261001). null = latest AMI for cluster_version. Pin in prod."
  type        = string
  default     = null
}

variable "node_max_unavailable" {
  description = "Nodes EKS may drain at once during a node group update. 1 = one node at a time."
  type        = number
  default     = 1
}

variable "force_update_version" {
  description = "Push a node group update through even if pods cannot be evicted in 15 min. Causes downtime. Keep false."
  type        = bool
  default     = false
}

# ---- karpenter (UPGRADE STEP 4 is automatic via drift; IAM lives here) -----

variable "karpenter_enabled" {
  description = "Create the Karpenter controller role, node role and instance profile."
  type        = bool
  default     = true
}

variable "karpenter_namespace" {
  description = "Namespace the Karpenter controller runs in."
  type        = string
  default     = "karpenter"
}

# ---- misc ------------------------------------------------------------------

variable "enabled_log_types" {
  description = "Control plane logs shipped to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "tags" {
  description = "Tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
