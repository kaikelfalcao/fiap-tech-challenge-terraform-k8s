# FIAP Tech Challenge - Kubernetes Infrastructure

Terraform para provisionamento da infraestrutura Kubernetes (EKS) na AWS.

## Recursos Provisionados

- **VPC** com subnets publicas e privadas em 3 AZs
- **NAT Gateway** para acesso a internet das subnets privadas
- **EKS Cluster** com managed node groups
- **Security Groups** para EKS e RDS
- **IAM Roles** para cluster e nodes

## Pre-requisitos

- Terraform >= 1.5.0
- AWS CLI configurado com credenciais
- S3 bucket e DynamoDB table para remote state

### Criar backend S3

```bash
aws s3 mb s3://fiap-tech-challenge-tfstate --region us-east-1

aws dynamodb create-table \
  --table-name fiap-tech-challenge-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Uso

```bash
# Inicializar
terraform init

# Planejar (dev)
terraform plan -var-file=environments/dev.tfvars

# Aplicar (dev)
terraform apply -var-file=environments/dev.tfvars

# Configurar kubeconfig
aws eks update-kubeconfig --region us-east-1 --name fiap-tech-challenge-dev-eks
```

## Ambientes

| Arquivo | Descricao |
|---------|-----------|
| `environments/dev.tfvars` | Desenvolvimento - nodes t3.medium, 2-4 nodes |
| `environments/staging.tfvars` | Staging - nodes t3.medium, 2-4 nodes |
| `environments/prod.tfvars` | Producao - nodes t3.large, 3-6 nodes, NAT multi-AZ |

## Outputs

| Output | Descricao |
|--------|-----------|
| `vpc_id` | ID da VPC |
| `private_subnet_ids` | IDs das subnets privadas |
| `public_subnet_ids` | IDs das subnets publicas |
| `cluster_name` | Nome do cluster EKS |
| `cluster_endpoint` | Endpoint da API do EKS |
| `node_security_group_id` | Security group dos nodes |
| `rds_security_group_id` | Security group para RDS (usado pelo repo de DB) |

## Integracao com Repo de Banco de Dados

O repositorio `fiap-tech-challenge-db-infra` consome os outputs deste repositorio via `terraform_remote_state`. Os outputs exportados incluem VPC ID, subnet IDs e o security group do RDS.
