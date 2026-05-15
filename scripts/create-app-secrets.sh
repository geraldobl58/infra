#!/usr/bin/env bash
# =============================================================================
# create-app-secrets.sh
# -----------------------------------------------------------------------------
# Cria os Kubernetes Secrets que as apps consomem via envFrom no chart
# helm/crivo-app. Os valores vêm do .env (na raiz da infra) e/ou de overrides
# por ambiente em config/secrets.<env>.env (gitignored).
#
# Uso:
#   ./scripts/create-app-secrets.sh <env>            # ex.: develop, prod
#   ./scripts/create-app-secrets.sh develop --dry-run
# =============================================================================

set -euo pipefail

ENV_NAME="${1:-}"
shift || true
DRY_RUN=""
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && DRY_RUN="--dry-run=client -o yaml"
done

if [[ -z "$ENV_NAME" ]]; then
  echo "Uso: $0 <develop|prod> [--dry-run]"
  exit 1
fi

NS="crivo-${ENV_NAME}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BASE_ENV="$INFRA_ROOT/.env"
OVERRIDE_ENV="$INFRA_ROOT/config/secrets.${ENV_NAME}.env"

# Carrega .env base e override do ambiente (override sobrescreve).
load_env() {
  local file="$1"
  if [[ -f "$file" ]]; then
    echo "📂 Carregando $file"
    set -a
    # shellcheck disable=SC1090
    source "$file"
    set +a
  fi
}

load_env "$BASE_ENV"
load_env "$OVERRIDE_ENV"

ensure_ns() {
  if ! kubectl get ns "$NS" >/dev/null 2>&1; then
    echo "📦 Namespace $NS não existe, criando..."
    kubectl create ns "$NS"
  fi
}

# create_secret <nome> KEY1 KEY2 ...
# Cada KEY é tanto o nome da variável no ambiente quanto a chave no secret.
create_secret() {
  local name="$1"; shift
  local args=()
  local has_any=false
  for key in "$@"; do
    local val="${!key:-}"
    if [[ -n "$val" ]]; then
      args+=("--from-literal=${key}=${val}")
      has_any=true
    fi
  done
  if ! $has_any; then
    echo "  ⚠️  $name: nenhuma var disponível, pulando"
    return
  fi
  kubectl -n "$NS" create secret generic "$name" \
    "${args[@]}" \
    --save-config \
    $DRY_RUN \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "  ✅ $name"
}

ensure_ns
echo "🔐 Criando secrets em $NS..."

# -- Auth ---------------------------------------------------------------------
create_secret crivo-auth-admin \
  KC_BOOTSTRAP_ADMIN_USERNAME \
  KC_BOOTSTRAP_ADMIN_PASSWORD

create_secret crivo-auth-db \
  KC_DB_URL \
  KC_DB_USERNAME \
  KC_DB_PASSWORD

# -- Backend ------------------------------------------------------------------
create_secret crivo-be-app \
  DATABASE_URL \
  KEYCLOAK_CLIENT_SECRET \
  BETTER_AUTH_SECRET

create_secret crivo-be-cloudinary \
  CLOUDINARY_CLOUD_NAME \
  CLOUDINARY_API_KEY \
  CLOUDINARY_API_SECRET \
  CLOUDINARY_FOLDER

create_secret crivo-be-stripe \
  STRIPE_SECRET_KEY \
  STRIPE_PUBLISHABLE_KEY \
  STRIPE_WEBHOOK_SECRET \
  STRIPE_PRICE_TRIAL \
  STRIPE_PRICE_BASIC \
  STRIPE_PRICE_PROFESSIONAL \
  STRIPE_PRICE_ENTERPRISE

create_secret crivo-be-mail \
  MAILTRAP_HOST \
  MAILTRAP_PORT \
  MAILTRAP_USER \
  MAILTRAP_PASSWORD

create_secret crivo-be-ai \
  ANTHROPIC_API_KEY

create_secret crivo-be-storage \
  AWS_ACCESS_KEY_ID \
  AWS_SECRET_ACCESS_KEY \
  S3_BUCKET

# -- Frontend -----------------------------------------------------------------
create_secret crivo-fe-auth \
  BETTER_AUTH_SECRET

echo "🎉 Secrets aplicados em $NS"
