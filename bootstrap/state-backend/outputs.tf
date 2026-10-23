output "state_buckets" {
  description = "State bucket name per environment"
  value       = { for env, b in aws_s3_bucket.state : env => b.id }
}
