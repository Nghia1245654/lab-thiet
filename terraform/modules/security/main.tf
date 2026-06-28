# 1. Security Group for Application Load Balancer (sg-alb)
resource "aws_security_group" "alb" {
  name        = "tf1-${var.environment}-sg-alb"
  description = "Security Group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Allow HTTPS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "tf1-${var.environment}-sg-alb"
    Environment = var.environment
  }
}

# 2. Security Group for EKS Managed Node Group (sg-eks-nodes)
resource "aws_security_group" "eks_nodes" {
  name        = "tf1-${var.environment}-sg-eks-nodes"
  description = "Security Group for EKS Managed Node Group"
  vpc_id      = var.vpc_id

  egress {
    description      = "Allow all outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "tf1-${var.environment}-sg-eks-nodes"
    Environment = var.environment
  }
}

# Ingress rule for EKS nodes from ALB
resource "aws_security_group_rule" "eks_nodes_from_alb" {
  type                     = "ingress"
  description              = "Allow traffic from ALB to EKS nodes"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.alb.id
}

# Egress rule for ALB to EKS nodes
resource "aws_security_group_rule" "alb_to_eks_nodes" {
  type                     = "egress"
  description              = "Allow traffic from ALB to EKS nodes"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb.id
  source_security_group_id = aws_security_group.eks_nodes.id
}


# 3. Security Group for Lambda Functions (sg-lambda)
resource "aws_security_group" "lambda" {
  name        = "tf1-${var.environment}-sg-lambda"
  description = "Security Group for Lambda Functions"
  vpc_id      = var.vpc_id

  egress {
    description      = "Allow all outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "tf1-${var.environment}-sg-lambda"
    Environment = var.environment
  }
}


# 4. Inbound rules added to sg-vpc-endpoints (created in networking module)
resource "aws_security_group_rule" "vpce_from_eks_nodes" {
  type                     = "ingress"
  description              = "Allow HTTPS from EKS nodes"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.sg_vpc_endpoints_id
  source_security_group_id = aws_security_group.eks_nodes.id
}

resource "aws_security_group_rule" "vpce_from_lambda" {
  type                     = "ingress"
  description              = "Allow HTTPS from Lambda"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = var.sg_vpc_endpoints_id
  source_security_group_id = aws_security_group.lambda.id
}
