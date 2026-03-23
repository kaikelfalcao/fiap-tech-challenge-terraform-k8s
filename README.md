# fiap-tech-challenge-terraform-k8s

Infraestrutura Kubernetes do **AutoFlow** — provisiona EKS, Kong API Gateway,
New Relic e todos os recursos de rede via Terraform.

## Tecnologias

| Camada          | Tecnologia                              |
| --------------- | --------------------------------------- |
| Cloud           | AWS (EKS, VPC, NLB, Security Groups)    |
| IaC             | Terraform 1.7+                          |
| Kubernetes      | EKS 1.31                                |
| API Gateway     | Kong 2.38 (DB-less, Ingress Controller) |
| Observabilidade | New Relic nri-bundle 5.0                |
| CI/CD           | GitHub Actions                          |

## Estrutura

```
eks.tf              ← cluster EKS + node group (LabRole)
vpc.tf              ← VPC, subnets públicas/privadas, NAT gateway
kong.tf             ← Kong Helm release + rotas /auth e /api/*
newrelic.tf         ← New Relic nri-bundle (infra, logs, eventos)
security-groups.tf  ← SGs do RDS e da Lambda
outputs.tf          ← endpoints, IDs de SG e subnets
variables.tf        ← todas as variáveis com descrições
versions.tf         ← versões dos providers

environments/
  dev.tfvars        ← configuração para desenvolvimento
  staging.tfvars    ← configuração para homologação
  prod.tfvars        ← configuração para produção

scripts/
  bootstrap.sh      ← cria bucket S3 e gera backend.tf
```

## Arquitetura

```
Internet
    │
    ▼
Kong API Gateway (NLB público)
    ├── POST /auth → aws-lambda plugin → Lambda de autenticação
    └── /api/*    → autoflow.autoflow.svc.cluster.local (NestJS)
                           │
                           ▼
                     RDS PostgreSQL
                     (subnet privada)
```

## Pré-requisitos

- Terraform 1.7+
- AWS CLI configurado
- kubectl
- Credenciais AWS com LabRole (AWS Academy)

## Deploy manual

### AWS Lab — configurar credenciais

```bash
aws configure set aws_access_key_id     <KEY>    --profile lab
aws configure set aws_secret_access_key <SECRET> --profile lab
aws configure set aws_session_token     <TOKEN>  --profile lab
export AWS_PROFILE=lab
```

### Bootstrap do backend S3

```bash
bash scripts/bootstrap.sh
```

### Fase 1 — EKS + Kong + New Relic (~15 min)

```bash
rm -rf .terraform .terraform.lock.hcl
terraform init

terraform apply \
  -var-file="./environments/dev.tfvars" \
  -var="newrelic_license_key=<NR_KEY>" \
  -var="lambda_function_name=autoflow-auth-homolog" \
  -target=module.vpc \
  -target=module.eks \
  -target=aws_security_group.rds \
  -target=aws_security_group.lambda \
  -target=helm_release.kong \
  -target=helm_release.newrelic \
  -target=kubernetes_namespace.kong \
  -target=kubernetes_namespace.newrelic
```

### Configura kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name fiap-tc-dev-eks
kubectl get nodes
```

### Fase 2 — Kong routes + manifests

```bash
terraform apply \
  -var-file="./environments/dev.tfvars" \
  -var="newrelic_license_key=<NR_KEY>" \
  -var="lambda_function_name=autoflow-auth-homolog"
```

### Verificar

```bash
# Nodes
kubectl get nodes

# Kong
kubectl get pods -n kong
kubectl get ingress -n kong

# New Relic
kubectl get pods -n newrelic

# URL do Kong
kubectl get svc -n kong kong-kong-proxy \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## CI/CD

| Evento            | Comportamento                                         |
| ----------------- | ----------------------------------------------------- |
| PR para `main`    | Validate + fmt check + terraform plan comentado no PR |
| Push em `develop` | Deploy automático (ambiente develop)                  |
| Merge em `main`   | Deploy para produção (requer aprovação no GitHub)     |

### Secrets necessários

| Secret                  | Descrição                                           |
| ----------------------- | --------------------------------------------------- |
| `AWS_ACCESS_KEY_ID`     | Credencial AWS Lab                                  |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS Lab                                  |
| `AWS_SESSION_TOKEN`     | Session token (obrigatório no Lab)                  |
| `NEWRELIC_LICENSE_KEY`  | Chave de ingest do New Relic                        |
| `LAMBDA_FUNCTION_NAME`  | Nome da função Lambda (ex: `autoflow-auth-homolog`) |

## Outputs importantes

Após o apply, os outputs são usados pelos outros repos:

```bash
terraform output private_subnet_ids      # usado pelo repo lambda
terraform output lambda_security_group_id # usado pelo repo lambda
terraform output rds_security_group_id   # usado pelo repo db
terraform output cluster_name            # usado pelo repo codebase
terraform output kong_proxy_url          # URL pública do Kong
```

## Observações AWS Lab

- O lab bloqueia `iam:CreateRole` e `iam:CreateOpenIDConnectProvider`
- Todos os recursos usam a `LabRole` existente (`enable_irsa = false`)
- O session token expira em ~4h — atualize os secrets antes de cada deploy
- O `backend.tf` é gerado pelo `bootstrap.sh` e não é versionado
