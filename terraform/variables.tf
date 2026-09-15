variable "aws_region" {
  description = "Região da AWS. O AWS Academy Learner Lab só libera us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "projeto" {
  description = "Prefixo aplicado ao nome de todos os recursos."
  type        = string
  default     = "oficina"
}

variable "cidr_vpc" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_nome" {
  description = "Nome do banco criado na instância."
  type        = string
  default     = "oficina"
}

variable "db_usuario" {
  description = "Usuário master do PostgreSQL."
  type        = string
  default     = "oficina"
}

variable "db_classe" {
  description = <<-DOC
    Classe da instância RDS. db.t3.micro cabe no free tier e é suficiente para a
    carga do desafio; o orçamento de USD 50 do Learner Lab não comporta classes
    maiores rodando entre sessões.
  DOC
  type        = string
  default     = "db.t3.micro"
}

variable "db_versao" {
  description = "Versão maior do PostgreSQL."
  type        = string
  default     = "16"
}
