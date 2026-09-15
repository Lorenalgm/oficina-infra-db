# A Lambda roda nas subnets privadas sem NAT, então precisa de um endpoint de
# interface para falar com o Secrets Manager sem sair para a internet.
resource "aws_security_group" "endpoints" {
  name        = "${var.projeto}-vpc-endpoints"
  description = "Permite HTTPS de dentro da VPC para os VPC endpoints"
  vpc_id      = aws_vpc.principal.id

  ingress {
    description = "HTTPS a partir da VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_vpc]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.projeto}-sg-vpc-endpoints" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.principal.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.privada : s.id]
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.projeto}-vpce-secretsmanager" }
}
