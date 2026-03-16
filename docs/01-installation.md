# 📦 Instalação e Configuração - Nexo CloudLab

## Visão Geral

Este guia cobre a instalação completa do Nexo CloudLab, um ambiente de desenvolvimento local que simula uma infraestrutura cloud profissional.

## Pré-requisitos

### Hardware

- **CPU**: Mínimo 8 cores (12 cores recomendado para toda infraestrutura)
- **RAM**: Mínimo 16GB (32GB recomendado para rodar 7 nodes + toda stack)
- **Storage**: 100GB+ de espaço livre (recomendado SSD externo)
- **SSD Externo**: Para dados persistentes (fortemente recomendado)

**Docker Desktop Settings:**

- CPUs: 8-12
- Memory: 12-16 GB
- Swap: 4 GB
- Disk: 100 GB

### Software

- **macOS**: 11.0 (Big Sur) ou superior
- **Docker Desktop**: 4.0.0 ou superior
- **Homebrew**: Gerenciador de pacotes para macOS
- **Git**: Para clonar repositórios

## Instalação Rápida

### 1. Verificar Pré-requisitos

```bash
# Verificar Docker
docker --version
docker info

# Verificar Homebrew
brew --version

# Verificar espaço em disco
df -h
```

### 2. Clonar Repositório

```bash
cd ~/Development/fullstack
git clone https://github.com/geraldobl58/nexo.git
cd nexo/local
```

### 3. Instalação Completa (Método Recomendado)

```bash
# Instalar tudo de uma vez
make install
```

Este comando irá:

- ✅ Instalar todas as dependências (k3d, kubectl, helm, k9s, etc)
- ✅ Criar cluster Kubernetes local com 3 nodes
- ✅ Instalar ArgoCD para GitOps
- ✅ Instalar stack de observabilidade (Prometheus + Grafana + AlertManager)
- ✅ Instalar stack de logging (Elasticsearch + Kibana + Filebeat)
- ✅ Configurar volumes persistentes no SSD externo

**Tempo estimado**: 15-20 minutos

### 4. Instalação Manual (Passo a Passo)

Se preferir controle total do processo:

```bash
# 1. Instalar dependências
make install-deps

# 2. Criar cluster Kubernetes
make create-cluster

# 3. Instalar ArgoCD
make install-argocd

# 4. Instalar Observabilidade
make install-observability

# 5. Instalar Logging
make install-logging

# 6. Deploy das aplicações (opcional)
make deploy-apps
```

## Configuração do SSD Externo

### Preparar o SSD

```bash
# Verificar se o SSD está montado
ls -la /Volumes/Backup

# Criar estrutura de diretórios
mkdir -p /Volumes/Backup/nexo-cloudlab/{data,postgres,prometheus,grafana,elasticsearch,backups}

# Definir permissões adequadas
chmod -R 755 /Volumes/Backup/nexo-cloudlab
```

### Configurar SSD com Nome Diferente

Se seu SSD tem um nome diferente de "Backup", edite o arquivo de configuração:

```bash
# Editar config/k3d-config.yaml
nano config/k3d-config.yaml

# Alterar "/Volumes/Backup" para "/Volumes/SEU_SSD"
```

## Configuração de DNS Local

As URLs locais precisam ser adicionadas ao `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

Adicionar:

```
127.0.0.1 argocd.nexo.local
127.0.0.1 grafana.nexo.local
127.0.0.1 prometheus.nexo.local
127.0.0.1 alertmanager.nexo.local
127.0.0.1 develop-be.nexo.local
127.0.0.1 develop-fe.nexo.local
127.0.0.1 develop-auth.nexo.local
```

Ou automaticamente durante a instalação quando solicitado.

## Verificação da Instalação

### Verificar Cluster

```bash
# Listar clusters
k3d cluster list

# Ver nodes
kubectl get nodes

# Status geral
make status
```

### Verificar Pods

```bash
# Ver todos os pods
kubectl get pods -A

# Por namespace
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n logging
```

### Acessar Dashboards

```bash
# Ver todas as URLs
make urls

# Abrir dashboards
make dashboard  # ArgoCD
make grafana    # Grafana
make kibana     # Kibana
make prometheus # Prometheus
```

## Configuração de Recursos

### Ajustar Recursos do Docker Desktop

Para melhor performance:

1. Abrir Docker Desktop
2. Settings → Resources
3. Configurar:
   - CPUs: 4-6 cores
   - Memory: 6-8GB
   - Swap: 2GB
   - Disk: 60GB+

### Ajustar Recursos do Cluster

Editar `config/k3d-config.yaml`:

```yaml
# Adicionar mais agents (workers)
agents: 3 # Padrão: 2

# Aumentar recursos
options:
  k3s:
    extraArgs:
      - arg: --kube-apiserver-arg=max-requests-inflight=400
        nodeFilters:
          - server:*
```

## Troubleshooting de Instalação

### Docker não está rodando

```bash
# Verificar status
docker info

# Se não estiver rodando, iniciar Docker Desktop
open -a Docker
```

### Cluster não cria

```bash
# Ver logs detalhados
k3d cluster create --config config/k3d-config.yaml --verbose

# Limpar e tentar novamente
make clean
make create-cluster
```

### Falta de espaço em disco

```bash
# Limpar imagens Docker antigas
docker system prune -a

# Ver uso de disco
docker system df

# Limpar volumes não usados
docker volume prune
```

### Pods ficam em Pending

```bash
# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'

# Ver detalhes do pod
kubectl describe pod <POD_NAME> -n <NAMESPACE>

# Verificar recursos
kubectl top nodes
```

### Ingress não funciona

```bash
# Verificar Ingress Controller
kubectl get pods -n ingress-nginx

# Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Reinstalar
helm uninstall ingress-nginx -n ingress-nginx
# Reexecutar script 01
```

## Próximos Passos

- [02 - Kubernetes Local (k3d)](./02-kubernetes.md)
- [03 - ArgoCD GitOps](./03-argocd.md)
- [04 - Observabilidade](./04-observability.md)

## Comandos Úteis

```bash
# Status completo
make status

# Ver URLs
make urls

# Reiniciar cluster
make restart

# Parar cluster (mantém dados)
make stop

# Iniciar cluster
make start

# Troubleshooting
make troubleshoot

# Interface visual
k9s
```

## Desinstalação

### Remover Cluster (mantém dados)

```bash
make delete
```

### Remover Tudo (incluindo dados)

```bash
make clean
```

### Desinstalar Ferramentas

```bash
brew uninstall k3d kubectl helm k9s kubectx
```

---

**Próximo**: [02 - Kubernetes Local](./02-kubernetes.md)
