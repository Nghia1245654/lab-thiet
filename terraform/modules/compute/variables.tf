variable "vpc_id" {
  description = "The ID of the VPC where the cluster will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EKS cluster and node groups"
  type        = list(string)
}

variable "sg_eks_nodes_id" {
  description = "Security group ID for EKS nodes"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "sandbox"
}

variable "node_instance_type" {
  description = "EC2 instance type for node group"
  type        = string
  default     = "t3.medium"
}
