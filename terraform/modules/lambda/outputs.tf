output "ingest_lambda_function_url" {
  value       = aws_lambda_function_url.ingest_url.function_url
  description = "The Function URL for the Ingest Lambda"
}

output "ingest_lambda_arn" {
  value       = aws_lambda_function.ingest.arn
  description = "The ARN of the Ingest Lambda Function"
}

output "integration_lambda_arn" {
  value       = aws_lambda_function.integration.arn
  description = "The ARN of the Integration Lambda Function"
}

output "ingest_api_endpoint" {
  value       = "${aws_apigatewayv2_api.ingest_api.api_endpoint}/alerts"
  description = "The endpoint URL for Alertmanager webhook ingestion via API Gateway"
}

output "ingest_lambda_name" {
  value       = aws_lambda_function.ingest.function_name
  description = "The name of the Ingest Lambda function"
}

output "integration_lambda_name" {
  value       = aws_lambda_function.integration.function_name
  description = "The name of the Integration Lambda function"
}
