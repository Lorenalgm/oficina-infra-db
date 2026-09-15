# Segredo HS256 compartilhado entre a Lambda que emite o JWT e a oficina-api,
# que o revalida. Gerado aqui para que nenhum dos dois lados precise versioná-lo.
resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "app" {
  name = "${var.projeto}/app"
  # O Learner Lab reaproveita a conta entre execuções; sem isso, um destroy
  # seguido de apply esbarra em "secret scheduled for deletion".
  recovery_window_in_days = 0

  tags = { Name = "${var.projeto}-app-secret" }
}

resource "aws_secretsmanager_secret_version" "app" {
  secret_id = aws_secretsmanager_secret.app.id

  secret_string = jsonencode({
    DB_HOST     = aws_db_instance.principal.address
    DB_PORT     = aws_db_instance.principal.port
    DB_DATABASE = var.db_nome
    DB_USERNAME = var.db_usuario
    DB_PASSWORD = random_password.db.result
    JWT_SECRET  = random_password.jwt.result
  })
}
