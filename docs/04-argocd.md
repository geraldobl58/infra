# 🚀 ArgoCD GitOps - DevOps Lab

## O que é ArgoCD?

ArgoCD é uma ferramenta declarativa de entrega contínua para Kubernetes que segue os princípios GitOps:

- 📦 **Git como fonte da verdade**: Configurações versionadas
- 🔄 **Sync automático**: Detecta e aplica mudanças
- 👁️ **Visibilidade**: Dashboard visual do estado das aplicações
- 🔙 **Rollback fácil**: Voltar para versões anteriores
- 🎯 **Multi-env**: Gerenciar múltiplos ambientes

## Arquitetura

```
┌──────────────────────────────────────────────┐
│             GitHub Repository                │
│   (Git como fonte da verdade)                │
└──────────────┬───────────────────────────────┘
               │
               │ Git Poll/Webhook
               ↓
┌──────────────────────────────────────────────┐
│            ArgoCD Server                     │
│  ┌────────────┐  ┌────────────┐             │
│  │ Application│  │ Controller │             │
│  │ Controller │  │            │             │
│  └────────────┘  └────────────┘             │
└──────────────┬───────────────────────────────┘
               │
               │ Apply/Sync
               ↓
┌──────────────────────────────────────────────┐
│         Kubernetes Cluster                   │
│   (devops-lab namespace)                     │
└──────────────────────────────────────────────┘
```

## Acesso ao ArgoCD

### Dashboard Web

```bash
# Ver URL e credenciais
make urls

# Abrir dashboard
make dashboard

# URL: http://argocd.devops.local
# User: admin
# Pass: Obtido do secret
```

### CLI

```bash
# Fazer login
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login argocd.devops.local --username admin --password "$ARGOCD_PASSWORD" --insecure

# Verificar versão
argocd version

# Listar aplicações
argocd app list
```

## Conceitos Principais

### Application

Uma Application é um recurso que conecta um repositório Git a um namespace Kubernetes:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crivo-be-local
  namespace: argocd
spec:
  project: devops-lab
  source:
    repoURL: https://github.com/geraldobl58/devops.git
    targetRevision: main
    path: local/helm/crivo-be
    helm:
      valueFiles:
        - values-local.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: devops-lab
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### ApplicationSet

ApplicationSet permite criar múltiplas Applications a partir de um template:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: devops-apps-local
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - service: crivo-be
          - service: crivo-fe
          - service: crivo-auth
  template:
    metadata:
      name: "{{service}}-local"
    spec:
      # ... configuração
```

### Project

Projects fornecem isolamento lógico:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: devops-lab
  namespace: argocd
spec:
  description: DevOps local development
  sourceRepos:
    - "*"
  destinations:
    - namespace: devops-lab
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: "*"
      kind: "*"
```

## Gestão de Aplicações

### Listar Aplicações

```bash
# Via CLI
argocd app list

# Via kubectl
kubectl get applications -n argocd

# Detalhes
argocd app get crivo-be-local
```

### Sincronizar Aplicações

```bash
# Sync manual
argocd app sync crivo-be-local

# Sync todas
argocd app sync -l environment=local

# Sync com prune (remove recursos órfãos)
argocd app sync crivo-be-local --prune

# Sync forçado
argocd app sync crivo-be-local --force
```

### Ver Status

```bash
# Status de uma app
argocd app get crivo-be-local

# Ver diferenças (drift detection)
argocd app diff crivo-be-local

# Ver histórico
argocd app history crivo-be-local

# Ver recursos
argocd app resources crivo-be-local
```

### Rollback

```bash
# Ver histórico
argocd app history crivo-be-local

# Rollback para revisão anterior
argocd app rollback crivo-be-local 2

# Rollback via kubectl
kubectl patch application crivo-be-local -n argocd --type merge -p '{"spec":{"source":{"targetRevision":"previous-commit"}}}'
```

## Sync Policies

### Auto-Sync

```yaml
syncPolicy:
  automated:
    prune: true # Remove recursos deletados do Git
    selfHeal: true # Reverte mudanças manuais
```

### Manual Sync

```yaml
syncPolicy:
  automated: null # Desabilita auto-sync
```

### Sync Options

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true # Criar namespace se não existir
    - PruneLast=true # Prunar por último
    - ApplyOutOfSyncOnly=true # Aplicar apenas out-of-sync
    - RespectIgnoreDifferences=true
```

### Retry Policy

```yaml
syncPolicy:
  retry:
    limit: 3
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

## Hooks

### Pre-Sync Hook

Executar antes do sync:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-sync-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrations
          image: crivo-be:latest
          command: ["npm", "run", "migrate"]
      restartPolicy: Never
```

### Post-Sync Hook

Executar após o sync:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: post-sync-smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  # ... teste de smoke
```

## Health Assessment

### Custom Health Check

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations: |
    apps/Deployment:
      health.lua: |
        hs = {}
        if obj.status.availableReplicas == obj.spec.replicas then
          hs.status = "Healthy"
          hs.message = "All replicas are available"
        else
          hs.status = "Progressing"
          hs.message = "Waiting for replicas"
        end
        return hs
```

## Secrets Management

### Sealed Secrets (Recomendado)

```bash
# Instalar Sealed Secrets Controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Instalar kubeseal CLI
brew install kubeseal

# Criar secret selado
kubectl create secret generic devops-secrets \
  --from-literal=database-url='postgres://...' \
  --dry-run=client -o yaml | \
  kubeseal --format yaml > sealed-secret.yaml

# Aplicar
kubectl apply -f sealed-secret.yaml
```

### External Secrets Operator

```bash
# Instalar ESO
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# Usar 1Password, Vault, AWS Secrets Manager, etc
```

## Notificações

### Configurar Slack

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $slack-token
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} is now running new version.
    slack:
      attachments: |
        [{
          "title": "{{.app.metadata.name}}",
          "title_link":"{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "color": "#18be52"
        }]
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

## Multi-Cluster

### Adicionar Cluster

```bash
# Listar clusters
kubectl config get-contexts

# Adicionar cluster ao ArgoCD
argocd cluster add k3d-outro-cluster

# Listar clusters no ArgoCD
argocd cluster list
```

### Deploy Cross-Cluster

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crivo-be-prod
spec:
  destination:
    server: https://prod-cluster.example.com
    namespace: crivo-prod
  # ... resto da config
```

## Best Practices

### 1. Use Projects

```bash
# Criar projeto por time/ambiente
argocd proj create team-backend \
  --description "Backend team applications" \
  --dest https://kubernetes.default.svc,backend-* \
  --src https://github.com/geraldobl58/*
```

### 2. ApplicationSets para DRY

Evite duplicação criando ApplicationSets:

```yaml
generators:
  - matrix:
      generators:
        - list:
            elements:
              - env: dev
              - env: staging
              - env: prod
        - list:
            elements:
              - service: api
              - service: web
```

### 3. Sync Waves

Controlar ordem de deploy:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0" # Deploy primeiro
```

### 4. Ignore Differences

Ignorar campos que mudam:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas # HPA altera replicas
```

## Workflows Comuns

### Deploy Nova Versão

```bash
# 1. Fazer mudanças no código
git add .
git commit -m "feat: nova feature"
git push

# 2. Build e push da imagem
docker build -t ghcr.io/geraldobl58/crivo-be:v1.2.3 .
docker push ghcr.io/geraldobl58/crivo-be:v1.2.3

# 3. Atualizar Helm values
# Editar local/helm/crivo-be/values-local.yaml
# Mudar tag: "v1.2.3"

# 4. Commit e push
git add local/helm/crivo-be/values-local.yaml
git commit -m "release: crivo-be v1.2.3"
git push

# 5. ArgoCD faz sync automaticamente em ~3 minutos
# Ou forçar sync:
argocd app sync crivo-be-local
```

### Debug de Sync Failures

```bash
# Ver detalhes do erro
argocd app get crivo-be-local

# Ver logs do sync
argocd app logs crivo-be-local

# Ver eventos
kubectl get events -n devops-lab --sort-by='.lastTimestamp'

# Ver diff
argocd app diff crivo-be-local
```

## Monitoramento com Prometheus

O ArgoCD já exporta métricas:

```yaml
# ServiceMonitor já criado pelo script de instalação
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  endpoints:
    - port: metrics
```

Ver no Grafana:

- Dashboard ID: 14584 (ArgoCD)

## Comandos Úteis

```bash
# Status de todas apps
argocd app list

# Ver apps com problemas
argocd app list | grep OutOfSync

# Sync todas apps
argocd app sync -l environment=local

# Ver logs de sync
argocd app logs crivo-be-local --follow

# Ver recursos de uma app
argocd app resources crivo-be-local

# Info do servidor
argocd admin settings resource-overrides

# Ver projects
argocd proj list

# Export de app (backup)
argocd app get crivo-be-local -o yaml > backup.yaml
```

## Troubleshooting

### App fica em Progressing

```bash
# Ver detalhes
kubectl describe application crivo-be-local -n argocd

# Ver pods
kubectl get pods -n devops-lab

# Ver eventos
kubectl get events -n devops-lab
```

### Image Pull Errors

```bash
# Verificar imagePullSecrets
kubectl get deployment crivo-be -n devops-lab -o yaml | grep -A 5 imagePullSecrets

# Criar secret se necessário
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=usuario \
  --docker-password=token \
  -n devops-lab
```

### Out of Sync mas igual

```bash
# Pode ser differences ignoráveis
argocd app diff crivo-be-local

# Forçar refresh
argocd app get crivo-be-local --refresh

# Hard refresh
argocd app get crivo-be-local --hard-refresh
```

## Próximos Passos

- [04 - Observabilidade](./04-observability.md)
- [06 - Deploy de Aplicações](./06-applications.md)
- [08 - Comandos Úteis](./08-cheatsheet.md)

---

**Anterior**: [02 - Kubernetes](./02-kubernetes.md) | **Próximo**: [04 - Observabilidade](./04-observability.md)
