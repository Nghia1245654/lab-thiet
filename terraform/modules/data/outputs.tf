output "queue_arn" {
  value       = aws_sqs_queue.alert_queue.arn
  description = "ARN of the main SQS FIFO queue"
}

output "queue_url" {
  value       = aws_sqs_queue.alert_queue.id
  description = "URL of the main SQS FIFO queue"
}

output "dlq_arn" {
  value       = aws_sqs_queue.alert_dlq.arn
  description = "ARN of the SQS FIFO DLQ"
}

output "dlq_url" {
  value       = aws_sqs_queue.alert_dlq.id
  description = "URL of the SQS FIFO DLQ"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.incident_state.name
  description = "Name of the DynamoDB table for incident states"
}

output "dynamodb_table_arn" {
  value       = aws_dynamodb_table.incident_state.arn
  description = "ARN of the DynamoDB table for incident states"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.audit.id
  description = "Name of the S3 audit bucket"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.audit.arn
  description = "ARN of the S3 audit bucket"
}

output "queue_name" {
  value       = aws_sqs_queue.alert_queue.name
  description = "Name of the main SQS FIFO queue"
}

output "dlq_name" {
  value       = aws_sqs_queue.alert_dlq.name
  description = "Name of the SQS FIFO DLQ"
}
