variable "secondary_region" {
  description = "Second AWS region where the security groups are managed."
  type        = string
}

variable "primary_vpc_id" {
  description = "VPC ID in the primary AWS region."
  type        = string
}

variable "secondary_vpc_id" {
  description = "VPC ID in the second AWS region."
  type        = string
}
