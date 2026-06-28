# 1. VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "tf1-${var.environment}-vpc"
    Environment = var.environment
  }
}

# 2. Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "tf1-${var.environment}-public-subnet-${var.availability_zones[count.index]}"
    Environment              = var.environment
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "tf1-${var.environment}-private-subnet-${var.availability_zones[count.index]}"
    Environment                       = var.environment
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# 3. Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "tf1-${var.environment}-igw"
    Environment = var.environment
  }
}

# 4. NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "tf1-${var.environment}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Đặt NAT GW ở public subnet đầu tiên

  tags = {
    Name        = "tf1-${var.environment}-nat-gw"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.igw]
}

# 5. Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "tf1-${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "tf1-${var.environment}-private-rt"
    Environment = var.environment
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# 6. Security Group for VPC Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "tf1-${var.environment}-sg-vpc-endpoints"
  description = "Security group for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main.id


  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "tf1-${var.environment}-sg-vpc-endpoints"
    Environment = var.environment
  }
}

# 7. Gateway VPC Endpoints (S3, DynamoDB)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name        = "tf1-${var.environment}-vpce-s3"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name        = "tf1-${var.environment}-vpce-dynamodb"
    Environment = var.environment
  }
}

# 8. Interface VPC Endpoints (SQS, ECR API, ECR DKR, Logs, STS, Secrets Manager)
locals {
  interface_services = {
    sqs            = "com.amazonaws.us-east-1.sqs"
    ecr_api        = "com.amazonaws.us-east-1.ecr.api"
    ecr_dkr        = "com.amazonaws.us-east-1.ecr.dkr"
    logs           = "com.amazonaws.us-east-1.logs"
    sts            = "com.amazonaws.us-east-1.sts"
    secretsmanager = "com.amazonaws.us-east-1.secretsmanager"
  }
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each = local.interface_services

  vpc_id              = aws_vpc.main.id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "tf1-${var.environment}-vpce-${each.key}"
    Environment = var.environment
  }
}
