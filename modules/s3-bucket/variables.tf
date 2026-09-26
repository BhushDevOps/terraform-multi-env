variable "bucket_name" {
  description = "Full name of the S3 bucket to create. Must be globally unique."
  type        = string
}

variable "force_destroy" {
  description = "Allow Terraform to delete a bucket that still has objects in it. Keep false in prod."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Turn on object versioning."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server side encryption algorithm: AES256 or aws:kms."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256 or aws:kms."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN. Only used when sse_algorithm is aws:kms."
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "Block all public access to the bucket."
  type        = bool
  default     = true
}

variable "lifecycle_expiration_days" {
  description = "Delete noncurrent object versions after this many days. Set to 0 to disable the rule."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "additional_tags" {
  description = "Additional tags to merge into tags. These values override matching keys in tags."
  type        = map(string)
  default     = {}
}
