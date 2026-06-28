# 1. SQS Dead Letter Queue (DLQ)
resource "aws_sqs_queue" "alert_dlq" {
  name                        = "tf1-${var.environment}-alert-dlq.fifo"
  fifo_queue                  = true
  message_retention_seconds   = 1209600 # 14 ngày
  sqs_managed_sse_enabled     = true

  tags = {
    Name        = "tf1-${var.environment}-alert-dlq"
    Environment = var.environment
  }
}

# 2. SQS Main Queue
resource "aws_sqs_queue" "alert_queue" {
  name                        = "tf1-${var.environment}-alert-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds   = 300     # 5 phút (visibility timeout)
  message_retention_seconds   = 345600  # 4 ngày
  sqs_managed_sse_enabled     = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.alert_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "tf1-${var.environment}-alert-queue"
    Environment = var.environment
  }
}


# 4. DynamoDB Table for Incident States
resource "aws_dynamodb_table" "incident_state" {
  name         = "tf1-${var.environment}-incident-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"

  attribute {
    name = "incident_id"
    type = "S"
  }

  attribute {
    name = "correlation_key"
    type = "S"
  }

  attribute {
    name = "alert_fingerprint"
    type = "S"
  }

  global_secondary_index {
    name            = "CorrelationFingerprintIndex"
    hash_key        = "correlation_key"
    range_key       = "alert_fingerprint"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = "tf1-${var.environment}-incident-state"
    Environment = var.environment
  }
}

data "aws_caller_identity" "current" {}

# 5. S3 Bucket for Audit Trail
resource "aws_s3_bucket" "audit" {
  bucket        = "tf1-audit-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name        = "tf1-audit"
    Environment = var.environment
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "audit_versioning" {
  bucket = aws_s3_bucket.audit.id
  versioning_configuration {
    status = "Enabled"
  }
}

# SSE Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "audit_encryption" {
  bucket = aws_s3_bucket.audit.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Public Access Block
resource "aws_s3_bucket_public_access_block" "audit_public_access" {
  bucket                  = aws_s3_bucket.audit.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle Configuration (Transition to Glacier after 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "audit_lifecycle" {
  bucket = aws_s3_bucket.audit.id

  rule {
    id     = "glacier-transition"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# Bucket Policy: Deny non-SSL requests
resource "aws_s3_bucket_policy" "audit_policy" {
  bucket = aws_s3_bucket.audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLSRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.audit.arn,
          "${aws_s3_bucket.audit.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}


