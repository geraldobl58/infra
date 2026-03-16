# 🚀 ArgoCD GitOps - Nexo CloudLab

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
│   (nexo-local namespace)                     │
└──────────────────────────────────────────────┘
```

## Acesso ao ArgoCD

### Dashboard Web

```bash
# Ver URL e credenciais
make urls

# Abrir dashboard
make dashboard

# URL: http://argocd.nexo.local
# User: admin
# Pass: Obtido do secret
```

### CLI

```bash
# Fazer login
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login argocd.nexo.local --username admin --password "$ARGOCD_PASSWORD" --insecure

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
  name: nexo-be-local
  namespace: argocd
spec:
  project: nexo-local
  source:
    repoURL: https://github.com/geraldobl58/nexo.git
    targetRevision: main
    path: local/helm/nexo-be
    helm:
      valueFiles:
        - values-local.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: nexo-local
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
  name: nexo-apps-local
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - service: nexo-be
          - service: nexo-fe
          - service: nexo-auth
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
  name: nexo-local
  namespace: argocd
spec:
  description: Nexo local development
  sourceRepos:
    - "*"
  destinations:
    - namespace: nexo-local
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
argocd app get nexo-be-local
```

### Sincronizar Aplicações

```bash
# Sync manual
argocd app sync nexo-be-local

# Sync todas
argocd app sync -l environment=local

# Sync com prune (remove recursos órfãos)
argocd app sync nexo-be-local --prune

# Sync forçado
argocd app sync nexo-be-local --force
```

### Ver Status

```bash
# Status de uma app
argocd app get nexo-be-local

# Ver diferenças (drift detection)
argocd app diff nexo-be-local

# Ver histórico
argocd app history nexo-be-local

# Ver recursos
argocd app resources nexo-be-local
```

### Rollback

```bash
# Ver histórico
argocd app history nexo-be-local

# Rollback para revisão anterior
argocd app rollback nexo-be-local 2

# Rollback via kubectl
kubectl patch application nexo-be-local -n argocd --type merge -p '{"spec":{"source":{"targetRevision":"previous-commit"}}}'
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
          image: nexo-be:latest
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
kubectl create secret generic nexo-secrets \
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
  name: nexo-be-prod
spec:
  destination:
    server: https://prod-cluster.example.com
    namespace: nexo-prod
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
docker build -t ghcr.io/geraldobl58/nexo-be:v1.2.3 .
docker push ghcr.io/geraldobl58/nexo-be:v1.2.3

# 3. Atualizar Helm values
# Editar local/helm/nexo-be/values-local.yaml
# Mudar tag: "v1.2.3"

# 4. Commit e push
git add local/helm/nexo-be/values-local.yaml
git commit -m "release: nexo-be v1.2.3"
git push

# 5. ArgoCD faz sync automaticamente em ~3 minutos
# Ou forçar sync:
argocd app sync nexo-be-local
```

### Debug de Sync Failures

```bash
# Ver detalhes do erro
argocd app get nexo-be-local

# Ver logs do sync
argocd app logs nexo-be-local

# Ver eventos
kubectl get events -n nexo-local --sort-by='.lastTimestamp'

# Ver diff
argocd app diff nexo-be-local
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
argocd app logs nexo-be-local --follow

# Ver recursos de uma app
argocd app resources nexo-be-local

# Info do servidor
argocd admin settings resource-overrides

# Ver projects
argocd proj list

# Export de app (backup)
argocd app get nexo-be-local -o yaml > backup.yaml
```

## Troubleshooting

### App fica em Progressing

```bash
# Ver detalhes
kubectl describe application nexo-be-local -n argocd

# Ver pods
kubectl get pods -n nexo-local

# Ver eventos
kubectl get events -n nexo-local
```

### Image Pull Errors

```bash
# Verificar imagePullSecrets
kubectl get deployment nexo-be -n nexo-local -o yaml | grep -A 5 imagePullSecrets

# Criar secret se necessário
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=usuario \
  --docker-password=token \
  -n nexo-local
```

### Out of Sync mas igual

```bash
# Pode ser differences ignoráveis
argocd app diff nexo-be-local

# Forçar refresh
argocd app get nexo-be-local --refresh

# Hard refresh
argocd app get nexo-be-local --hard-refresh
```

## Próximos Passos

- [04 - Observabilidade](./04-observability.md)
- [06 - Deploy de Aplicações](./06-applications.md)
- [08 - Comandos Úteis](./08-cheatsheet.md)

---

**Anterior**: [02 - Kubernetes](./02-kubernetes.md) | **Próximo**: [04 - Observabilidade](./04-observability.md)
