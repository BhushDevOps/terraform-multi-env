variable "role_name" {
  description = "IAM role name. Carry account + env in it, e.g. demoapp-dev-env1-app."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider. Comes from the 02-eks layer outputs."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL WITHOUT https://. Comes from the 02-eks layer outputs."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account that may assume this role."
  type        = string
}

variable "service_account" {
  description = "Service account name inside that namespace."
  type        = string
}

variable "policy_arns" {
  description = "Managed policy ARNs to attach."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional inline policy document. null = none."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to the role."
  type        = map(string)
  default     = {}
}
