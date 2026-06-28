variable "environment" {
  type        = string
  description = "Environment name (e.g. sandbox)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where lambdas will run"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private Subnet IDs for VPC-placed Lambdas"
}

variable "security_group_id" {
  type        = string
  description = "Security Group ID for Lambdas"
}

variable "sqs_queue_url" {
  type        = string
  description = "URL of the main SQS queue"
}

variable "sqs_queue_arn" {
  type        = string
  description = "ARN of the main SQS queue"
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB incident state table"
}

variable "dynamodb_table_arn" {
  type        = string
  description = "ARN of the DynamoDB incident state table"
}

variable "s3_bucket_name" {
  type        = string
  description = "Name of the S3 audit bucket"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 audit bucket"
}
