#!/usr/bin/env bash
# =============================================================================
# apply-kong-config.sh
# -----------------------------------------------------------------------------
# Renderiza helm/crivo-app/apps/crivo-kong/kong.tmpl.yml substituindo
# variáveis do ambiente e aplica como ConfigMap `crivo-kong-config` no
# namespace `crivo-<env>`.
#
# Requisitos:
#   - config/secrets.<env>.env contendo KEYCLOAK_RSA_PUBLIC_KEY (multilinha
#     entre BEGIN/END PUBLIC KEY) ou a chave em config/keycloak.<env>.pub.
#
# Uso:
#   ./scripts/apply-kong-config.sh <develop|prod>
# =============================================================================

set -euo pipefail

ENV_NAME="${1:-}"
if [[ -z "$ENV_NAME" ]]; then
  echo "Uso: $0 <develop|prod>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPL="$INFRA_ROOT/helm/crivo-app/apps/crivo-kong/kong.tmpl.yml"
NS="crivo-${ENV_NAME}"

# Hosts e URLs por ambiente
KEYCLOAK_HOST="${ENV_NAME}.auth.crivo.local"
KEYCLOAK_REALM="${KEYCLOAK_REALM:-crivo}"
FRONTEND_ORIGIN="http://${ENV_NAME}.fe.crivo.local"
BE_INTERNAL_URL="http://crivo-be.${NS}.svc.cluster.local:3000"
AUTH_INTERNAL_URL="http://crivo-auth.${NS}.svc.cluster.local:8080"

# Chave pública do Keycloak: lê do arquivo dedicado ou do secrets.<env>.env
PUB_KEY_FILE="$INFRA_ROOT/config/keycloak.${ENV_NAME}.pub"
if [[ -f "$PUB_KEY_FILE" ]]; then
  PUB_KEY=$(<"$PUB_KEY_FILE")
elif [[ -n "${KEYCLOAK_RSA_PUBLIC_KEY:-}" ]]; then
  PUB_KEY="$KEYCLOAK_RSA_PUBLIC_KEY"
else
  echo "❌ Chave pública RS256 do Keycloak não encontrada."
  echo "   Crie $PUB_KEY_FILE com o conteúdo BASE64 (sem cabeçalho -----BEGIN-----),"
  echo "   ou exporte KEYCLOAK_RSA_PUBLIC_KEY antes de rodar este script."
  echo ""
  echo "   Como obter:"
  echo "   kubectl exec -n $NS deploy/crivo-auth -- \\"
  echo "     curl -s http://localhost:8080/realms/${KEYCLOAK_REALM}/protocol/openid-connect/certs \\"
  echo "     | jq -r '.keys[0].x5c[0]'"
  exit 1
fi

# Remove cabeçalhos PEM se vieram inclusos e indenta com 10 espaços (formato YAML).
PUB_KEY_BODY=$(echo "$PUB_KEY" \
  | sed -e '/-----BEGIN/d' -e '/-----END/d' \
  | tr -d '\r' \
  | awk 'NF { gsub(/^ +| +$/, ""); print "          " $0 }')

# Renderiza
RENDERED=$(sed \
  -e "s|{{ENV}}|${ENV_NAME}|g" \
  -e "s|{{KEYCLOAK_HOST}}|${KEYCLOAK_HOST}|g" \
  -e "s|{{KEYCLOAK_REALM}}|${KEYCLOAK_REALM}|g" \
  -e "s|{{FRONTEND_ORIGIN}}|${FRONTEND_ORIGIN}|g" \
  -e "s|{{BE_INTERNAL_URL}}|${BE_INTERNAL_URL}|g" \
  -e "s|{{AUTH_INTERNAL_URL}}|${AUTH_INTERNAL_URL}|g" \
  "$TMPL")

# Substitui {{KEYCLOAK_RSA_PUB_INDENTED}} pela chave multi-linha (sed simples
# não lida bem com multilinhas; usa python para inserir).
RENDERED=$(python3 -c "
import sys
tmpl = sys.argv[1]
pub  = sys.argv[2]
print(tmpl.replace('{{KEYCLOAK_RSA_PUB_INDENTED}}', pub))
" "$RENDERED" "$PUB_KEY_BODY")

# Garante namespace
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

# Aplica como ConfigMap
echo "$RENDERED" | kubectl create configmap crivo-kong-config \
  -n "$NS" --from-file=kong.yml=/dev/stdin \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ ConfigMap crivo-kong-config aplicado em $NS"

# Faz Kong recarregar o config (rollout restart força reread do volume)
if kubectl get deploy crivo-kong -n "$NS" >/dev/null 2>&1; then
  kubectl rollout restart deploy/crivo-kong -n "$NS"
  echo "🔁 Kong reiniciado em $NS"
fi
