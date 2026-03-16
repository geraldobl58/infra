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
kubectl get pods -n nexo-local               # Namespace específico
kubectl get pods -o wide                     # Mais informações
kubectl get pods --watch                     # Watch mode

# Describe pod
kubectl describe pod <pod-name> -n nexo-local

# Logs
kubectl logs <pod-name> -n nexo-local                    # Últimos logs
kubectl logs <pod-name> -n nexo-local --follow           # Follow logs
kubectl logs <pod-name> -n nexo-local --previous         # Pod anterior
kubectl logs <pod-name> -n nexo-local --tail=100         # Últimas 100 linhas
kubectl logs -l app=nexo-be -n nexo-local --follow       # Por label

# Shell no pod
kubectl exec -it <pod-name> -n nexo-local -- /bin/sh
kubectl exec -it <pod-name> -n nexo-local -- bash

# Copiar arquivos
kubectl cp <pod>:/path/to/file ./local-file -n nexo-local
kubectl cp ./local-file <pod>:/path/to/file -n nexo-local

# Delete pod
kubectl delete pod <pod-name> -n nexo-local
kubectl delete pods --all -n nexo-local
```

### Deployments

```bash
# Listar deployments
kubectl get deployments -n nexo-local

# Describe
kubectl describe deployment nexo-be -n nexo-local

# Scale
kubectl scale deployment nexo-be --replicas=3 -n nexo-local

# Restart
kubectl rollout restart deployment nexo-be -n nexo-local

# Status do rollout
kubectl rollout status deployment nexo-be -n nexo-local

# Histórico
kubectl rollout history deployment nexo-be -n nexo-local

# Rollback
kubectl rollout undo deployment nexo-be -n nexo-local
kubectl rollout undo deployment nexo-be --to-revision=2 -n nexo-local

# Edit deployment
kubectl edit deployment nexo-be -n nexo-local
```

### Services

```bash
# Listar services
kubectl get svc -A
kubectl get svc -n nexo-local

# Describe
kubectl describe svc nexo-be -n nexo-local

# Endpoints
kubectl get endpoints -n nexo-local
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
kubens nexo-local
```

### Context

```bash
# Ver contextos
kubectl config get-contexts

# Trocar contexto
kubectl config use-context k3d-nexo-local

# Context atual
kubectl config current-context

# Com kubectx
kubectx                      # Listar
kubectx k3d-nexo-local      # Trocar
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
k3d cluster stop nexo-local

# Iniciar cluster
k3d cluster start nexo-local

# Deletar cluster
k3d cluster delete nexo-local

# Ver nodes
k3d node list

# Importar imagem
k3d image import myimage:latest -c nexo-local
```

## 🎨 ArgoCD

```bash
# Login
argocd login argocd.nexo.local --username admin --insecure

# Listar apps
argocd app list

# Get app
argocd app get nexo-be-local

# Sync app
argocd app sync nexo-be-local
argocd app sync nexo-be-local --prune --force

# Ver diff
argocd app diff nexo-be-local

# Histórico
argocd app history nexo-be-local

# Rollback
argocd app rollback nexo-be-local 2

# Ver logs
argocd app logs nexo-be-local --follow

# Recursos
argocd app resources nexo-be-local

# Delete app
argocd app delete nexo-be-local

# Projects
argocd proj list
argocd proj get nexo-local

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
rate(container_cpu_usage_seconds_total{namespace="nexo-local"}[5m]) * 100

# CPU requests vs usage
sum(rate(container_cpu_usage_seconds_total{namespace="nexo-local"}[5m])) by (pod) /
sum(kube_pod_container_resource_requests{resource="cpu", namespace="nexo-local"}) by (pod)
```

### Memory

```promql
# Memory usage
container_memory_working_set_bytes{namespace="nexo-local"} / 1024 / 1024

# Memory utilization
container_memory_working_set_bytes{namespace="nexo-local"} /
container_spec_memory_limit_bytes{namespace="nexo-local"}
```

### Network

```promql
# Network RX
rate(container_network_receive_bytes_total{namespace="nexo-local"}[5m])

# Network TX
rate(container_network_transmit_bytes_total{namespace="nexo-local"}[5m])
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
curl -X GET "localhost:9200/filebeat-*/_search?pretty&q=kubernetes.namespace:nexo-local"

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
kubectl top pods -n nexo-local

# Top pods (ordenar)
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Resource usage
kubectl describe node | grep -A 5 "Allocated resources"

# Watch resources
watch -n 2 kubectl top pods -n nexo-local
```

## 🐛 Debug

### Events

```bash
# Ver eventos
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get events -n nexo-local --sort-by='.lastTimestamp'
kubectl get events --field-selector type=Warning -A
```

### Troubleshoot Pod

```bash
# Por que o pod não está rodando?
kubectl describe pod <pod> -n nexo-local

# Ver logs anteriores
kubectl logs <pod> -n nexo-local --previous

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
kubectl port-forward -n nexo-local svc/nexo-be 3000:3000

# Pod
kubectl port-forward -n nexo-local pod/nexo-be-xxx 3000:3000

# Deployment
kubectl port-forward -n nexo-local deployment/nexo-be 3000:3000

# Background
kubectl port-forward -n nexo-local svc/nexo-be 3000:3000 &

# Múltiplas portas
kubectl port-forward -n nexo-local svc/nexo-be 3000:3000 9090:9090
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
kubectl delete pod <pod> -n nexo-local --force --grace-period=0

# Limpar finalizers (se pod travou)
kubectl patch pod <pod> -n nexo-local -p '{"metadata":{"finalizers":[]}}' --type=merge
```

## 🔐 Secrets

```bash
# Criar secret
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n nexo-local

# From file
kubectl create secret generic my-secret \
  --from-file=ssh-privatekey=~/.ssh/id_rsa \
  -n nexo-local

# Ver secrets
kubectl get secrets -n nexo-local

# Decode secret
kubectl get secret my-secret -n nexo-local -o jsonpath='{.data.password}' | base64 -d

# Edit secret
kubectl edit secret my-secret -n nexo-local
```

## 📝 ConfigMaps

```bash
# Criar configmap
kubectl create configmap my-config \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  -n nexo-local

# From file
kubectl create configmap my-config \
  --from-file=config.json \
  -n nexo-local

# Ver configmaps
kubectl get configmaps -n nexo-local

# Ver conteúdo
kubectl get configmap my-config -n nexo-local -o yaml

# Edit
kubectl edit configmap my-config -n nexo-local
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
make logs SERVICE=nexo-be NAMESPACE=nexo-local

# Port-forward
make port-forward SERVICE=nexo-be PORT=3000

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
kubectl get pods -n nexo-local -o name | xargs kubectl delete -n nexo-local

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
