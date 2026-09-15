data "aws_availability_zones" "disponiveis" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.disponiveis.names, 0, 2)
}

resource "aws_vpc" "principal" {
  cidr_block           = var.cidr_vpc
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.projeto}-vpc" }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = { Name = "${var.projeto}-igw" }
}

# Subnets públicas: nodes do EKS e o Network Load Balancer do ingress.
resource "aws_subnet" "publica" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id                  = aws_vpc.principal.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.cidr_vpc, 8, each.value)
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.projeto}-publica-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Subnets privadas: RDS e as ENIs das Lambdas. Sem NAT Gateway — a Lambda não
# precisa de internet e o NAT continuaria cobrando entre as sessões do Learner
# Lab. O acesso ao Secrets Manager sai por VPC endpoint (ver endpoints.tf).
resource "aws_subnet" "privada" {
  for_each = { for i, az in local.azs : az => i }

  vpc_id            = aws_vpc.principal.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(var.cidr_vpc, 8, each.value + 10)

  tags = {
    Name                              = "${var.projeto}-privada-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = { Name = "${var.projeto}-rt-publica" }
}

resource "aws_route_table_association" "publica" {
  for_each = aws_subnet.publica

  subnet_id      = each.value.id
  route_table_id = aws_route_table.publica.id
}

# A tabela privada fica sem rota default de propósito: nada nas subnets privadas
# deve alcançar a internet.
resource "aws_route_table" "privada" {
  vpc_id = aws_vpc.principal.id

  tags = { Name = "${var.projeto}-rt-privada" }
}

resource "aws_route_table_association" "privada" {
  for_each = aws_subnet.privada

  subnet_id      = each.value.id
  route_table_id = aws_route_table.privada.id
}
