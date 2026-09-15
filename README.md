# oficina-infra-db

Terraform do **banco de dados** da Oficina Mecânica
(Tech Challenge 13SOAT — Fase 3). Cria a rede (VPC) usada por todos os
repositórios, o banco **PostgreSQL no Amazon RDS** e o **Secrets Manager** com
as senhas.

## Links

| O quê | Link |
|---|---|
| 🚪 API em produção (API Gateway) | https://q7m1gn8vqi.execute-api.us-east-1.amazonaws.com |
| 🗂️ Diagrama ER e relacionamentos | [modelo-de-dados.md](https://github.com/Lorenalgm/oficina_mecanica/blob/main/docs/arquitetura/modelo-de-dados.md) |
| 📝 Por que PostgreSQL (RFC-002) | [RFC-002](https://github.com/Lorenalgm/oficina_mecanica/blob/main/docs/rfcs/RFC-002-banco-de-dados.md) |
| ⚙️ Código da API | [oficina_mecanica](https://github.com/Lorenalgm/oficina_mecanica) |
| 🔐 Autenticação | [oficina-auth-lambda](https://github.com/Lorenalgm/oficina-auth-lambda) |
| ☸️ Kubernetes | [oficina-infra-k8s](https://github.com/Lorenalgm/oficina-infra-k8s) |

> O banco fica em rede privada, sem acesso pela internet. Só a API e a Lambda
> de autenticação conseguem se conectar.

## Arquitetura

```mermaid
flowchart LR
    internet(["🌍 Internet"])

    subgraph vpc["🔒 VPC — rede da oficina (2 zonas de disponibilidade)"]
        direction LR

        subgraph pub["🌐 Subnets públicas"]
            direction TB
            lb["Load Balancer<br/>entrada do cluster"]
            nodes["⚙️ Nodes do EKS<br/>rodam a API"]
        end

        subgraph priv["🛡️ Subnets privadas — sem saída para a internet"]
            direction TB
            lambda["🪪 Lambdas<br/>de autenticação"]
            db[("🐘 PostgreSQL 16<br/>RDS")]
            vpce["🔌 Acesso privado<br/>ao Secrets Manager"]
        end
    end

    sm["🔑 Secrets Manager<br/>senha do banco e chave do token"]

    internet --> lb
    lb --> nodes
    nodes -->|"porta 5432"| db
    lambda -->|"porta 5432"| db
    lambda --> vpce
    vpce --> sm

    style vpc fill:#f8fafc,stroke:#64748b,color:#0f172a
    style pub fill:#eff6ff,stroke:#1d4ed8,color:#1e3a8a
    style priv fill:#f0fdf4,stroke:#15803d,color:#14532d
    classDef entry fill:#e2e8f0,stroke:#475569,color:#0f172a;
    classDef app fill:#dbeafe,stroke:#2563eb,color:#1e3a8a;
    classDef data fill:#dcfce7,stroke:#15803d,color:#14532d;
    classDef sec fill:#f5d0fe,stroke:#a21caf,color:#701a75;
    class internet entry;
    class lb,nodes app;
    class db data;
    class lambda,vpce,sm sec;
```

**Legenda:** 🟦 parte pública (API) · 🟩 banco · 🟪 autenticação e segredos

### Decisões de rede

- **Sem NAT Gateway.** Nada na parte privada precisa de internet. A Lambda
  acessa o Secrets Manager por um endpoint privado, bem mais barato. Isso
  importa porque o Learner Lab tem orçamento de USD 50.
- **O banco começa fechado.** O firewall (security group) do RDS nasce sem
  nenhuma regra de entrada. Cada repositório que precisa do banco libera o
  próprio acesso. Assim este repositório não depende dos outros.

## Por que PostgreSQL

Resumo da [RFC-002](https://github.com/Lorenalgm/oficina_mecanica/blob/main/docs/rfcs/RFC-002-banco-de-dados.md):

| Motivo | Exemplo no sistema |
|---|---|
| **Transações** | Aprovar um orçamento muda o status da OS, grava o histórico e baixa o estoque de todas as peças, tudo ou nada |
| **Chaves estrangeiras** | 10 tabelas ligadas; não é possível apagar um serviço que está em uso numa OS |
| **Consultas com agregação** | Tempo médio por status sai direto do histórico em SQL |
| **Valores exatos** | Preços em `decimal(10,2)`, sem erro de arredondamento |
| **Sem retrabalho** | A API já usava PostgreSQL na Fase 2 |

**Por que RDS e não o banco dentro do cluster:** backup automático, disco
criptografado, e os dados sobrevivem quando o cluster é destruído.

## Modelo de dados

```mermaid
erDiagram
  clientes ||--o{ veiculos : "possui"
  clientes ||--o{ os : "abre"
  veiculos ||--o{ os : "recebe"
  status   ||--o{ os : "é o status atual de"
  os       ||--o{ os_servicos : "inclui"
  servicos ||--o{ os_servicos : "é usado em"
  os_servicos ||--o{ os_servico_insumos : "consome"
  insumos     ||--o{ os_servico_insumos : "é consumido em"
  os       ||--o{ os_status : "tem histórico em"
  status   ||--o{ os_status : "aparece em"
  os       ||--o{ os_orcamentos : "recebe"
```

Colunas, regras de exclusão e explicação de cada relacionamento:
[modelo-de-dados.md](https://github.com/Lorenalgm/oficina_mecanica/blob/main/docs/arquitetura/modelo-de-dados.md).

## Stack

| Item | Escolha |
|---|---|
| Infraestrutura como código | Terraform ≥ 1.5 |
| Banco | Amazon RDS PostgreSQL 16, `db.t3.micro`, 20 GB criptografado |
| Segredos | AWS Secrets Manager (`oficina/app`) |
| Rede | VPC `10.0.0.0/16`, 2 zonas, subnets públicas e privadas |
| Estado do Terraform | S3 com trava no DynamoDB |

## Validar localmente

```bash
cd terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

## Deploy

Pré-requisito: bucket S3 e tabela DynamoDB para o estado do Terraform.

```bash
cd terraform
terraform init \
  -backend-config="bucket=<bucket do state>" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=<tabela de trava>"

terraform apply                 # cerca de 10 minutos
terraform output db_endpoint
```

**No AWS Academy:** as credenciais mudam a cada sessão de 4 horas. O RDS
continua cobrando entre sessões, então pause quando não estiver usando:

```bash
aws rds stop-db-instance  --db-instance-identifier oficina-db   # pausa por até 7 dias
aws rds start-db-instance --db-instance-identifier oficina-db
```

## CI/CD

| Workflow | Quando roda | O que faz |
|---|---|---|
| `ci.yml` | pull request | Valida o Terraform |
| `cd.yml` | push em `main` ou `develop` | Aplica o Terraform na AWS |

- `main` = produção, `develop` = homologação. A `main` só recebe código por pull request.
- Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`,
  `TFSTATE_BUCKET`, `TFSTATE_LOCK_TABLE`.
