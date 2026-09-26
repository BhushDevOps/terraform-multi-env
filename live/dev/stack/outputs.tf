output "bucket_name" {
  description = "Name of the application bucket for this environment."
  value       = module.app_bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN of the application bucket."
  value       = module.app_bucket.bucket_arn
}

output "app_object_url" {
  description = "S3 URI of the uploaded application file."
  value       = "s3://${module.app_bucket.bucket_id}/${aws_s3_object.app_index.key}"
}
