#!/usr/bin/env bash
# =============================================================================
# import-keycloak-realm.sh
# -----------------------------------------------------------------------------
# Aplica um realm-export.json como ConfigMap `keycloak-realm-import` no
# namespace do ambiente. Na próxima vez que o pod do crivo-auth subir
# (com --import-realm nos args), o realm é importado.
#
# Uso:
#   ./scripts/import-keycloak-realm.sh <develop|prod> <path/to/realm.json>
#
# Como obter o realm.json:
#
# 1) Do Keycloak antigo (docker-compose):
#    docker exec crivo-auth-dev /opt/keycloak/bin/kc.sh export \
#       --realm crivo --file /tmp/realm.json
#    docker cp crivo-auth-dev:/tmp/realm.json ./crivo-realm.json
#
# 2) Do Keycloak no cluster (após criar via UI):
#    kubectl exec -n crivo-develop deploy/crivo-auth -- \
#      /opt/keycloak/bin/kc.sh export --realm crivo --file /tmp/realm.json
#    kubectl cp crivo-develop/<pod>:/tmp/realm.json ./crivo-realm.json
# =============================================================================

set -euo pipefail

ENV_NAME="${1:-}"
REALM_FILE="${2:-}"

if [[ -z "$ENV_NAME" || -z "$REALM_FILE" ]]; then
  echo "Uso: $0 <develop|prod> <path/to/realm.json>"
  exit 1
fi

if [[ ! -f "$REALM_FILE" ]]; then
  echo "❌ Arquivo não encontrado: $REALM_FILE"
  exit 1
fi

NS="crivo-${ENV_NAME}"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

kubectl create configmap keycloak-realm-import \
  -n "$NS" \
  --from-file=realm.json="$REALM_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ ConfigMap keycloak-realm-import aplicado em $NS"

# Rolando pod para aplicar
if kubectl get deploy crivo-auth -n "$NS" >/dev/null 2>&1; then
  kubectl rollout restart deploy/crivo-auth -n "$NS"
  echo "🔁 Keycloak reiniciado em $NS (vai importar o realm no startup)"
fi
