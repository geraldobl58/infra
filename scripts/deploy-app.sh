#!/bin/bash
set -e

# DevOps Lab Ninja - App Deploy Helper
# =====================================
# Este script ajuda a subir novas aplicações no cluster local.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$#" -lt 2 ]; then
    echo -e "${YELLOW}Uso: $0 <nome-do-app> <diretorio-do-helm-chart> [namespace]${NC}"
    echo -e "Exemplo: $0 meu-app ./helm/meu-app devops-develop"
    exit 1
fi

APP_NAME=$1
HELM_PATH=$2
NAMESPACE=${3:-devops-develop}

echo -e "${BLUE}🚀 Fazendo deploy de $APP_NAME em $NAMESPACE...${NC}"

# 1. Criar aplicação no ArgoCD
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${APP_NAME}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/geraldobl58/devops.git # Ajuste para seu repo se necessário
    targetRevision: HEAD
    path: ${HELM_PATH}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${NAMESPACE}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

echo -e "${GREEN}✅ Aplicação '$APP_NAME' criada no ArgoCD!${NC}"
echo ""
echo -e "${YELLOW}ℹ️  Não esqueça de mapear o host no seu /etc/hosts:${NC}"
echo -e "   127.0.0.1 ${APP_NAME}.devops.local"
echo ""
echo -e "${BLUE}🔗 Acompanhe em: http://argocd.devops.local/applications/${APP_NAME}${NC}"
