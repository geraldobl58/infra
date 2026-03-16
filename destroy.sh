#!/bin/bash

# Nexo CloudLab Ninja - Destruir Ambiente
# ========================================
# Remove completamente o CloudLab Ninja local:
# - Deleta cluster k3d
# - Remove entradas do /etc/hosts
# - Limpa contexto do kubeconfig

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
║   🥷 Destroy CloudLab Ninja                              ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF

echo ""
echo -e "${RED}⚠️  AVISO: Esta ação irá destruir completamente o CloudLab!${NC}"
echo ""
echo -e "${YELLOW}Será removido:${NC}"
echo "  • Cluster Kubernetes (k3d)"
echo "  • Todos os pods e deployments"
echo "  • Dados do Prometheus e Grafana"
echo "  • ArgoCD e todas as aplicações"
echo "  • Entradas do /etc/hosts"
echo "  • Contexto do kubeconfig"
echo ""
echo -e "${CYAN}O que NÃO será removido:${NC}"
echo "  • Código fonte deste repositório"
echo "  • Configurações do Helm (charts)"
echo "  • Imagens Docker em cache"
echo ""
read -p "Tem certeza que deseja continuar? (yes/N): " -r
echo

if [[ ! $REPLY =~ ^(yes|YES)$ ]]; then
    echo -e "${GREEN}✓ Operação cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║           INICIANDO DESTRUIÇÃO DO CLOUDLAB               ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ==============================================================================
# Verificar se cluster existe
# ==============================================================================
if ! k3d cluster list 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    echo -e "${YELLOW}⚠️  Cluster '$CLUSTER_NAME' não encontrado${NC}"
    echo -e "${BLUE}ℹ️  Continuando com limpeza de configurações...${NC}"
else
    # Mostrar resumo antes de deletar
    echo -e "${CYAN}📊 Resumo do que será deletado:${NC}"
    echo ""
    
    echo -e "${BLUE}Namespaces:${NC}"
    kubectl get namespaces --no-headers 2>/dev/null | grep -E "nexo-|argocd|monitoring" | awk '{print "  • " $1}' || echo "  (nenhum encontrado)"
    echo ""
    
    echo -e "${BLUE}Applications ArgoCD:${NC}"
    APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [ "$APP_COUNT" -gt "0" ]; then
        echo "  • Total: $APP_COUNT aplicações"
    else
        echo "  (nenhuma encontrada)"
    fi
    echo ""
    
    echo -e "${BLUE}Pods Total:${NC}"
    POD_COUNT=$(kubectl get pods --all-namespaces --no-headers 2>/dev/null | wc -l | tr -d ' ')
    echo "  • Total: $POD_COUNT pods"
    echo ""
    
    # Deletar cluster
    echo -e "${RED}🗑️  Deletando cluster k3d...${NC}"
    k3d cluster delete "$CLUSTER_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Cluster deletado com sucesso${NC}"
    else
        echo -e "${RED}✗ Erro ao deletar cluster${NC}"
    fi
fi

echo ""

# ==============================================================================
# Limpar /etc/hosts
# ==============================================================================
echo -e "${YELLOW}🧹 Limpando /etc/hosts...${NC}"

# Contar entradas antes
ENTRIES_BEFORE=$(grep -c "nexo.local" /etc/hosts 2>/dev/null || echo "0")

if [ "$ENTRIES_BEFORE" -gt "0" ]; then
    echo -e "${BLUE}  Removendo $ENTRIES_BEFORE entradas do /etc/hosts...${NC}"
    
    # Remover entradas do Nexo CloudLab
    sudo sed -i '' '/# Nexo CloudLab/d' /etc/hosts 2>/dev/null || true
    sudo sed -i '' '/nexo\.local/d' /etc/hosts 2>/dev/null || true
    
    ENTRIES_AFTER=$(grep -c "nexo.local" /etc/hosts 2>/dev/null || echo "0")
    
    if [ "$ENTRIES_AFTER" -eq "0" ]; then
        echo -e "${GREEN}✓ Entradas removidas do /etc/hosts${NC}"
    else
        echo -e "${YELLOW}⚠️  Algumas entradas podem não ter sido removidas${NC}"
    fi
else
    echo -e "${BLUE}  Nenhuma entrada encontrada no /etc/hosts${NC}"
fi

echo ""

# ==============================================================================
# Limpar kubeconfig
# ==============================================================================
echo -e "${YELLOW}🧹 Limpando contexto do kubeconfig...${NC}"

# Verificar se contexto existe
if kubectl config get-contexts 2>/dev/null | grep -q "k3d-$CLUSTER_NAME"; then
    kubectl config delete-context "k3d-$CLUSTER_NAME" 2>/dev/null || true
    echo -e "${GREEN}✓ Contexto removido do kubeconfig${NC}"
else
    echo -e "${BLUE}  Nenhum contexto encontrado${NC}"
fi

echo ""

# ==============================================================================
# Opcional: Limpar volumes (pergunta antes)
# ==============================================================================
if [ -d "/Volumes/Backup/nexo-cloudlab" ]; then
    echo -e "${YELLOW}📦 Volumes persistentes encontrados em: /Volumes/Backup/nexo-cloudlab${NC}"
    read -p "Deseja remover os volumes também? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🗑️  Removendo volumes...${NC}"
        sudo rm -rf /Volumes/Backup/nexo-cloudlab
        echo -e "${GREEN}✓ Volumes removidos${NC}"
    else
        echo -e "${BLUE}ℹ️  Volumes mantidos (podem ser reutilizados no próximo setup)${NC}"
    fi
fi

echo ""

# ==============================================================================
# Finalização
# ==============================================================================
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}║          ✨  CLOUDLAB DESTRUÍDO COM SUCESSO!  ✨         ║${NC}"
echo -e "${GREEN}║                                                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}📋 RESUMO DA LIMPEZA:${NC}"
echo -e "  ${GREEN}✓${NC} Cluster k3d removido"
echo -e "  ${GREEN}✓${NC} Entradas do /etc/hosts limpas"
echo -e "  ${GREEN}✓${NC} Contexto do kubeconfig removido"
echo ""
echo -e "${CYAN}🔄 Para recriar o ambiente:${NC}"
echo -e "  ${GREEN}make setup${NC}"
echo ""
echo -e "${BLUE}💡 Dica: O código fonte e configurações foram preservados${NC}"
echo ""
