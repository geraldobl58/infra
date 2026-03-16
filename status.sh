#!/bin/bash

# Nexo CloudLab Ninja - Status do Ambiente
# =========================================
# Verifica o status de todos os componentes do CloudLab Ninja

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="nexo-local"

cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║    _   _                    ____ _                 _ _    ║
║   | \ | | _____  _____    / ___| | ___  _   _  __| | |   ║
║   |  \| |/ _ \ \/ / _ \  | |   | |/ _ \| | | |/ _` | |   ║
║   | |\  |  __/>  < (_) | | |___| | (_) | |_| | (_| | |__ ║
║   |_| \_|\___/_/\_\___/   \____|_|\___/ \__,_|\__,_|____|║
║                                                           ║
║   🥷 CloudLab Ninja - Status Report                      ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""

# ==============================================================================
# Verificar se cluster existe
# ==============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📊 STATUS DO CLUSTER${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo -e "${RED}❌ Cluster '$CLUSTER_NAME' não encontrado!${NC}"
    echo -e "${YELLOW}   Execute: make setup${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓${NC} Cluster: $CLUSTER_NAME ${GREEN}(ativo)${NC}"
echo ""

# Nodes
echo -e "${BLUE}Nodes:${NC}"
kubectl get nodes --no-headers 2>/dev/null | while read line; do
    node=$(echo "$line" | awk '{print $1}')
    status=$(echo "$line" | awk '{print $2}')
    if [ "$status" == "Ready" ]; then
        echo -e "  ${GREEN}✓${NC} $node - $status"
    else
        echo -e "  ${RED}✗${NC} $node - $status"
    fi
done

echo ""

# ==============================================================================
# Verificar namespaces
# ==============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 NAMESPACES${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

for ns in nexo-develop nexo-qa nexo-staging nexo-prod monitoring argocd; do
    if kubectl get namespace "$ns" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $ns"
    else
        echo -e "  ${RED}✗${NC} $ns ${RED}(não encontrado)${NC}"
    fi
done

echo ""

# ==============================================================================
# Verificar ArgoCD
# ==============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}🎯 ARGOCD - GitOps${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if kubectl get deployment argocd-server -n argocd &>/dev/null; then
    echo -e "${GREEN}✓${NC} ArgoCD instalado"
    echo -e "  URL: ${BLUE}http://argocd.nexo.local${NC}"
    
    # Verificar pods
    ARGOCD_READY=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running")
    ARGOCD_TOTAL=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  Pods: $ARGOCD_READY/$ARGOCD_TOTAL running"
    
    # Senha
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "não-disponível")
    echo -e "  Login: ${GREEN}admin${NC} / ${GREEN}$ARGOCD_PASSWORD${NC}"
    
    echo ""
    echo -e "${BLUE}Applications:${NC}"
    kubectl get applications -n argocd 2>/dev/null | tail -n +2 | while read line; do
        app=$(echo "$line" | awk '{print $1}')
        sync=$(echo "$line" | awk '{print $2}')
        health=$(echo "$line" | awk '{print $3}')
        
        if [ "$health" == "Healthy" ]; then
            health_icon="${GREEN}✓${NC}"
        elif [ "$health" == "Degraded" ]; then
            health_icon="${RED}✗${NC}"
        else
            health_icon="${YELLOW}⚠${NC}"
        fi
        
        if [ "$sync" == "Synced" ]; then
            sync_icon="${GREEN}✓${NC}"
        else
            sync_icon="${YELLOW}⟳${NC}"
        fi
        
        echo -e "  $health_icon $app - Health: $health | Sync: $sync"
    done
else
    echo -e "${RED}✗${NC} ArgoCD não instalado"
fi

echo ""

# ==============================================================================
# Verificar Observabilidade
# ==============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📊 OBSERVABILIDADE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Grafana
if kubectl get deployment kube-prometheus-stack-grafana -n monitoring &>/dev/null; then
    echo -e "${GREEN}✓${NC} Grafana"
    echo -e "  URL: ${BLUE}http://grafana.nexo.local${NC}"
    echo -e "  Login: ${GREEN}admin${NC} / ${GREEN}nexo@local2026${NC}"
else
    echo -e "${RED}✗${NC} Grafana não instalado"
fi

echo ""

# Prometheus
if kubectl get deployment kube-prometheus-stack-prometheus -n monitoring &>/dev/null 2>&1 || \
   kubectl get statefulset prometheus-kube-prometheus-stack-prometheus -n monitoring &>/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Prometheus"
    echo -e "  URL: ${BLUE}http://prometheus.nexo.local${NC}"
else
    echo -e "${RED}✗${NC} Prometheus não instalado"
fi

echo ""

# AlertManager
if kubectl get deployment alertmanager-kube-prometheus-stack-alertmanager -n monitoring &>/dev/null 2>&1 || \
   kubectl get statefulset alertmanager-kube-prometheus-stack-alertmanager -n monitoring &>/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} AlertManager"
    echo -e "  URL: ${BLUE}http://alertmanager.nexo.local${NC}"
else
    echo -e "${RED}✗${NC} AlertManager não instalado"
fi

echo ""

# ==============================================================================
# Verificar Aplicações por Namespace
# ==============================================================================
for ENV in develop qa staging prod; do
    NS="nexo-$ENV"
    if [ "$ENV" == "prod" ]; then
        DOMAIN_PREFIX=""
    else
        DOMAIN_PREFIX="$ENV-"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🚀 AMBIENTE: $(echo $ENV | tr '[:lower:]' '[:upper:]')${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    POD_COUNT=$(kubectl get pods -n "$NS" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$POD_COUNT" -eq "0" ]; then
        echo -e "  ${YELLOW}⚠${NC} Nenhum pod encontrado"
        echo -e "  ${BLUE}URLs:${NC}"
        echo -e "    • Backend:  http://${DOMAIN_PREFIX}be.nexo.local"
        echo -e "    • Frontend: http://${DOMAIN_PREFIX}fe.nexo.local"
        echo -e "    • Auth:     http://${DOMAIN_PREFIX}auth.nexo.local"
    else
        echo -e "${BLUE}Pods ($POD_COUNT):${NC}"
        kubectl get pods -n "$NS" --no-headers 2>/dev/null | while read line; do
            pod=$(echo "$line" | awk '{print $1}')
            ready=$(echo "$line" | awk '{print $2}')
            status=$(echo "$line" | awk '{print $3}')
            
            if [ "$status" == "Running" ] && [[ "$ready" =~ ^[1-9].*/.*$ ]]; then
                echo -e "  ${GREEN}✓${NC} $pod - $status ($ready)"
            elif [ "$status" == "Running" ]; then
                echo -e "  ${YELLOW}⚠${NC} $pod - $status ($ready)"
            else
                echo -e "  ${RED}✗${NC} $pod - $status ($ready)"
            fi
        done
        
        echo ""
        echo -e "${BLUE}URLs:${NC}"
        echo -e "  • Backend:  http://${DOMAIN_PREFIX}be.nexo.local"
        echo -e "  • Frontend: http://${DOMAIN_PREFIX}fe.nexo.local"
        echo -e "  • Auth:     http://${DOMAIN_PREFIX}auth.nexo.local"
    fi
    
    echo ""
done

# ==============================================================================
# Resumo Final
# ==============================================================================
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 RESUMO${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TOTAL_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
RUNNING_PODS=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | grep -c "Running" || true)
APPS_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
APPS_HEALTHY=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Healthy" || true)

echo -e "  Pods:         $RUNNING_PODS/$TOTAL_PODS running"
echo -e "  Applications: $APPS_HEALTHY/$APPS_COUNT healthy"
echo ""

# Verificar se há problemas
DEGRADED_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Degraded" || true)
if [ "${DEGRADED_APPS:-0}" -gt "0" ]; then
    echo -e "${YELLOW}⚠️  ATENÇÃO:${NC} $DEGRADED_APPS aplicações degradadas"
    echo -e "   Possível causa: ImagePullBackOff (imagens privadas)"
    echo -e "   Solução: ${GREEN}bash local/create-ghcr-secrets.sh <GITHUB_TOKEN>${NC}"
    echo ""
fi

echo -e "${CYAN}📚 COMANDOS ÚTEIS:${NC}"
echo -e "  • make status   - Atualizar este status"
echo -e "  • k9s           - Explorar cluster interativamente"
echo -e "  • make destroy  - Destruir todo o ambiente"
echo ""
