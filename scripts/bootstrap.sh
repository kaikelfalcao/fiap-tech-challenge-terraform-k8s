#!/usr/bin/env bash
set -e

REGION=${AWS_REGION:-us-east-1}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="fiap-tc-tfstate-${ACCOUNT_ID}"

echo ""
echo "Bootstrap Terraform Backend"
echo "==========================="
echo "Account : $ACCOUNT_ID"
echo "Bucket  : $BUCKET"
echo "Region  : $REGION"
echo ""

if aws s3 ls "s3://${BUCKET}" > /dev/null 2>&1; then
  echo "✓ Bucket já existe"
else
  echo "→ Criando bucket..."
  aws s3 mb "s3://${BUCKET}" --region "$REGION"

  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

  echo "✓ Bucket criado"
fi

cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket       = "${BUCKET}"
    key          = "k8s-infra/terraform.tfstate"
    region       = "${REGION}"
    use_lockfile = true
    encrypt      = true
  }
}
EOF

echo "✓ backend.tf gerado"
echo ""
echo "Próximo passo:"
echo "  rm -rf .terraform/ .terraform.lock.hcl"
echo "  terraform init"