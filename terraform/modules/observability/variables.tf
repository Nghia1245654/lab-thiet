variable "environment" {
  type        = string
  description = "The deployment environment (e.g., sandbox, dev, staging)"
}

variable "ingest_lambda_name" {
  type        = string
  description = "The name of the Ingest Lambda function"
}

variable "integration_lambda_name" {
  type        = string
  description = "The name of the Integration Lambda function"
}

variable "sqs_queue_name" {
  type        = string
  description = "The name of the main SQS FIFO Queue"
}

variable "sqs_dlq_name" {
  type        = string
  description = "The name of the SQS FIFO DLQ"
}

variable "dynamodb_table_name" {
  type        = string
  description = "The name of the incident state DynamoDB table"
}

variable "s3_bucket_name" {
  type        = string
  description = "The name of the S3 audit bucket"
}

variable "slack_webhook_url" {
  type        = string
  description = "The Slack webhook URL for SNS alert notifications"
  default     = ""
}
