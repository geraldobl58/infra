#!/bin/bash
set -e

echo "🚀 Nexo CloudLab - Criando Cluster Kubernetes"
echo "=============================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLUSTER_NAME="nexo-local"

# Verificar se cluster já existe
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo -e "${YELLOW}⚠️  Cluster $CLUSTER_NAME já existe!${NC}"
    read -p "Deseja deletar e recriar? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Deletando cluster existente...${NC}"
        k3d cluster delete $CLUSTER_NAME
    else
        echo -e "${BLUE}ℹ️  Usando cluster existente${NC}"
        exit 0
    fi
fi

# Criar diretórios no SSD se não existirem
echo -e "${YELLOW}📁 Preparando volumes no SSD...${NC}"
mkdir -p /Volumes/Backup/nexo-cloudlab/{data,postgres,prometheus,grafana,elasticsearch}

# Criar cluster
echo -e "${YELLOW}🎯 Criando cluster Kubernetes...${NC}"
k3d cluster create --config="$(pwd)/config/k3d-config.yaml"

# Aguardar cluster ficar pronto
echo -e "${YELLOW}⏳ Aguardando cluster ficar pronto...${NC}"
sleep 10

# Verificar nodes
echo -e "${BLUE}📊 Status dos nodes:${NC}"
kubectl get nodes -o wide

# Criar namespaces
echo -e "${YELLOW}🏗️  Criando namespaces...${NC}"
kubectl create namespace nexo-develop || true
kubectl create namespace nexo-qa || true
kubectl create namespace nexo-staging || true
kubectl create namespace nexo-prod || true
kubectl create namespace monitoring || true
kubectl create namespace argocd || true

# Aplicar StorageClass
echo -e "${YELLOW}💾 Configurando StorageClass...${NC}"
kubectl apply -f config/storage-class.yaml

# Instalar Ingress NGINX
echo -e "${YELLOW}🌐 Instalando NGINX Ingress Controller...${NC}"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.watchIngressWithoutClass=true \
  --set controller.ingressClassResource.default=true \
  --wait

# Aguardar Ingress ficar pronto
echo -e "${YELLOW}⏳ Aguardando Ingress Controller...${NC}"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# Configurar /etc/hosts
echo -e "${YELLOW}🔧 Configurando DNS local...${NC}"
echo -e "${BLUE}Adicionando entradas ao /etc/hosts...${NC}"
echo -e "${YELLOW}(Requer sudo)${NC}"
echo ""

# Entradas de hosts para o CloudLab
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

echo -e "${GREEN}✅ DNS local configurado${NC}"

# Verificar tudo
echo ""
echo -e "${GREEN}✅ Cluster criado com sucesso!${NC}"
echo ""
echo -e "${BLUE}📊 Informações do Cluster:${NC}"
echo "  Cluster: $CLUSTER_NAME"
echo "  Context: k3d-$CLUSTER_NAME"
echo "  Nodes: $(kubectl get nodes --no-headers | wc -l)"
echo "  Namespaces: nexo-develop, nexo-qa, nexo-staging, nexo-prod, monitoring, argocd"
echo ""
echo -e "${BLUE}📦 Comandos úteis:${NC}"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  k9s"
echo ""
echo "Próximo passo: ./scripts/02-install-argocd.sh"
