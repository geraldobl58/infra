#!/bin/bash
set -e

# Nexo CloudLab Ninja - Setup Unificado
# ======================================
# Este script configura todo o ambiente local do CloudLab Ninja:
# 1. Cria cluster k3d (7 nodes)
# 2. Instala ArgoCD para GitOps
# 3. Instala Prometheus + Grafana
# 4. Configura namespaces e aplicações
# 5. Configura hosts locais

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CLUSTER_NAME="nexo-local"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║    _   _                    ____ _                 _ _    ║
║   | \ | | _____  _____    / ___| | ___  _   _  __| | |   ║
║   |  \| |/ _ \ \/ / _ \  | |   | |/ _ \| | | |/ _` | |   ║
║   | |\  |  __/>  < (_) | | |___| | (_) | |_| | (_| | |__ ║
║   |_| \_|\___/_/\_\___/   \____|_|\___/ \__,_|\__,_|____|║
║                                                           ║
║   🥷 CloudLab Ninja - Kubernetes Local                    ║
║   4 Ambientes: develop → qa → staging → prod             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""
echo -e "${CYAN}Este script irá configurar:${NC}"
echo "  • Cluster Kubernetes (k3d) com 7 nodes"
echo "  • NGINX Ingress Controller"
echo "  • ArgoCD para GitOps automático"
echo "  • Prometheus + Grafana para observabilidade"
echo "  • 4 namespaces: develop, qa, staging, prod"
echo "  • 12 aplicações (3 serviços × 4 ambientes)"
echo "  • DNS local (16 domínios .nexo.local)"
echo ""
echo -e "${YELLOW}Tempo estimado: 10-15 minutos${NC}"
echo ""
read -p "Iniciar setup? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Setup cancelado.${NC}"
    exit 0
fi

# Função para log
log_step() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

log_substep() {
    echo -e "${CYAN}▸ $1${NC}"
}

# ==============================================================================
# ETAPA 1: Verificar e criar cluster k3d
# ==============================================================================
log_step "ETAPA 1/7: Criando Cluster Kubernetes"

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo -e "${YELLOW}⚠️  Cluster '$CLUSTER_NAME' já existe!${NC}"
    log_substep "Cluster já configurado, prosseguindo..."
else
    log_substep "Preparando volumes no SSD..."
    mkdir -p /Volumes/Backup/nexo-cloudlab/{data,postgres,prometheus,grafana}
    
    log_substep "Criando cluster k3d (1 server + 6 agents)..."
    k3d cluster create --config="$SCRIPT_DIR/config/k3d-config.yaml"
    
    sleep 10
    log_substep "Verificando nodes..."
    kubectl get nodes -o wide
fi

# ==============================================================================
# ETAPA 1.5: Instalar NGINX Ingress Controller
# ==============================================================================
log_step "ETAPA 1.5/7: Instalando NGINX Ingress Controller"

log_substep "Adicionando repositório NGINX Ingress..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update

log_substep "Instalando NGINX Ingress Controller via Helm..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace kube-system \
  --set controller.publishService.enabled=true \
  --set controller.service.type=LoadBalancer \
  --set controller.watchIngressWithoutClass=true \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --set 'controller.nodeSelector.kubernetes\.io/os=linux' \
  --timeout 5m \
  --wait

log_substep "Aguardando NGINX Ingress ficar pronto..."
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/name=ingress-nginx \
  --namespace=kube-system \
  --timeout=120s 2>/dev/null || echo "NGINX Ingress ainda inicializando..."

echo -e "${GREEN}✓ NGINX Ingress Controller instalado${NC}"

# ==============================================================================
# ETAPA 2: Criar namespaces
# ==============================================================================
log_step "ETAPA 2/7: Criando Namespaces"

log_substep "Criando namespaces de ambientes..."
kubectl create namespace nexo-develop --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace nexo-qa --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace nexo-staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace nexo-prod --dry-run=client -o yaml | kubectl apply -f -

log_substep "Criando namespaces de infra..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl get namespaces

# ==============================================================================
# ETAPA 3: Instalar ArgoCD
# ==============================================================================
log_step "ETAPA 3/7: Instalando ArgoCD"

log_substep "Adicionando repositório Helm..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

log_substep "Instalando ArgoCD via Helm..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.extraArgs[0]="--insecure" \
  --set configs.params."server\.insecure"=true \
  --set server.service.type=ClusterIP \
  --set controller.metrics.enabled=true \
  --set server.metrics.enabled=true \
  --set repoServer.metrics.enabled=true \
  --timeout 10m \
  --wait

log_substep "Aguardando ArgoCD ficar pronto..."
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/name=argocd-server \
  --namespace=argocd \
  --timeout=300s 2>/dev/null || echo "ArgoCD ainda inicializando..."

log_substep "Configurando Ingress para ArgoCD..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
spec:
  ingressClassName: nginx
  rules:
  - host: argocd.nexo.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF

log_substep "Obtendo senha inicial do ArgoCD..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "não-disponível")
echo -e "${GREEN}✓ ArgoCD instalado - Usuário: admin / Senha: $ARGOCD_PASSWORD${NC}"

# ==============================================================================
# ETAPA 4: Instalar Observabilidade (Prometheus + Grafana)
# ==============================================================================
log_step "ETAPA 4/7: Instalando Stack de Observabilidade"

log_substep "Adicionando repositório Prometheus Community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo update

log_substep "Instalando kube-prometheus-stack..."
cat <<EOF > /tmp/prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 7d
    resources:
      requests:
        cpu: 200m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi
    serviceMonitorSelectorNilUsesHelmValues: false
  
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - prometheus.nexo.local
    paths:
      - /

grafana:
  adminPassword: "nexo@local2026"
  persistence:
    enabled: false
  
  sidecar:
    dashboards:
      enabled: true
      folderAnnotation: grafana_folder
      provider:
        foldersFromFilesStructure: true
        allowUiUpdates: true
  
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - grafana.nexo.local
    path: /

alertmanager:
  enabled: true
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - alertmanager.nexo.local
    paths:
      - /
EOF

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values /tmp/prometheus-values.yaml \
  --timeout 10m \
  --wait

log_substep "Aguardando pods de observabilidade..."
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/name=grafana \
  --namespace=monitoring \
  --timeout=300s 2>/dev/null || echo "Grafana ainda inicializando..."

echo -e "${GREEN}✓ Grafana instalado - Usuário: admin / Senha: nexo@local2026${NC}"

log_substep "Aplicando dashboards customizados do Grafana..."
kubectl apply -f "$SCRIPT_DIR/k8s/grafana-dashboard-nexo.yaml"
kubectl apply -f "$SCRIPT_DIR/k8s/grafana-dashboard-apps.yaml"
echo -e "${GREEN}✓ Dashboards customizados aplicados${NC}"

log_substep "Aplicando ServiceMonitors para métricas das aplicações..."
kubectl apply -f "$SCRIPT_DIR/k8s/servicemonitor-apps.yaml"
echo -e "${GREEN}✓ ServiceMonitors aplicados (nexo-be, nexo-fe, nexo-auth)${NC}"

# ==============================================================================
# ETAPA 5: Configurar ArgoCD Applications
# ==============================================================================
log_step "ETAPA 5/7: Configurando ArgoCD GitOps"

log_substep "Aplicando ArgoCD Projects..."
kubectl apply -f "$SCRIPT_DIR/argocd/projects/nexo-environments.yaml"

log_substep "Aplicando ApplicationSets..."
kubectl apply -f "$SCRIPT_DIR/argocd/applicationsets/nexo-apps.yaml"

log_substep "Aguardando ApplicationSets criar aplicações..."
sleep 5

echo -e "${GREEN}✓ 12 aplicações configuradas (3 serviços × 4 ambientes)${NC}"

# ==============================================================================
# ETAPA 6: Configurar /etc/hosts
# ==============================================================================
log_step "ETAPA 6/7: Configurando DNS Local (/etc/hosts)"

HOSTS_ENTRIES="
# Nexo CloudLab - Ferramentas
127.0.0.1 argocd.nexo.local
127.0.0.1 grafana.nexo.local
127.0.0.1 prometheus.nexo.local
127.0.0.1 alertmanager.nexo.local

# Nexo CloudLab - Apps Develop
127.0.0.1 develop-be.nexo.local
127.0.0.1 develop-fe.nexo.local
127.0.0.1 develop-auth.nexo.local

# Nexo CloudLab - Apps QA
127.0.0.1 qa-be.nexo.local
127.0.0.1 qa-fe.nexo.local
127.0.0.1 qa-auth.nexo.local

# Nexo CloudLab - Apps Staging
127.0.0.1 staging-be.nexo.local
127.0.0.1 staging-fe.nexo.local
127.0.0.1 staging-auth.nexo.local

# Nexo CloudLab - Apps Prod
127.0.0.1 be.nexo.local
127.0.0.1 fe.nexo.local
127.0.0.1 auth.nexo.local
"

# Remover entradas antigas do Nexo CloudLab
sudo sed -i '' '/# Nexo CloudLab/d' /etc/hosts 2>/dev/null || true
sudo sed -i '' '/nexo\.local/d' /etc/hosts 2>/dev/null || true

# Adicionar novas entradas
echo "$HOSTS_ENTRIES" | sudo tee -a /etc/hosts > /dev/null

# Flush DNS cache (macOS trata .local como mDNS/Bonjour, precisa limpar cache)
log_substep "Limpando cache DNS do macOS..."
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

log_substep "/etc/hosts configurado com 16 domínios + cache DNS limpo"

# ==============================================================================
# ETAPA 7: Verificação Final
# ==============================================================================
log_step "ETAPA 7/7: Verificação Final"

log_substep "Verificando NGINX Ingress Controller..."
kubectl wait --for=condition=ready pod \
  --selector=app.kubernetes.io/name=ingress-nginx \
  --namespace=kube-system \
  --timeout=60s 2>/dev/null || echo "NGINX Ingress ainda inicializando..."

log_substep "Verificando conectividade dos serviços..."
sleep 5

# Usar --resolve para evitar problemas com mDNS do macOS no .local
SERVICES_OK=0
SERVICES_TOTAL=6

for CHECK in "argocd.nexo.local ArgoCD" "grafana.nexo.local Grafana" "prometheus.nexo.local Prometheus" "alertmanager.nexo.local AlertManager" "develop-fe.nexo.local Frontend" "develop-auth.nexo.local Auth"; do
    HOST=$(echo $CHECK | cut -d' ' -f1)
    NAME=$(echo $CHECK | cut -d' ' -f2)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 --resolve "${HOST}:80:127.0.0.1" "http://${HOST}" 2>/dev/null)
    if [[ "$HTTP_CODE" =~ ^(200|301|302|303|307|404)$ ]]; then
        echo -e "${GREEN}✓ ${NAME} acessível (HTTP ${HTTP_CODE})${NC}"
        SERVICES_OK=$((SERVICES_OK + 1))
    else
        echo -e "${YELLOW}⚠️  ${NAME} ainda inicializando (HTTP ${HTTP_CODE})${NC}"
    fi
done

echo -e "\n${GREEN}${SERVICES_OK}/${SERVICES_TOTAL} serviços respondendo${NC}"

# ==============================================================================
# FINALIZAÇÃO
# ==============================================================================
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║              ✨  SETUP CONCLUÍDO COM SUCESSO!  ✨         ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔧 FERRAMENTAS INSTALADAS:${NC}"
echo ""
echo -e "  🎯 ${YELLOW}ArgoCD${NC}         → http://argocd.nexo.local"
echo -e "     Usuário: admin | Senha: $ARGOCD_PASSWORD"
echo ""
echo -e "  📊 ${YELLOW}Grafana${NC}        → http://grafana.nexo.local"
echo -e "     Usuário: admin | Senha: nexo@local2026"
echo -e "     Dashboards: Kubernetes Cluster, Pods, Node Exporter, NGINX Ingress"
echo -e "     + Nexo Overview, Nexo Applications Performance"
echo ""
echo -e "  🔍 ${YELLOW}Prometheus${NC}     → http://prometheus.nexo.local"
echo -e "  🚨 ${YELLOW}AlertManager${NC}   → http://alertmanager.nexo.local"
echo ""
echo -e "${CYAN}🚀 APLICAÇÕES (12 total):${NC}"
echo ""
echo -e "  ${BLUE}[DEVELOP]${NC}"
echo -e "    • Backend:  http://develop-be.nexo.local"
echo -e "    • Frontend: http://develop-fe.nexo.local"
echo -e "    • Auth:     http://develop-auth.nexo.local"
echo ""
echo -e "  ${BLUE}[QA]${NC}"
echo -e "    • Backend:  http://qa-be.nexo.local"
echo -e "    • Frontend: http://qa-fe.nexo.local"
echo -e "    • Auth:     http://qa-auth.nexo.local"
echo ""
echo -e "  ${BLUE}[STAGING]${NC}"
echo -e "    • Backend:  http://staging-be.nexo.local"
echo -e "    • Frontend: http://staging-fe.nexo.local"
echo -e "    • Auth:     http://staging-auth.nexo.local"
echo ""
echo -e "  ${BLUE}[PROD]${NC}"
echo -e "    • Backend:  http://be.nexo.local"
echo -e "    • Frontend: http://fe.nexo.local"
echo -e "    • Auth:     http://auth.nexo.local"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo -e "   As aplicações podem estar com status 'Degraded' até você configurar o GitHub token:"
echo -e ""
echo -e "   ${GREEN}Opção 1 (Recomendado):${NC} Configurar no .env"
echo -e "   1. Editar arquivo .env na raiz do projeto"
echo -e "   2. Adicionar seu token: GITHUB_TOKEN=ghp_xxxxx"
echo -e "   3. Executar: bash local/create-ghcr-secrets.sh"
echo -e ""
echo -e "   ${GREEN}Opção 2:${NC} Passar token diretamente"
echo -e "   bash local/create-ghcr-secrets.sh <TOKEN>"
echo -e ""
echo -e "   ${GREEN}Opção 3:${NC} Tornar packages públicos no GitHub"
echo -e "   https://github.com/geraldobl58?tab=packages"
echo ""
echo -e "${CYAN}📚 PRÓXIMOS PASSOS:${NC}"
echo -e "   • Verificar status:  ${GREEN}make status${NC}"
echo -e "   • Explorar cluster:  ${GREEN}k9s${NC}"
echo -e "   • Ver logs:          ${GREEN}kubectl logs -f <pod> -n <namespace>${NC}"
echo -e "   • Destruir tudo:     ${GREEN}make destroy${NC}"
echo ""
echo -e "${GREEN}🎉 Você tem um CloudLab profissional rodando localmente!${NC}"
echo ""
