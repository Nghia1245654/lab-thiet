output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "The ARN of the SNS topic for alerts"
}

output "sns_topic_name" {
  value       = aws_sns_topic.alerts.name
  description = "The name of the SNS topic for alerts"
}
