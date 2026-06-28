output "sg_alb_id" {
  description = "The ID of the Security Group for Application Load Balancer"
  value       = aws_security_group.alb.id
}

output "sg_eks_nodes_id" {
  description = "The ID of the Security Group for EKS Nodes"
  value       = aws_security_group.eks_nodes.id
}

output "sg_lambda_id" {
  description = "The ID of the Security Group for Lambda Functions"
  value       = aws_security_group.lambda.id
}
