#!/usr/bin/env bash
# Valida o plano Terraform localmente sem aplicar nada.
# Uso: ./scripts/local-plan.sh [environments/dev.tfvars]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

ENV_FILE="${ROOT_DIR}/.env.local"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: .env.local não encontrado."
  echo "      Copie .env.local.example → .env.local e preencha as credenciais."
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

TFVARS="${1:-environments/dev.tfvars}"

bash scripts/bootstrap.sh

terraform init -input=false -reconfigure

# Lê lambda_function_name do state S3 do repo lambda (fallback: valor da variável)
BUCKET="fiap-tc-tfstate-$(aws sts get-caller-identity --query Account --output text)"
LAMBDA_NAME=$(aws s3 cp "s3://${BUCKET}/lambda/terraform.tfstate" - 2>/dev/null | \
  jq -r '.outputs.function_name.value // empty' 2>/dev/null || true)
LAMBDA_NAME="${LAMBDA_NAME:-${TF_VAR_lambda_function_name:-autoflow-auth-homolog}}"

terraform plan -lock=false -input=false \
  -var-file="$TFVARS" \
  -var="lambda_function_name=${LAMBDA_NAME}" \
  -var="newrelic_license_key=${TF_VAR_newrelic_license_key}"

