# ---- account level (comes from ../account.tfvars) --------------------------

variable "project" {
  description = "Short project name, used as a name prefix."
  type        = string
}

variable "account_alias" {
  description = "Which AWS account this is: dev, test or prod."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.account_alias)
    error_message = "account_alias must be dev, test or prod."
  }
}

variable "account_id" {
  description = "AWS account id. Used to guard against running in the wrong account."
  type        = string
}

variable "region" {
  description = "AWS region for this account."
  type        = string
}

variable "owner" {
  description = "Team that owns these resources."
  type        = string
}

variable "state_bucket" {
  description = "State bucket for this account. Not used by this layer, declared so account.tfvars loads without warnings."
  type        = string
  default     = null
}

variable "state_region" {
  description = "Region of the state bucket. Same note as state_bucket."
  type        = string
  default     = null
}

# ---- layer level (comes from ./terraform.tfvars) ---------------------------

variable "cluster_version" {
  description = "Kubernetes version. UPGRADE STEP 1. One minor at a time."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the cluster (from 01-network, or an existing VPC)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for control plane ENIs and nodes."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Public API endpoint. true in dev for convenience, false in prod."
  type        = bool
  default     = false
}

variable "addon_versions" {
  description = "Pinned managed add-on versions. UPGRADE STEP 2."
  type = object({
    vpc-cni                = string
    kube-proxy             = string
    coredns                = string
    eks-pod-identity-agent = string
    aws-ebs-csi-driver     = string
  })
}

variable "platform_nodes" {
  description = "Managed platform node group sizing."
  type = object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
  })
}

variable "platform_node_release_version" {
  description = "Exact AMI release for the platform node group. null in dev (latest), pinned in prod. UPGRADE STEP 3."
  type        = string
  default     = null
}
