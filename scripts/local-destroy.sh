#!/usr/bin/env bash
# Destrói toda a infra e, opcionalmente, limpa o bucket S3 de state.
# Uso: ./scripts/local-destroy.sh [--purge-bucket] [environments/dev.tfvars]
#
#   --purge-bucket   Remove também o bucket S3 (e todos os states nele).
#                    CUIDADO: isso apaga o state de todos os repos que usam o bucket.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PURGE_BUCKET=false
TFVARS="environments/dev.tfvars"
for arg in "$@"; do
  case "$arg" in
    --purge-bucket) PURGE_BUCKET=true ;;
    environments/*.tfvars) TFVARS="$arg" ;;
  esac
done

ENV_FILE="${ROOT_DIR}/.env.local"
if [ ! -f "$ENV_FILE" ]; then
  echo "ERRO: .env.local não encontrado."
  echo "      Copie .env.local.example → .env.local e preencha as credenciais."
  exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="fiap-tc-tfstate-${ACCOUNT_ID}"

# Garante que backend.tf existe antes de init
if [ ! -f backend.tf ]; then
  bash scripts/bootstrap.sh
fi

terraform init -input=false -reconfigure

LAMBDA_NAME=$(aws s3 cp "s3://${BUCKET}/lambda/terraform.tfstate" - 2>/dev/null | \
  jq -r '.outputs.function_name.value // empty' 2>/dev/null || true)
LAMBDA_NAME="${LAMBDA_NAME:-${TF_VAR_lambda_function_name:-autoflow-auth-homolog}}"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ATENÇÃO: isso vai destruir toda a infra do cluster  ║"
if $PURGE_BUCKET; then
echo "║  E remover o bucket S3 com TODOS os states!          ║"
fi
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -r -p "Confirme digitando 'destroy': " CONFIRM
if [ "$CONFIRM" != "destroy" ]; then
  echo "Cancelado."
  exit 1
fi

echo ""
echo "=== terraform destroy ==="
terraform destroy -auto-approve -input=false \
  -var-file="$TFVARS" \
  -var="lambda_function_name=${LAMBDA_NAME}"

echo ""
echo "=== Removendo state file do k8s-infra ==="
aws s3 rm "s3://${BUCKET}/k8s-infra/terraform.tfstate" 2>/dev/null || true
aws s3 rm "s3://${BUCKET}/k8s-infra/terraform.tfstate.tflock" 2>/dev/null || true

if $PURGE_BUCKET; then
  echo ""
  echo "=== Purgando bucket S3: ${BUCKET} ==="
  # Remove todas as versões e delete markers
  aws s3api list-object-versions \
    --bucket "${BUCKET}" \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' \
    --output json 2>/dev/null | \
    jq -r '.[] | "\(.Key) \(.VersionId)"' 2>/dev/null | \
    while read -r KEY VID; do
      aws s3api delete-object --bucket "${BUCKET}" --key "$KEY" --version-id "$VID" 2>/dev/null || true
    done
  aws s3api list-object-versions \
    --bucket "${BUCKET}" \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
    --output json 2>/dev/null | \
    jq -r '.[] | "\(.Key) \(.VersionId)"' 2>/dev/null | \
    while read -r KEY VID; do
      aws s3api delete-object --bucket "${BUCKET}" --key "$KEY" --version-id "$VID" 2>/dev/null || true
    done
  aws s3 rb "s3://${BUCKET}" 2>/dev/null || true
  echo "Bucket ${BUCKET} removido."
fi

echo ""
echo "=== Infra destruída sem rastros. ==="
