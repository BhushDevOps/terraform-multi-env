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

# ---- environment level (comes from ./terraform.tfvars) ---------------------

variable "env_name" {
  description = "Environment inside the account: env1, env2, env3 ..."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.env_name))
    error_message = "env_name must be lowercase letters, numbers or dashes."
  }
}

variable "versioning_enabled" {
  description = "Turn on S3 object versioning."
  type        = bool
}

variable "force_destroy" {
  description = "Let Terraform delete a non-empty bucket."
  type        = bool
}

variable "lifecycle_expiration_days" {
  description = "Delete noncurrent versions after N days. 0 disables the rule."
  type        = number
  default     = 0
}
