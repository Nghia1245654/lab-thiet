# 1. Zip files for Lambda Code
data "archive_file" "ingest" {
  type        = "zip"
  source_file = "${path.module}/../../../services/ingest-lambda/index.py"
  output_path = "${path.module}/../../../services/ingest-lambda/lambda.zip"
}

data "archive_file" "integration" {
  type        = "zip"
  source_file = "${path.module}/../../../services/integration-lambda/index.py"
  output_path = "${path.module}/../../../services/integration-lambda/lambda.zip"
}

# 2. Ingest Lambda IAM Role and Policies
resource "aws_iam_role" "ingest_role" {
  name = "tf1-${var.environment}-ingest-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "ingest_policy" {
  name        = "tf1-${var.environment}-ingest-lambda-policy"
  description = "IAM policy for ingest lambda to send messages to SQS and write logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = var.sqs_queue_arn
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tf1-${var.environment}-ingest-lambda:*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ingest_attach" {
  role       = aws_iam_role.ingest_role.name
  policy_arn = aws_iam_policy.ingest_policy.arn
}

# 3. Integration Lambda IAM Role and Policies
resource "aws_iam_role" "integration_role" {
  name = "tf1-${var.environment}-integration-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "integration_policy" {
  name        = "tf1-${var.environment}-integration-lambda-policy"
  description = "IAM policy for integration lambda to read/write DynamoDB, S3, Secrets Manager, and write logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/tf1-${var.environment}-integration-lambda:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "integration_attach" {
  role       = aws_iam_role.integration_role.name
  policy_arn = aws_iam_policy.integration_policy.arn
}

# 4. Ingest Lambda Function
resource "aws_lambda_function" "ingest" {
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  function_name    = "tf1-${var.environment}-ingest-lambda"
  role             = aws_iam_role.ingest_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  environment {
    variables = {
      SQS_QUEUE_URL = var.sqs_queue_url
      ENVIRONMENT   = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.ingest_log_group
  ]

  tags = {
    Name        = "tf1-${var.environment}-ingest-lambda"
    Environment = var.environment
  }
}

# Ingest Function URL
resource "aws_lambda_function_url" "ingest_url" {
  function_name      = aws_lambda_function.ingest.function_name
  authorization_type = "NONE"
}

# Grant public invocation permission for the Function URL
resource "aws_lambda_permission" "allow_public_function_url" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.ingest.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

# API Gateway HTTP API for Ingest Lambda
resource "aws_apigatewayv2_api" "ingest_api" {
  name          = "tf1-${var.environment}-ingest-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "ingest_integration" {
  api_id           = aws_apigatewayv2_api.ingest_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingest.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ingest_route" {
  api_id    = aws_apigatewayv2_api.ingest_api.id
  route_key = "POST /alerts"
  target    = "integrations/${aws_apigatewayv2_integration.ingest_integration.id}"
}

resource "aws_apigatewayv2_stage" "ingest_stage" {
  api_id      = aws_apigatewayv2_api.ingest_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_ingest_permission" {
  statement_id  = "AllowAPIGatewayInvokeIngest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ingest_api.execution_arn}/*/*"
}



# 5. Integration Lambda Function
resource "aws_lambda_function" "integration" {
  filename         = data.archive_file.integration.output_path
  source_code_hash = data.archive_file.integration.output_base64sha256
  function_name    = "tf1-${var.environment}-integration-lambda"
  role             = aws_iam_role.integration_role.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      S3_BUCKET_NAME = var.s3_bucket_name
      ENVIRONMENT    = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.integration_log_group
  ]

  tags = {
    Name        = "tf1-${var.environment}-integration-lambda"
    Environment = var.environment
  }
}

# 6. Explicit CloudWatch Log Groups for both lambdas to prevent auto-creation and manage retention
resource "aws_cloudwatch_log_group" "ingest_log_group" {
  name              = "/aws/lambda/tf1-${var.environment}-ingest-lambda"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "integration_log_group" {
  name              = "/aws/lambda/tf1-${var.environment}-integration-lambda"
  retention_in_days = 14

  tags = {
    Environment = var.environment
  }
}
