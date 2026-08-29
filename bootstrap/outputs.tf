output "state_bucket_name" {
  description = "Copy this into environments/dev/backend.tf -> bucket"
  value       = aws_s3_bucket.tf_state.bucket
}

output "aws_region" {
  value = var.aws_region
}
