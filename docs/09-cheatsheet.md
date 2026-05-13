# ⚡ Cheat Sheet - Comandos Úteis

## 🎯 Quick Start

```bash
# Instalar tudo
make install

# Ver URLs e credenciais
make urls

# Ver status
make status
```

## 📦 Kubectl Essentials

### Pods

```bash
# Listar pods
kubectl get pods -A                           # Todos namespaces
kubectl get pods -n devops-lab               # Namespace específico
kubectl get pods -o wide                     # Mais informações
kubectl get pods --watch                     # Watch mode

# Describe pod
kubectl describe pod <pod-name> -n devops-lab

# Logs
kubectl logs <pod-name> -n devops-lab                    # Últimos logs
kubectl logs <pod-name> -n devops-lab --follow           # Follow logs
kubectl logs <pod-name> -n devops-lab --previous         # Pod anterior
kubectl logs <pod-name> -n devops-lab --tail=100         # Últimas 100 linhas
kubectl logs -l app=devops-be -n devops-lab --follow       # Por label

# Shell no pod
kubectl exec -it <pod-name> -n devops-lab -- /bin/sh
kubectl exec -it <pod-name> -n devops-lab -- bash

# Copiar arquivos
kubectl cp <pod>:/path/to/file ./local-file -n devops-lab
kubectl cp ./local-file <pod>:/path/to/file -n devops-lab

# Delete pod
kubectl delete pod <pod-name> -n devops-lab
kubectl delete pods --all -n devops-lab
```

### Deployments

```bash
# Listar deployments
kubectl get deployments -n devops-lab

# Describe
kubectl describe deployment devops-be -n devops-lab

# Scale
kubectl scale deployment devops-be --replicas=3 -n devops-lab

# Restart
kubectl rollout restart deployment devops-be -n devops-lab

# Status do rollout
kubectl rollout status deployment devops-be -n devops-lab

# Histórico
kubectl rollout history deployment devops-be -n devops-lab

# Rollback
kubectl rollout undo deployment devops-be -n devops-lab
kubectl rollout undo deployment devops-be --to-revision=2 -n devops-lab

# Edit deployment
kubectl edit deployment devops-be -n devops-lab
```

### Services

```bash
# Listar services
kubectl get svc -A
kubectl get svc -n devops-lab

# Describe
kubectl describe svc devops-be -n devops-lab

# Endpoints
kubectl get endpoints -n devops-lab
```

### Namespaces

```bash
# Listar
kubectl get namespaces

# Criar
kubectl create namespace my-namespace

# Deletar
kubectl delete namespace my-namespace

# Mudar default namespace (com kubens)
kubens devops-lab
```

### Context

```bash
# Ver contextos
kubectl config get-contexts

# Trocar contexto
kubectl config use-context k3d-devops-lab

# Context atual
kubectl config current-context

# Com kubectx
kubectx                      # Listar
kubectx k3d-devops-lab      # Trocar
```

## 🐳 K3d

```bash
# Listar clusters
k3d cluster list

# Criar cluster (custom config)
k3d cluster create --config config/k3d-config.yaml

# Criar cluster (simples)
k3d cluster create mycluster --agents 2

# Parar cluster
k3d cluster stop devops-lab

# Iniciar cluster
k3d cluster start devops-lab

# Deletar cluster
k3d cluster delete devops-lab

# Ver nodes
k3d node list

# Importar imagem
k3d image import myimage:latest -c devops-lab
```

## 🎨 ArgoCD

```bash
# Login
argocd login argocd.devops.local --username admin --insecure

# Listar apps
argocd app list

# Get app
argocd app get devops-be-local

# Sync app
argocd app sync devops-be-local
argocd app sync devops-be-local --prune --force

# Ver diff
argocd app diff devops-be-local

# Histórico
argocd app history devops-be-local

# Rollback
argocd app rollback devops-be-local 2

# Ver logs
argocd app logs devops-be-local --follow

# Recursos
argocd app resources devops-be-local

# Delete app
argocd app delete devops-be-local

# Projects
argocd proj list
argocd proj get devops-lab

# Clusters
argocd cluster list
```

## 📊 Prometheus Queries

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Queries úteis (no browser: localhost:9090)
```

### CPU

```promql
# CPU usage por pod
rate(container_cpu_usage_seconds_total{namespace="devops-lab"}[5m]) * 100

# CPU requests vs usage
sum(rate(container_cpu_usage_seconds_total{namespace="devops-lab"}[5m])) by (pod) /
sum(kube_pod_container_resource_requests{resource="cpu", namespace="devops-lab"}) by (pod)
```

### Memory

```promql
# Memory usage
container_memory_working_set_bytes{namespace="devops-lab"} / 1024 / 1024

# Memory utilization
container_memory_working_set_bytes{namespace="devops-lab"} /
container_spec_memory_limit_bytes{namespace="devops-lab"}
```

### Network

```promql
# Network RX
rate(container_network_receive_bytes_total{namespace="devops-lab"}[5m])

# Network TX
rate(container_network_transmit_bytes_total{namespace="devops-lab"}[5m])
```

### HTTP

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
sum(rate(http_requests_total{status_code=~"5.."}[5m])) /
sum(rate(http_requests_total[5m]))

# Latência P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

<!-- Elasticsearch foi removido (muito pesado para dev local)
## 🔍 Elasticsearch

```bash
# Port-forward
kubectl port-forward -n logging svc/elasticsearch-master 9200:9200

# Health
curl http://localhost:9200/_cluster/health?pretty

# Listar índices
curl http://localhost:9200/_cat/indices?v

# Stats de índice
curl http://localhost:9200/filebeat-*/_stats?pretty

# Buscar
curl -X GET "localhost:9200/filebeat-*/_search?pretty&q=kubernetes.namespace:devops-lab"

# Count
curl -X GET "localhost:9200/filebeat-*/_count?pretty"

# Deletar índice
curl -X DELETE "localhost:9200/filebeat-2026.02.01?pretty"
```
-->

## 🎛️ Helm

```bash
# Listar releases
helm list -A

# Install/upgrade
helm upgrade --install myapp ./chart -n namespace --create-namespace

# Ver valores
helm get values myapp -n namespace

# Ver manifest
helm get manifest myapp -n namespace

# Histórico
helm history myapp -n namespace

# Rollback
helm rollback myapp 1 -n namespace

# Uninstall
helm uninstall myapp -n namespace

# Repo
helm repo add <name> <url>
helm repo update
helm search repo <keyword>
```

## 🔧 Docker

```bash
# Listar imagens
docker images

# Build
docker build -t myimage:tag .

# Tag
docker tag myimage:tag ghcr.io/geraldobl58/myimage:tag

# Push para registry local
docker push ghcr.io/geraldobl58/myimage:tag

# Pull
docker pull ghcr.io/geraldobl58/myimage:tag

# Limpar
docker system prune -a        # Remove tudo não usado
docker volume prune           # Remove volumes não usados
docker image prune -a         # Remove imagens não usadas

# Ver uso
docker system df
```

## 📈 Monitoramento

```bash
# Top nodes
kubectl top nodes

# Top pods (todos)
kubectl top pods -A

# Top pods (namespace)
kubectl top pods -n devops-lab

# Top pods (ordenar)
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Resource usage
kubectl describe node | grep -A 5 "Allocated resources"

# Watch resources
watch -n 2 kubectl top pods -n devops-lab
```

## 🐛 Debug

### Events

```bash
# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get events -n devops-lab --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning -A
```

### Troubleshoot Pod

```bash
# Por que o pod não está rodando?
kubectl describe pod <pod> -n devops-lab

# Ver logs anteriores
kubectl logs <pod> -n devops-lab --previous

# Debug com busybox
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Debug DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Debug network
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Dentro do netshoot:
# curl http://service-name.namespace:port
# ping service-name.namespace
# traceroute service-name.namespace
```

### Port Forward

```bash
# Service
kubectl port-forward -n devops-lab svc/devops-be 3000:3000

# Pod
kubectl port-forward -n devops-lab pod/devops-be-xxx 3000:3000

# Deployment
kubectl port-forward -n devops-lab deployment/devops-be 3000:3000

# Background
kubectl port-forward -n devops-lab svc/devops-be 3000:3000 &

# Múltiplas portas
kubectl port-forward -n devops-lab svc/devops-be 3000:3000 9090:9090
```

## 🗑️ Cleanup

```bash
# Deletar pods failed
kubectl delete pods --field-selector=status.phase=Failed -A

# Deletar pods completed
kubectl delete pods --field-selector=status.phase=Succeeded -A

# Deletar evicted pods
kubectl get pods -A | grep Evicted | awk '{print $2, $1}' | xargs -n2 kubectl delete pod -n

# Force delete pod
kubectl delete pod <pod> -n devops-lab --force --grace-period=0

# Limpar finalizers (se pod travou)
kubectl patch pod <pod> -n devops-lab -p '{"metadata":{"finalizers":[]}}' --type=merge
```

## 🔐 Secrets

```bash
# Criar secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n devops-lab

# From file
kubectl create secret generic my-secret \
  --from-file=ssh-privatekey=~/.ssh/id_rsa \
  -n devops-lab

# Ver secrets
kubectl get secrets -n devops-lab

# Decode secret
kubectl get secret my-secret -n devops-lab -o jsonpath='{.data.password}' | base64 -d

# Edit secret
kubectl edit secret my-secret -n devops-lab
```

## 📝 ConfigMaps

```bash
# Criar configmap
kubectl create configmap my-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  -n devops-lab

# From file
kubectl create configmap my-config \
  --from-file=config.json \
  -n devops-lab

# Ver configmaps
kubectl get configmaps -n devops-lab

# Ver conteúdo
kubectl get configmap my-config -n devops-lab -o yaml

# Edit
kubectl edit configmap my-config -n devops-lab
```

## 🎮 k9s

```bash
# Iniciar
k9s

# Comandos dentro do k9s:
:pods              # Ver pods
:svc               # Ver services
:deploy            # Ver deployments
:ns                # Trocar namespace
:ctx               # Trocar context
:events            # Ver eventos

# Navegação:
/                  # Filtrar
l                  # Logs
d                  # Describe
e                  # Edit
s                  # Shell
y                  # YAML
Ctrl+d             # Delete
Ctrl+k             # Kill (force delete)
?                  # Help
:q                 # Quit
```

## 🚀 Makefile (Custom)

```bash
# Ver comandos disponíveis
make help

# Instalar
make install
make install-deps
make create-cluster
make install-argocd
make install-observability
# make install-logging  # Removido (Elasticsearch muito pesado)

# Gestão
make start
make stop
make restart
make status
make urls

# Deploy
make deploy-apps

# Logs
make logs SERVICE=devops-be NAMESPACE=devops-lab

# Port-forward
make port-forward SERVICE=devops-be PORT=3000

# Dashboards
make dashboard     # ArgoCD
make grafana       # Grafana
# make kibana      # Kibana (Removido)
make prometheus    # Prometheus

# Troubleshoot
make troubleshoot
make top

# Limpeza
make delete        # Deletar cluster
make clean         # Deletar tudo + dados

# Backup
make backup
```

## 📚 Aliases Úteis

Adicione ao `~/.zshrc` ou `~/.bashrc`:

```bash
# Kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgd='kubectl get deployments'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'
alias kdel='kubectl delete'

# Context e Namespace
alias kctx='kubectl config use-context'
alias kns='kubectl config set-context --current --namespace'

# Watch
alias kwatch='watch -n 2 kubectl get pods'

# Logs
alias klf='kubectl logs -f'
alias klp='kubectl logs --previous'

# ArgoCD
alias arcd='argocd'
alias arcda='argocd app'
alias arcdal='argocd app list'
alias arcdas='argocd app sync'

# k3d
alias k3dl='k3d cluster list'
alias k3ds='k3d cluster start'
alias k3dstop='k3d cluster stop'

# Docker
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dprune='docker system prune -a'
```

## 🔥 One-Liners Poderosos

```bash
# Restart de todos os pods
kubectl get pods -n devops-lab -o name | xargs kubectl delete -n devops-lab

# Ver imagens usadas
kubectl get pods -A -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort -u

# Ver nodes e seus pods
kubectl get pods -A -o wide --sort-by=.spec.nodeName

# Ver pods sem resource limits
kubectl get pods -A -o json | jq -r '.items[] | select(.spec.containers[].resources.limits == null) | .metadata.name'

# CPU total dos pods
kubectl top pods -A | awk '{sum+=$2} END {print sum}'

# Memory total dos pods
kubectl top pods -A | awk '{sum+=$3} END {print sum}'

# Ver pod com mais restarts
kubectl get pods -A --sort-by='.status.containerStatuses[0].restartCount'
```

---

**Dica**: Imprima esta página para referência rápida! 📄
