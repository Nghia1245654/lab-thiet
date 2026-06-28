# 1. SNS Topic for Alerting
resource "aws_sns_topic" "alerts" {
  name = "tf1-${var.environment}-alerts"

  tags = {
    Name        = "tf1-${var.environment}-alerts"
    Environment = var.environment
  }
}

# 2. SNS Subscription to Slack Webhook (HTTPS Protocol)
resource "aws_sns_topic_subscription" "slack" {
  count     = var.slack_webhook_url != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# 3. Lambda CloudWatch Alarms
# Ingest Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "ingest_lambda_errors" {
  alarm_name          = "tf1-${var.environment}-ingest-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Cảnh báo khi Ingest Lambda xảy ra > 5 lỗi trong 5 phút"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.ingest_lambda_name
  }

  tags = {
    Environment = var.environment
  }
}

# Ingest Lambda Duration Alarm (p99 > 10s)
resource "aws_cloudwatch_metric_alarm" "ingest_lambda_duration" {
  alarm_name          = "tf1-${var.environment}-ingest-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 10000 # p99 > 10s (in ms)
  alarm_description   = "Cảnh báo khi thời gian chạy p99 của Ingest Lambda vượt quá 10 giây"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.ingest_lambda_name
  }

  tags = {
    Environment = var.environment
  }
}

# Integration Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "integration_lambda_errors" {
  alarm_name          = "tf1-${var.environment}-integration-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Cảnh báo khi Integration Lambda xảy ra > 5 lỗi trong 5 phút"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.integration_lambda_name
  }

  tags = {
    Environment = var.environment
  }
}

# Integration Lambda Duration Alarm (p99 > 10s)
resource "aws_cloudwatch_metric_alarm" "integration_lambda_duration" {
  alarm_name          = "tf1-${var.environment}-integration-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 10000 # p99 > 10s (in ms)
  alarm_description   = "Cảnh báo khi thời gian chạy p99 của Integration Lambda vượt quá 10 giây"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.integration_lambda_name
  }

  tags = {
    Environment = var.environment
  }
}

# 4. SQS CloudWatch Alarms
# Main Queue Depth Alarm
resource "aws_cloudwatch_metric_alarm" "sqs_queue_depth" {
  alarm_name          = "tf1-${var.environment}-sqs-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 100
  alarm_description   = "Cảnh báo khi số lượng tin nhắn chờ xử lý trong Main SQS vượt quá 100"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = var.sqs_queue_name
  }

  tags = {
    Environment = var.environment
  }
}

# DLQ Messages Count Alarm (CRITICAL)
resource "aws_cloudwatch_metric_alarm" "sqs_dlq_depth" {
  alarm_name          = "tf1-${var.environment}-sqs-dlq-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Cảnh báo CRITICAL khi có tin nhắn rơi vào SQS DLQ"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = var.sqs_dlq_name
  }

  tags = {
    Environment = var.environment
    Severity    = "CRITICAL"
  }
}

# 5. DynamoDB Table Alarm
# Throttled Requests Alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttles" {
  alarm_name          = "tf1-${var.environment}-dynamodb-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Cảnh báo khi có yêu cầu truy cập DynamoDB bị throttle"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    TableName = var.dynamodb_table_name
  }

  tags = {
    Environment = var.environment
  }
}

# 6. S3 Audit Bucket Alarm
# S3 Request Detailed Metrics
resource "aws_s3_bucket_metric" "audit_metrics" {
  bucket = var.s3_bucket_name
  name   = "EntireBucket"
}

# S3 Errors Alarm (4xx + 5xx Errors > 10 using CloudWatch Metric Math)
resource "aws_cloudwatch_metric_alarm" "s3_errors" {
  alarm_name          = "tf1-${var.environment}-s3-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 10
  alarm_description   = "Cảnh báo khi S3 audit bucket có tổng số lỗi 4xx & 5xx vượt quá 10 trong 5 phút"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  metric_query {
    id          = "e1"
    expression  = "m1 + m2"
    label       = "Total Errors"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "4xxErrors"
      namespace   = "AWS/S3"
      period      = 300
      stat        = "Sum"
      dimensions = {
        BucketName = var.s3_bucket_name
        FilterId   = aws_s3_bucket_metric.audit_metrics.name
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "5xxErrors"
      namespace   = "AWS/S3"
      period      = 300
      stat        = "Sum"
      dimensions = {
        BucketName = var.s3_bucket_name
        FilterId   = aws_s3_bucket_metric.audit_metrics.name
      }
    }
  }

  tags = {
    Environment = var.environment
  }
}
