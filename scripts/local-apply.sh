#!/usr/bin/env bash
# Aplica a infra localmente (Fase 1 + Fase 2) com as mesmas etapas da pipeline.
# Uso: ./scripts/local-apply.sh [environments/dev.tfvars]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# ── .env.local ────────────────────────────────────────────────────────────────
ENV_FILE="${ROOT_DIR}/.env.local"
[ -f "$ENV_FILE" ] || { echo "ERRO: .env.local não encontrado. Copie .env.local.example e preencha."; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

TFVARS="${1:-environments/dev.tfvars}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
NR_KEY="${TF_VAR_newrelic_license_key:?'TF_VAR_newrelic_license_key não definido no .env.local'}"
NR_ACCOUNT_ID="${TF_VAR_newrelic_account_id:?'TF_VAR_newrelic_account_id não definido no .env.local'}"
NR_API_KEY="${TF_VAR_newrelic_api_key:?'TF_VAR_newrelic_api_key não definido no .env.local'}"

# ── Bootstrap + init ──────────────────────────────────────────────────────────
bash scripts/bootstrap.sh
terraform init -input=false -reconfigure

# ── Lambda function name (lê do state remoto, fallback para env/default) ──────
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="fiap-tc-tfstate-${ACCOUNT_ID}"
LAMBDA_NAME=$(aws s3 cp "s3://${BUCKET}/lambda/terraform.tfstate" - 2>/dev/null \
  | jq -r '.outputs.function_name.value // empty' 2>/dev/null || true)
LAMBDA_NAME="${LAMBDA_NAME:-${TF_VAR_lambda_function_name:-autoflow-auth-homolog}}"
echo "lambda_function_name = ${LAMBDA_NAME}"

# ── Limpa recursos que causam conflito no re-apply ───────────────────────────
echo ""
echo "=== Limpando recursos conflitantes ==="
aws logs delete-log-group \
  --log-group-name /aws/eks/fiap-tc-dev-eks/cluster \
  --region "$REGION" 2>/dev/null && echo "Log group deletado" || echo "Log group não existe, ok"

# ── Variáveis comuns ──────────────────────────────────────────────────────────
TF_COMMON_VARS=(
  -var-file="$TFVARS"
  -var="lambda_function_name=${LAMBDA_NAME}"
  -var="newrelic_license_key=${NR_KEY}"
  -var="newrelic_account_id=${NR_ACCOUNT_ID}"
  -var="newrelic_api_key=${NR_API_KEY}"
)

# ── Fase 1: infra base ────────────────────────────────────────────────────────
echo ""
echo "=== Fase 1: infra base ==="
terraform apply -auto-approve -input=false \
  "${TF_COMMON_VARS[@]}" \
  -target=module.vpc \
  -target=module.eks \
  -target=aws_security_group.rds \
  -target=aws_security_group.lambda \
  -target=helm_release.kong \
  -target=helm_release.newrelic \
  -target=kubernetes_namespace.kong \
  -target=kubernetes_namespace.newrelic

# ── Configura kubectl ─────────────────────────────────────────────────────────
echo ""
echo "=== Configurando kubectl ==="
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "fiap-tc-dev-eks")
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

# ── Atualiza lambda name (pode ter sido deployada entre as fases) ─────────────
LAMBDA_NAME_UPDATED=$(aws s3 cp "s3://${BUCKET}/lambda/terraform.tfstate" - 2>/dev/null \
  | jq -r '.outputs.function_name.value // empty' 2>/dev/null || true)
LAMBDA_NAME="${LAMBDA_NAME_UPDATED:-$LAMBDA_NAME}"

TF_COMMON_VARS=(
  -var-file="$TFVARS"
  -var="lambda_function_name=${LAMBDA_NAME}"
  -var="newrelic_license_key=${NR_KEY}"
  -var="newrelic_account_id=${NR_ACCOUNT_ID}"
  -var="newrelic_api_key=${NR_API_KEY}"
)

# ── Fase 2: Kong routes + manifests ──────────────────────────────────────────
echo ""
echo "=== Fase 2: Kong routes + manifests ==="
terraform apply -auto-approve -input=false "${TF_COMMON_VARS[@]}"

# ── Sumário ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Deploy concluído ==="
terraform output