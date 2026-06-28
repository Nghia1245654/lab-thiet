variable "vpc_id" {
  description = "The ID of the VPC where Security Groups will be created"
  type        = string
}

variable "sg_vpc_endpoints_id" {
  description = "The ID of the VPC Endpoints Security Group"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "sandbox"
}
