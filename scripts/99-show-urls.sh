#!/bin/bash

echo "🚀 Nexo CloudLab - URLs de Acesso"
echo "=================================="
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}🎯 Ferramentas de Gestão:${NC}"
echo ""
echo -e "  ${BLUE}ArgoCD (GitOps):${NC}"
echo "    URL: http://argocd.nexo.local"
echo "    User: admin"
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
echo "    Pass: $ARGOCD_PASS"
echo ""

echo -e "  ${BLUE}Grafana (Métricas):${NC}"
echo "    URL: http://grafana.nexo.local"
echo "    User: admin"
echo "    Pass: nexo@local2026"
echo ""

echo -e "  ${BLUE}Prometheus (Métricas Raw):${NC}"
echo "    URL: http://prometheus.nexo.local"
echo ""

echo -e "  ${BLUE}AlertManager (Alertas):${NC}"
echo "    URL: http://alertmanager.nexo.local"
echo ""

echo -e "${GREEN}🌐 Aplicações por Ambiente:${NC}"
echo ""
echo -e "  ${BLUE}Develop:${NC}"
echo "    Frontend: http://develop-fe.nexo.local"
echo "    API:      http://develop-be.nexo.local"
echo "    Auth:     http://develop-auth.nexo.local"
echo ""

echo -e "  ${BLUE}QA:${NC}"
echo "    Frontend: http://qa-fe.nexo.local"
echo "    API:      http://qa-be.nexo.local"
echo "    Auth:     http://qa-auth.nexo.local"
echo ""

echo -e "  ${BLUE}Staging:${NC}"
echo "    Frontend: http://staging-fe.nexo.local"
echo "    API:      http://staging-be.nexo.local"
echo "    Auth:     http://staging-auth.nexo.local"
echo ""

echo -e "  ${BLUE}Prod:${NC}"
echo "    Frontend: http://fe.nexo.local"
echo "    API:      http://be.nexo.local"
echo "    Auth:     http://auth.nexo.local"
echo ""

echo -e "${YELLOW}📊 Status do Cluster:${NC}"
echo ""
kubectl get nodes -o wide
echo ""

echo -e "${YELLOW}📦 Pods por Namespace:${NC}"
echo ""
echo "Namespace: argocd"
kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | xargs echo "  Pods:"

echo "Namespace: monitoring"
kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | xargs echo "  Pods:"

# Namespace logging removido (Elasticsearch muito pesado)
# echo "Namespace: logging"
# kubectl get pods -n logging --no-headers 2>/dev/null | wc -l | xargs echo "  Pods:"

for NS in nexo-develop nexo-qa nexo-staging nexo-prod; do
  echo "Namespace: $NS"
  kubectl get pods -n $NS --no-headers 2>/dev/null | wc -l | xargs echo "  Pods:"
done

echo ""
echo -e "${GREEN}✅ CloudLab está rodando!${NC}"
echo ""
echo -e "${BLUE}📝 Comandos úteis:${NC}"
echo "  k9s                           # Interface visual para K8s"
echo "  kubectl get pods -A           # Ver todos os pods"
echo "  kubectl top nodes             # Uso de recursos dos nodes"
echo "  kubectl top pods -A           # Uso de recursos dos pods"
echo "  argocd app list               # Listar apps no ArgoCD"
echo ""
