#!/usr/bin/env bash
# =============================================================================
# setup-postgres.sh
# -----------------------------------------------------------------------------
# Cria PostgreSQL no namespace crivo-<env>:
#   - ConfigMap postgres-init (cria bancos crivo_keycloak + crivo_better_auth)
#   - Service postgres (ClusterIP, 5432)
#   - Deployment postgres com volume emptyDir (volátil)
#
# emptyDir vs PVC: o local-path provisioner do k3d no macOS mapeia pra um
# path no host; o Finder/Spotlight injeta arquivos AppleDouble (._*) ali e
# Postgres trava com "Operation not permitted". emptyDir evita esse problema
# 100%. Em troca, dados são perdidos no restart do pod — mas migrations +
# seed + import-realm são reprodutíveis via make targets.
#
# Uso:
#   ./scripts/setup-postgres.sh <develop|prod> [--reset]
#
# --reset: apaga deployment primeiro (forçar recriação).
# =============================================================================

set -euo pipefail

ENV_NAME="${1:-}"
shift || true
RESET=false
for arg in "$@"; do
  [[ "$arg" == "--reset" ]] && RESET=true
done

if [[ -z "$ENV_NAME" ]]; then
  echo "Uso: $0 <develop|prod> [--reset]"
  exit 1
fi

NS="crivo-${ENV_NAME}"
kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create ns "$NS"

if $RESET; then
  echo "🗑️  Reset solicitado, apagando deployment..."
  kubectl delete deploy postgres -n "$NS" --ignore-not-found --wait=true
fi

# ConfigMap com init scripts (cria bancos extras)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init
  namespace: ${NS}
data:
  init-extra-dbs.sh: |
    #!/bin/bash
    set -e
    psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" <<-EOSQL
      CREATE DATABASE crivo_keycloak;
      GRANT ALL PRIVILEGES ON DATABASE crivo_keycloak TO "\$POSTGRES_USER";
      CREATE DATABASE crivo_better_auth;
      GRANT ALL PRIVILEGES ON DATABASE crivo_better_auth TO "\$POSTGRES_USER";
    EOSQL
EOF

# Apaga PVC legacy se existir (migramos pra emptyDir)
kubectl delete pvc postgres-pvc -n "$NS" --ignore-not-found --wait=false >/dev/null 2>&1 || true

# Service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ${NS}
  labels:
    app: postgres
spec:
  type: ClusterIP
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
  selector:
    app: postgres
EOF

# Deployment com initContainer limpando macOS metadata
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: ${NS}
  labels:
    app: postgres
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - name: POSTGRES_USER
              value: crivo
            - name: POSTGRES_PASSWORD
              value: crivo_password
            - name: POSTGRES_DB
              value: crivo_app
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          ports:
            - containerPort: 5432
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "crivo"]
            initialDelaySeconds: 10
            periodSeconds: 5
          resources:
            limits: { cpu: 500m, memory: 512Mi }
            requests: { cpu: 50m, memory: 128Mi }
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
            - name: init
              mountPath: /docker-entrypoint-initdb.d
      volumes:
        - name: data
          # emptyDir em vez de PVC pra evitar arquivos AppleDouble (._*)
          # que macOS injeta no path do local-path provisioner do k3d.
          # Trade-off: dados são voláteis (perdidos no restart do pod),
          # mas seed + migrations + import-realm são reprodutíveis via
          # make targets. Para lab é uma troca aceitável.
          emptyDir:
            sizeLimit: 2Gi
        - name: init
          configMap:
            name: postgres-init
            defaultMode: 0755
EOF

echo "⏳ Aguardando postgres ficar pronto..."
kubectl rollout status -n "$NS" deploy/postgres --timeout=180s
echo "✅ Postgres pronto em $NS"
