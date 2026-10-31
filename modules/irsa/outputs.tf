output "role_arn" {
  description = "Role ARN. Put it in the service account annotation eks.amazonaws.com/role-arn."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Role name."
  value       = aws_iam_role.this.name
}
