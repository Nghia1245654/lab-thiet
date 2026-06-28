terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


module "networking" {
  source             = "../../modules/networking"
  vpc_cidr           = "10.0.0.0/16"
  public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets    = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  environment        = "sandbox"
}

module "security" {
  source              = "../../modules/security"
  vpc_id              = module.networking.vpc_id
  sg_vpc_endpoints_id = module.networking.sg_vpc_endpoints_id
  environment         = "sandbox"
}

module "compute" {
  source             = "../../modules/compute"
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  sg_eks_nodes_id    = module.security.sg_eks_nodes_id
  environment        = "sandbox"
  node_instance_type = "t3.medium"
}

module "data" {
  source      = "../../modules/data"
  environment = "sandbox"
}

module "lambda" {
  source              = "../../modules/lambda"
  environment         = "sandbox"
  vpc_id              = module.networking.vpc_id
  subnet_ids          = module.networking.private_subnet_ids
  security_group_id   = module.security.sg_lambda_id
  sqs_queue_url       = module.data.queue_url
  sqs_queue_arn       = module.data.queue_arn
  dynamodb_table_name = module.data.dynamodb_table_name
  dynamodb_table_arn  = module.data.dynamodb_table_arn
  s3_bucket_name      = module.data.s3_bucket_name
  s3_bucket_arn       = module.data.s3_bucket_arn
}


provider "kubernetes" {
  host                   = module.compute.cluster_endpoint
  cluster_ca_certificate = base64decode(module.compute.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.compute.cluster_name, "--region", "us-east-1"]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.compute.cluster_endpoint
    cluster_ca_certificate = base64decode(module.compute.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.compute.cluster_name, "--region", "us-east-1"]
      command     = "aws"
    }
  }
}

output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "sg_alb_id" {
  value = module.security.sg_alb_id
}

output "sg_eks_nodes_id" {
  value = module.security.sg_eks_nodes_id
}

output "sg_lambda_id" {
  value = module.security.sg_lambda_id
}

output "sg_vpc_endpoints_id" {
  value = module.networking.sg_vpc_endpoints_id
}

output "cluster_name" {
  value = module.compute.cluster_name
}

output "cluster_endpoint" {
  value = module.compute.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.compute.cluster_certificate_authority_data
}

output "sqs_queue_arn" {
  value = module.data.queue_arn
}

output "sqs_queue_url" {
  value = module.data.queue_url
}

output "sqs_dlq_arn" {
  value = module.data.dlq_arn
}

output "sqs_dlq_url" {
  value = module.data.dlq_url
}

output "dynamodb_table_name" {
  value = module.data.dynamodb_table_name
}

output "dynamodb_table_arn" {
  value = module.data.dynamodb_table_arn
}

output "s3_bucket_name" {
  value = module.data.s3_bucket_name
}

output "s3_bucket_arn" {
  value = module.data.s3_bucket_arn
}

output "ingest_lambda_function_url" {
  value = module.lambda.ingest_lambda_function_url
}

output "ingest_lambda_arn" {
  value = module.lambda.ingest_lambda_arn
}

output "integration_lambda_arn" {
  value = module.lambda.integration_lambda_arn
}

output "ingest_api_endpoint" {
  value = module.lambda.ingest_api_endpoint
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack webhook URL for SNS alerts"
  default     = ""
}

module "observability" {
  source                  = "../../modules/observability"
  environment             = "sandbox"
  ingest_lambda_name      = module.lambda.ingest_lambda_name
  integration_lambda_name = module.lambda.integration_lambda_name
  sqs_queue_name          = module.data.queue_name
  sqs_dlq_name            = module.data.dlq_name
  dynamodb_table_name     = module.data.dynamodb_table_name
  s3_bucket_name          = module.data.s3_bucket_name
  slack_webhook_url       = var.slack_webhook_url
}

output "sns_topic_arn" {
  value       = module.observability.sns_topic_arn
  description = "ARN of the SNS topic for alerts"
}

output "sns_topic_name" {
  value       = module.observability.sns_topic_name
  description = "Name of the SNS topic for alerts"
}




