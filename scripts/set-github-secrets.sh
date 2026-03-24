#!/usr/bin/env bash
# Seta os GitHub secrets em todos os repos e gera .env.local em cada um.
#
# Uso:
#   ./scripts/set-github-secrets.sh setup    # primeira vez — seta tudo + gera todos os .env.local
#   ./scripts/set-github-secrets.sh refresh  # renova credenciais AWS (GitHub + .env.local)
#   ./scripts/set-github-secrets.sh local    # só gera/atualiza os .env.local (sem GitHub)
#
# Pré-requisito para setup/refresh: gh CLI autenticado (gh auth login)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_FILE="${ROOT_DIR}/secret.env"

if [ ! -f "$SECRETS_FILE" ]; then
  echo "ERRO: secret.env não encontrado."
  echo "      Copie secret.env.example → secret.env e preencha os valores."
  exit 1
fi

# shellcheck source=/dev/null
source "$SECRETS_FILE"

# Paths locais com fallback para valores padrão
LOCAL_DB="${LOCAL_DB:-../db}"
LOCAL_LAMBDA="${LOCAL_LAMBDA:-../lambda}"
LOCAL_CODEBASE="${LOCAL_CODEBASE:-../codebase}"

MODE="${1:-refresh}"

# ── helpers ───────────────────────────────────────────────────────────────────
set_secret() {
  local repo="$1" name="$2" value="$3"
  if [ -z "$value" ]; then
    echo "  AVISO: ${name} está vazio, pulando."
    return
  fi
  gh secret set "$name" --repo "$repo" --body "$value"
  echo "  ✓ ${repo} → ${name}"
}

set_aws() {
  local repo="$1"
  set_secret "$repo" AWS_ACCESS_KEY_ID     "$AWS_ACCESS_KEY_ID"
  set_secret "$repo" AWS_SECRET_ACCESS_KEY "$AWS_SECRET_ACCESS_KEY"
  set_secret "$repo" AWS_SESSION_TOKEN     "$AWS_SESSION_TOKEN"
}

write_env() {
  local path="$1"
  local content="$2"
  local target
  target="$(cd "${ROOT_DIR}" && realpath -m "${path}/.env.local" 2>/dev/null || echo "${ROOT_DIR}/${path}/.env.local")"
  local dir
  dir="$(dirname "$target")"
  if [ ! -d "$dir" ]; then
    echo "  AVISO: diretório ${dir} não encontrado, pulando."
    return
  fi
  printf '%s\n' "$content" > "$target"
  echo "  ✓ ${target}"
}

# ── gera .env.local para cada repo ────────────────────────────────────────────
write_all_local_envs() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"

  echo "[ .env.local ]"

  # k8s
  write_env "." "# Gerado por scripts/set-github-secrets.sh em ${ts}
# NÃO commite este arquivo.

# ── AWS Lab (renove a cada ~4h) ────────────────────────────────────────────────
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
export AWS_DEFAULT_REGION=us-east-1

# ── Secrets da aplicação ───────────────────────────────────────────────────────
export TF_VAR_newrelic_license_key=${NEWRELIC_LICENSE_KEY}
export TF_VAR_newrelic_account_id=${NEWRELIC_ACCOUNT_ID}
export TF_VAR_newrelic_api_key=${NEWRELIC_API_KEY}
export TF_VAR_newrelic_alert_email=${NEWRELIC_ALERT_EMAIL}

# ── Opcional: sobrescreve o nome da Lambda se o repo lambda ainda não foi deployado
# export TF_VAR_lambda_function_name=autoflow-auth-homolog"

  # db
  write_env "$LOCAL_DB" "# Gerado por scripts/set-github-secrets.sh em ${ts}
# NÃO commite este arquivo.

# ── AWS Lab (renove a cada ~4h) ────────────────────────────────────────────────
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
export AWS_DEFAULT_REGION=us-east-1"

  # lambda
  write_env "$LOCAL_LAMBDA" "# Gerado por scripts/set-github-secrets.sh em ${ts}
# NÃO commite este arquivo.

# ── AWS Lab (renove a cada ~4h) ────────────────────────────────────────────────
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
export AWS_DEFAULT_REGION=us-east-1

# ── Secrets da aplicação ───────────────────────────────────────────────────────
export JWT_SECRET=${JWT_SECRET}
export NEWRELIC_ACCOUNT_ID=${NEWRELIC_ACCOUNT_ID}
export NEWRELIC_LICENSE_KEY=${NEWRELIC_LICENSE_KEY}

# ── Ambiente alvo (homolog ou production) ──────────────────────────────────────
export LAMBDA_ENV=homolog"

  # codebase
  write_env "$LOCAL_CODEBASE" "# Gerado por scripts/set-github-secrets.sh em ${ts}
# NÃO commite este arquivo.

# ── AWS Lab (renove a cada ~4h) ────────────────────────────────────────────────
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
export AWS_DEFAULT_REGION=us-east-1

# ── Secrets da aplicação ───────────────────────────────────────────────────────
export JWT_SECRET=${JWT_SECRET}
export NEWRELIC_LICENSE_KEY=${NEWRELIC_LICENSE_KEY}"
}

# ── modo refresh: renova credenciais AWS nos 4 repos + todos os .env.local ────
refresh() {
  echo ""
  echo "Renovando credenciais AWS em todos os repos..."
  echo ""
  for repo in "$REPO_K8S" "$REPO_DB" "$REPO_LAMBDA" "$REPO_CODEBASE"; do
    echo "[ $repo ]"
    set_aws "$repo"
    echo ""
  done
  write_all_local_envs
  echo ""
  echo "Credenciais AWS renovadas. Válidas por ~4h."
}

# ── modo setup: seta tudo + todos os .env.local ────────────────────────────────
setup() {
  echo ""
  echo "Setup completo de secrets em todos os repos..."
  echo ""

  echo "[ $REPO_K8S ]"
  set_aws "$REPO_K8S"
  set_secret "$REPO_K8S" NEWRELIC_LICENSE_KEY  "$NEWRELIC_LICENSE_KEY"
  set_secret "$REPO_K8S" NEWRELIC_ACCOUNT_ID   "$NEWRELIC_ACCOUNT_ID"
  set_secret "$REPO_K8S" NEWRELIC_API_KEY       "$NEWRELIC_API_KEY"
  set_secret "$REPO_K8S" NEWRELIC_ALERT_EMAIL   "$NEWRELIC_ALERT_EMAIL"

  echo ""
  echo "[ $REPO_DB ]"
  set_aws "$REPO_DB"

  echo ""
  echo "[ $REPO_LAMBDA ]"
  set_aws "$REPO_LAMBDA"
  set_secret "$REPO_LAMBDA" JWT_SECRET          "$JWT_SECRET"
  set_secret "$REPO_LAMBDA" NEWRELIC_LICENSE_KEY "$NEWRELIC_LICENSE_KEY"
  set_secret "$REPO_LAMBDA" NEWRELIC_ACCOUNT_ID  "$NEWRELIC_ACCOUNT_ID"

  echo ""
  echo "[ $REPO_CODEBASE ]"
  set_aws "$REPO_CODEBASE"
  set_secret "$REPO_CODEBASE" JWT_SECRET           "$JWT_SECRET"
  set_secret "$REPO_CODEBASE" NEWRELIC_LICENSE_KEY "$NEWRELIC_LICENSE_KEY"
  set_secret "$REPO_CODEBASE" NEWRELIC_ACCOUNT_ID  "$NEWRELIC_ACCOUNT_ID"
  set_secret "$REPO_CODEBASE" NEWRELIC_API_KEY      "$NEWRELIC_API_KEY"
  set_secret "$REPO_CODEBASE" NEWRELIC_ALERT_EMAIL  "$NEWRELIC_ALERT_EMAIL"
  set_secret "$REPO_CODEBASE" DOCKER_USERNAME       "$DOCKER_USERNAME"
  set_secret "$REPO_CODEBASE" DOCKER_PASSWORD       "$DOCKER_PASSWORD"

  echo ""
  write_all_local_envs

  echo ""
  echo "Setup concluído."
  echo ""
  echo "Lembre-se: AWS_SESSION_TOKEN expira em ~4h. Para renovar:"
  echo "  ./scripts/set-github-secrets.sh refresh"
}

# ── modo local: só gera os .env.local, sem tocar no GitHub ───────────────────
local_env() {
  echo ""
  echo "Gerando .env.local em todos os repos a partir de secret.env..."
  echo ""
  write_all_local_envs
  echo ""
  echo "Pronto. Em cada repo: source .env.local"
}

# ── entrada ───────────────────────────────────────────────────────────────────
case "$MODE" in
  setup)   setup     ;;
  refresh) refresh   ;;
  local)   local_env ;;
  *)
    echo "Uso: $0 [setup|refresh|local]"
    echo "  setup    — seta todos os secrets nos 4 repos + gera todos os .env.local"
    echo "  refresh  — renova credenciais AWS nos 4 repos + atualiza todos os .env.local"
    echo "  local    — só gera/atualiza os .env.local (sem GitHub)"
    exit 1
    ;;
esac
