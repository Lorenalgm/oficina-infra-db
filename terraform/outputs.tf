output "vpc_id" {
  description = "VPC compartilhada pelos demais repositórios de infraestrutura."
  value       = aws_vpc.principal.id
}

output "private_subnet_ids" {
  description = "Subnets privadas: RDS e ENIs das Lambdas."
  value       = [for s in aws_subnet.privada : s.id]
}

output "public_subnet_ids" {
  description = "Subnets públicas: nodes do EKS e o NLB do ingress."
  value       = [for s in aws_subnet.publica : s.id]
}

output "db_sg_id" {
  description = "Security group do RDS. Quem precisa do 5432 cria a regra apontando para ele."
  value       = aws_security_group.db.id
}

output "db_endpoint" {
  description = "Endpoint host:porta do PostgreSQL."
  value       = aws_db_instance.principal.endpoint
}

output "db_host" {
  description = "Apenas o host do PostgreSQL."
  value       = aws_db_instance.principal.address
}

output "db_name" {
  description = "Nome do banco."
  value       = var.db_nome
}

output "secret_arn" {
  description = "ARN do segredo com credenciais do banco e o JWT_SECRET."
  value       = aws_secretsmanager_secret.app.arn
}
