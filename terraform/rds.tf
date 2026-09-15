resource "aws_db_subnet_group" "principal" {
  name       = "${var.projeto}-db"
  subnet_ids = [for s in aws_subnet.privada : s.id]

  tags = { Name = "${var.projeto}-db-subnet-group" }
}

# O SG nasce sem ingress. Quem precisa do 5432 abre a própria regra a partir do
# seu repositório (a Lambda em oficina-auth-lambda, os nodes em
# oficina-infra-k8s), evitando dependência circular entre os states.
resource "aws_security_group" "db" {
  name        = "${var.projeto}-db"
  description = "Acesso ao PostgreSQL gerenciado"
  vpc_id      = aws_vpc.principal.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.projeto}-sg-db" }
}

resource "random_password" "db" {
  length = 24
  # O RDS rejeita /, @, " e espaço na senha master.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "principal" {
  identifier     = "${var.projeto}-db"
  engine         = "postgres"
  engine_version = var.db_versao
  instance_class = var.db_classe

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_nome
  username = var.db_usuario
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  # O Learner Lab não interrompe o RDS entre sessões: manter a janela de
  # manutenção curta e os upgrades automáticos desligados evita surpresa.
  auto_minor_version_upgrade = false

  tags = { Name = "${var.projeto}-db" }
}
