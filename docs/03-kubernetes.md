# 🎯 Kubernetes Local com k3d - DevOps Lab

## O que é k3d?

k3d é uma ferramenta que roda clusters K3s (Kubernetes leve da Rancher) dentro de containers Docker. É perfeito para desenvolvimento local porque:

- ✅ **Leve**: Usa menos recursos que Kubernetes completo
- ✅ **Rápido**: Cluster criado em segundos
- ✅ **Multi-node**: Simula ambientes de produção
- ✅ **Persistente**: Dados salvos em volumes
- ✅ **Versátil**: Suporta LoadBalancer, Ingress, Registry local

## Arquitetura do Cluster

```
┌─────────────────────────────────────────────────────┐
│                  Docker Host (macOS)                │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │   Server     │  │   Agent 0    │  │  Agent 1 │ │
│  │ (Control     │  │   (Worker)   │  │ (Worker) │ │
│  │  Plane)      │  │              │  │          │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│         ↓                 ↓                ↓       │
│  ┌─────────────────────────────────────────────┐  │
│  │        Local Registry (5000)                │  │
│  └─────────────────────────────────────────────┘  │
│         ↓                                          │
│  ┌─────────────────────────────────────────────┐  │
│  │    Persistent Storage (/Volumes/Backup)     │  │
│  └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

## Gestão do Cluster

### Criar Cluster

```bash
# Usando config personalizado
make create-cluster

# Ou manualmente
k3d cluster create --config config/k3d-config.yaml

# Com mais workers
k3d cluster create devops-lab --agents 3 --servers 1
```

### Listar Clusters

```bash
k3d cluster list

# Output:
# NAME         SERVERS   AGENTS   LOADBALANCER
# devops-lab   1/1       2/2      true
```

### Parar/Iniciar Cluster

```bash
# Parar (mantém dados)
make stop
# ou
k3d cluster stop devops-lab

# Iniciar
make start
# ou
k3d cluster start devops-lab

# Reiniciar
make restart
```

### Deletar Cluster

```bash
# Deletar mas mantém dados externos
make delete

# Deletar tudo incluindo dados
make clean
```

## Contexto do Kubectl

```bash
# Ver contextos disponíveis
kubectl config get-contexts

# Trocar de contexto
kubectl config use-context k3d-devops-lab

# Ver contexto atual
kubectl config current-context

# Ferramenta kubectx facilita
kubectx                    # Lista contextos
kubectx k3d-devops-lab    # Troca contexto
```

## Namespaces

### Namespaces Criados

```bash
kubectl get namespaces

# Output:
# NAME              STATUS   AGE
# default           Active   10m
# kube-system       Active   10m
# kube-public       Active   10m
# devops-lab        Active   10m
# argocd            Active   10m
# monitoring        Active   10m
# logging           Active   10m
# ingress-nginx     Active   10m
```

### Trabalhar com Namespaces

```bash
# Ver pods em namespace específico
kubectl get pods -n devops-lab

# Ver todos os pods
kubectl get pods -A

# Mudar namespace padrão (com kubens)
kubens devops-lab

# Ver recursos em todos namespaces
kubectl get all -A
```

## Nodes

### Informações dos Nodes

```bash
# Listar nodes
kubectl get nodes

# Detalhes
kubectl get nodes -o wide

# Describe node
kubectl describe node k3d-devops-lab-server-0

# Recursos dos nodes
kubectl top nodes
```

### Labels nos Nodes

```bash
# Ver labels
kubectl get nodes --show-labels

# Adicionar label
kubectl label node k3d-devops-lab-agent-0 disktype=ssd

# Remover label
kubectl label node k3d-devops-lab-agent-0 disktype-
```

## Storage

### Storage Classes

```bash
# Ver storage classes
kubectl get storageclass

# Output:
# NAME                PROVISIONER             RECLAIMPOLICY
# local-path-ssd      rancher.io/local-path   Retain
# local-path-fast     rancher.io/local-path   Delete
```

### Persistent Volumes

```bash
# Ver PVs
kubectl get pv

# Ver PVCs
kubectl get pvc -A

# Criar PVC exemplo
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path-ssd
  resources:
    requests:
      storage: 1Gi
EOF
```

### Backup de Volumes

```bash
# Volumes estão em:
ls -la /Volumes/Backup/devops-lab/data

# Backup manual
make backup
```

## Networking

### Services

```bash
# Listar services
kubectl get svc -A

# Detalhes de um service
kubectl describe svc <service-name> -n <namespace>

# Endpoints
kubectl get endpoints -A
```

### Ingress

```bash
# Listar ingresses
kubectl get ingress -A

# Detalhes
kubectl describe ingress <ingress-name> -n <namespace>

# Testar ingress
curl -H "Host: develop-be.devops.local" http://localhost
```

### Port Forwarding

```bash
# Port-forward de um service
make port-forward SERVICE=crivo-be PORT=3000

# Ou manualmente
kubectl port-forward -n devops-lab svc/crivo-be 3000:3000

# Port-forward de um pod
kubectl port-forward -n devops-lab pod/crivo-be-xxx 3000:3000

# Múltiplas portas
kubectl port-forward -n devops-lab svc/crivo-be 3000:3000 9090:9090
```

### Network Policies

```bash
# Ver network policies
kubectl get networkpolicies -A

# Criar policy exemplo
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-from-monitoring
  namespace: devops-lab
spec:
  podSelector:
    matchLabels:
      app: crivo-be
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
EOF
```

## Registry Local

### Usar Registry Local

```bash
# Registry está disponível em:
# ghcr.io/geraldobl58

# Fazer build e push
docker build -t ghcr.io/geraldobl58/crivo-be:latest .
docker push ghcr.io/geraldobl58/crivo-be:latest

# Listar imagens no registry
curl http://localhost:5000/v2/_catalog

# Tags de uma imagem
curl http://localhost:5000/v2/crivo-be/tags/list
```

### Configurar Docker para Registry Local

```bash
# Docker já está configurado pelo k3d
# Mas se precisar configurar manualmente:

# Editar /etc/hosts
echo REMOVE_REGISTRY_LINE | sudo tee -a /etc/hosts

# Docker Desktop → Settings → Docker Engine
# Adicionar:
{
  "insecure-registries": ["ghcr.io/geraldobl58"]
}
```

## Recursos e Limites

### Ver Uso de Recursos

```bash
# Nodes
kubectl top nodes

# Pods
kubectl top pods -A

# Por namespace
kubectl top pods -n devops-lab

# Ordenar por memória
kubectl top pods -A --sort-by=memory

# Ordenar por CPU
kubectl top pods -A --sort-by=cpu
```

### Resource Quotas

```bash
# Ver quotas
kubectl get resourcequotas -A

# Criar quota para namespace
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: devops-quota
  namespace: devops-lab
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "10"
EOF
```

## Ferramentas Úteis

### k9s - Interface Visual

```bash
# Iniciar k9s
k9s

# Comandos dentro do k9s:
# :pods        # Ver pods
# :svc         # Ver services
# :deploy      # Ver deployments
# :ns          # Trocar namespace
# /            # Filtrar
# l            # Ver logs
# d            # Describe
# e            # Edit
# s            # Shell
# Ctrl+d       # Delete
```

### kubectl plugins

```bash
# Instalar krew (plugin manager)
brew install krew

# Plugins úteis
kubectl krew install ctx      # Gerenciar contextos
kubectl krew install ns       # Gerenciar namespaces
kubectl krew install tail     # Tail logs
kubectl krew install tree     # Ver hierarquia de recursos
```

## Troubleshooting

### Cluster não inicia

```bash
# Ver logs do Docker
docker logs k3d-devops-lab-server-0

# Recriar cluster
k3d cluster delete devops-lab
make create-cluster
```

### Pods em CrashLoopBackOff

```bash
# Ver logs
kubectl logs <pod> -n <namespace>

# Logs anteriores
kubectl logs <pod> -n <namespace> --previous

# Events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Problemas de Rede

```bash
# Testar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Testar conectividade
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://crivo-be.devops-lab:3000/health
```

### Limpar Recursos

```bash
# Deletar pods órfãos
kubectl delete pods --field-selector=status.phase=Failed -A

# Deletar completed jobs
kubectl delete jobs --field-selector=status.successful=1 -A

# Limpar imagens não usadas
docker system prune -a
```

## Comparativo: k3d vs outros

| Feature        | k3d      | Minikube | Kind     | Docker Desktop |
| -------------- | -------- | -------- | -------- | -------------- |
| Multi-node     | ✅       | ⚠️       | ✅       | ❌             |
| LoadBalancer   | ✅       | ⚠️       | ❌       | ✅             |
| Velocidade     | ⚡⚡⚡   | ⚡       | ⚡⚡     | ⚡⚡           |
| Uso de memória | 🟢 Baixo | 🟡 Médio | 🟢 Baixo | 🟡 Médio       |
| Registry local | ✅       | ❌       | ⚠️       | ❌             |
| Produção-like  | ⭐⭐⭐   | ⭐       | ⭐⭐     | ⭐             |

## Próximos Passos

- [03 - ArgoCD GitOps](./03-argocd.md)
- [04 - Observabilidade](./04-observability.md)
- [08 - Comandos Úteis](./08-cheatsheet.md)

---

**Anterior**: [01 - Instalação](./01-installation.md) | **Próximo**: [03 - ArgoCD](./03-argocd.md)
