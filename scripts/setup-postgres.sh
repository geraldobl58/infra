#!/usr/bin/env bash
# =============================================================================
# setup-postgres.sh
# -----------------------------------------------------------------------------
# Cria PostgreSQL no namespace crivo-<env>:
#   - ConfigMap postgres-init (cria bancos crivo_keycloak + crivo_better_auth)
#   - PersistentVolumeClaim postgres-pvc (5Gi via local-path)
#   - Service postgres (ClusterIP, 5432)
#   - Deployment postgres com initContainer pra limpar AppleDouble metadata
#     do macOS (evita CrashLoop após restart do k3d).
#
# Uso:
#   ./scripts/setup-postgres.sh <develop|prod> [--reset]
#
# --reset: apaga PVC primeiro (perde dados).
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
  echo "🗑️  Reset solicitado, apagando deployment e PVC..."
  kubectl delete deploy postgres -n "$NS" --ignore-not-found --wait=true
  kubectl delete pvc postgres-pvc -n "$NS" --ignore-not-found --wait=true
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

# PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: ${NS}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
EOF

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
      initContainers:
        - name: cleanup-macos-metadata
          image: alpine:3
          command:
            - sh
            - -c
            - |
              if [ -d /var/lib/postgresql/data ]; then
                find /var/lib/postgresql/data -name '._*' -delete 2>/dev/null || true
                find /var/lib/postgresql/data -name '.DS_Store' -delete 2>/dev/null || true
              fi
              echo "cleanup done"
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
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
          persistentVolumeClaim:
            claimName: postgres-pvc
        - name: init
          configMap:
            name: postgres-init
            defaultMode: 0755
EOF

echo "⏳ Aguardando postgres ficar pronto..."
kubectl rollout status -n "$NS" deploy/postgres --timeout=180s
echo "✅ Postgres pronto em $NS"
