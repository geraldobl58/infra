# 🚀 Deploy de Aplicações - Nexo CloudLab

## Visão Geral

Este guia mostra como fazer deploy das aplicações Nexo (Backend, Frontend, Auth) no CloudLab usando ArgoCD e GitOps.

## Arquitetura de Deploy

```
┌─────────────────────────────────────────────┐
│         GitHub Repository                   │
│  local/helm/nexo-be/values-local.yaml       │
│  local/helm/nexo-fe/values-local.yaml       │
│  local/helm/nexo-auth/values-local.yaml     │
└──────────────┬──────────────────────────────┘
               │
               │ ArgoCD Poll/Sync
               ↓
┌──────────────────────────────────────────────┐
│            ArgoCD                            │
│  ApplicationSet: nexo-apps-local             │
│    - nexo-be-local                           │
│    - nexo-fe-local                           │
│    - nexo-auth-local                         │
└──────────────┬───────────────────────────────┘
               │
               │ Apply to Kubernetes
               ↓
┌──────────────────────────────────────────────┐
│         nexo-local namespace                 │
│  - nexo-be (Backend API)                     │
│  - nexo-fe (Frontend Next.js)                │
│  - nexo-auth (Keycloak)                      │
│  - postgres (Database)                       │
└──────────────────────────────────────────────┘
```

## Pré-requisitos

### 1. Build das Imagens

```bash
# Navegar para cada aplicação
cd apps/nexo-be

# Build da imagem
docker build -t ghcr.io/geraldobl58/nexo-be:latest .

# Push para registry local
docker push ghcr.io/geraldobl58/nexo-be:latest

# Repetir para nexo-fe e nexo-auth
cd ../nexo-fe
docker build -t ghcr.io/geraldobl58/nexo-fe:latest .
docker push ghcr.io/geraldobl58/nexo-fe:latest

cd ../nexo-auth
docker build -t ghcr.io/geraldobl58/nexo-auth:latest .
docker push ghcr.io/geraldobl58/nexo-auth:latest
```

### 2. Criar Secrets

```bash
# Criar secret com credenciais do banco e outras configs
kubectl create secret generic nexo-secrets \
  --from-literal=database-url='postgresql://nexo:nexo123@postgres:5432/nexo_db' \
  --from-literal=jwt-secret='super-secret-key-change-in-production' \
  --from-literal=db-username='nexo' \
  --from-literal=db-password='nexo123' \
  --from-literal=keycloak-db-url='jdbc:postgresql://postgres:5432/keycloak' \
  --from-literal=keycloak-admin-password='admin123' \
  -n nexo-local
```

### 3. Deploy PostgreSQL

```bash
# Via Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install postgres bitnami/postgresql \
  --namespace nexo-local \
  --create-namespace \
  --set auth.username=nexo \
  --set auth.password=nexo123 \
  --set auth.database=nexo_db \
  --set primary.persistence.storageClass=local-path-ssd \
  --set primary.persistence.size=5Gi
```

## Deploy via ArgoCD

### Método 1: Script Automático

```bash
# Deploy tudo
make deploy-apps

# Ou manualmente
./scripts/05-deploy-apps.sh
```

### Método 2: Manual via CLI

```bash
# Criar ApplicationSet
kubectl apply -f - <<EOF
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
            path: local/helm/nexo-be
          - service: nexo-fe
            path: local/helm/nexo-fe
          - service: nexo-auth
            path: local/helm/nexo-auth

  template:
    metadata:
      name: "{{service}}-local"
      labels:
        app: "{{service}}"
        environment: local
    spec:
      project: nexo-local
      source:
        repoURL: https://github.com/geraldobl58/nexo.git
        targetRevision: main
        path: "{{path}}"
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
        syncOptions:
          - CreateNamespace=true
EOF

# Aguardar sync
argocd app list
argocd app sync nexo-be-local
argocd app sync nexo-fe-local
argocd app sync nexo-auth-local
```

## Verificar Deploy

### Status das Apps

```bash
# Via ArgoCD CLI
argocd app list

# Output esperado:
# NAME              CLUSTER                         NAMESPACE    PROJECT      STATUS  HEALTH
# nexo-be-local     https://kubernetes.default.svc  nexo-local   nexo-local   Synced  Healthy
# nexo-fe-local     https://kubernetes.default.svc  nexo-local   nexo-local   Synced  Healthy
# nexo-auth-local   https://kubernetes.default.svc  nexo-local   nexo-local   Synced  Healthy
```

### Pods

```bash
kubectl get pods -n nexo-local

# Output esperado:
# NAME                         READY   STATUS    RESTARTS   AGE
# nexo-be-xxx                  1/1     Running   0          5m
# nexo-fe-xxx                  1/1     Running   0          5m
# nexo-auth-xxx                1/1     Running   0          5m
# postgres-xxx                 1/1     Running   0          10m
```

### Services e Ingress

```bash
kubectl get svc,ingress -n nexo-local

# Testar endpoints
curl http://develop-be.nexo.local/health
curl http://develop-fe.nexo.local
curl http://develop-auth.nexo.local
```

## Configuração dos Helm Charts

### Backend (nexo-be)

```yaml
# local/helm/nexo-be/values-local.yaml
replicaCount: 1

image:
  repository: ghcr.io/geraldobl58/nexo-be
  tag: "latest"

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 256Mi

env:
  - name: NODE_ENV
    value: "local"
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: nexo-secrets
        key: database-url

ingress:
  enabled: true
  hosts:
    - host: develop-be.nexo.local
      paths:
        - path: /
          pathType: Prefix
```

### Frontend (nexo-fe)

```yaml
# local/helm/nexo-fe/values-local.yaml
replicaCount: 1

image:
  repository: ghcr.io/geraldobl58/nexo-fe
  tag: "latest"

env:
  - name: NEXT_PUBLIC_API_URL
    value: "http://develop-be.nexo.local"
  - name: NEXT_PUBLIC_AUTH_URL
    value: "http://develop-auth.nexo.local"

ingress:
  enabled: true
  hosts:
    - host: develop-fe.nexo.local
```

### Auth (nexo-auth/Keycloak)

```yaml
# local/helm/nexo-auth/values-local.yaml
replicaCount: 1

image:
  repository: ghcr.io/geraldobl58/nexo-auth
  tag: "latest"

env:
  - name: KC_DB
    value: "postgres"
  - name: KC_DB_URL
    valueFrom:
      secretKeyRef:
        name: nexo-secrets
        key: keycloak-db-url

ingress:
  enabled: true
  hosts:
    - host: develop-auth.nexo.local
```

## Workflow de Desenvolvimento

### 1. Fazer Mudanças no Código

```bash
cd apps/nexo-be
# Editar código...
git add .
git commit -m "feat: nova feature"
```

### 2. Build e Push Nova Imagem

```bash
# Com versão específica
VERSION=v1.2.3
docker build -t ghcr.io/geraldobl58/nexo-be:$VERSION .
docker push ghcr.io/geraldobl58/nexo-be:$VERSION

# Ou latest
docker build -t ghcr.io/geraldobl58/nexo-be:latest .
docker push ghcr.io/geraldobl58/nexo-be:latest
```

### 3. Atualizar Helm Values (se usar versão)

```yaml
# local/helm/nexo-be/values-local.yaml
image:
  tag: "v1.2.3" # Atualizar
```

```bash
git add local/helm/nexo-be/values-local.yaml
git commit -m "release: nexo-be v1.2.3"
git push
```

### 4. ArgoCD Faz Sync Automático

```bash
# Monitorar sync
argocd app get nexo-be-local --watch

# Ou forçar sync imediato
argocd app sync nexo-be-local
```

### 5. Verificar Deploy

```bash
# Ver rollout
kubectl rollout status deployment nexo-be -n nexo-local

# Ver pods novos
kubectl get pods -n nexo-local -l app=nexo-be

# Testar aplicação
curl http://develop-be.nexo.local/health
```

## Rollback

### Via ArgoCD

```bash
# Ver histórico
argocd app history nexo-be-local

# Rollback para revisão anterior
argocd app rollback nexo-be-local 2
```

### Via Kubectl

```bash
# Rollback deployment
kubectl rollout undo deployment nexo-be -n nexo-local

# Rollback para revisão específica
kubectl rollout undo deployment nexo-be --to-revision=3 -n nexo-local
```

## Scaling

### Manual

```bash
# Scale up
kubectl scale deployment nexo-be --replicas=3 -n nexo-local

# Scale down
kubectl scale deployment nexo-be --replicas=1 -n nexo-local
```

### Horizontal Pod Autoscaler (HPA)

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nexo-be-hpa
  namespace: nexo-local
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nexo-be
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

```bash
kubectl apply -f hpa.yaml
kubectl get hpa -n nexo-local
```

## Migrations e Seeds

### Pre-Sync Hook para Migrations

```yaml
# migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: nexo-be-migration
  namespace: nexo-local
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: ghcr.io/geraldobl58/nexo-be:latest
          command: ["npm", "run", "migrate"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: nexo-secrets
                  key: database-url
      restartPolicy: Never
  backoffLimit: 3
```

### Executar Migration Manualmente

```bash
# Via Job
kubectl create job --from=cronjob/migrations manual-migration -n nexo-local

# Ou exec no pod
kubectl exec -it <nexo-be-pod> -n nexo-local -- npm run migrate
```

## Monitoramento

### Métricas no Grafana

1. Acessar: http://grafana.nexo.local
2. Dashboard → Kubernetes Pods
3. Filtrar por namespace: nexo-local

### Verificar Health

```bash
# Backend health check
curl http://develop-be.nexo.local/health

# Ver métricas
curl http://develop-be.nexo.local/metrics

# Frontend
curl -I http://develop-fe.nexo.local

# Auth
curl http://develop-auth.nexo.local/health/ready
```

### Logs

```bash
# Via kubectl
make logs SERVICE=nexo-be

# Ou
kubectl logs -n nexo-local -l app=nexo-be --follow

# No Kibana
# Query: kubernetes.namespace: "nexo-local"
```

## Troubleshooting

### App não sincroniza

```bash
# Ver detalhes
argocd app get nexo-be-local

# Ver diff
argocd app diff nexo-be-local

# Logs do sync
argocd app logs nexo-be-local

# Forçar refresh
argocd app get nexo-be-local --refresh
```

### Pod crashando

```bash
# Ver logs
kubectl logs -n nexo-local <pod> --previous

# Describe
kubectl describe pod -n nexo-local <pod>

# Events
kubectl get events -n nexo-local --sort-by='.lastTimestamp'
```

### Database connection failed

```bash
# Verificar se postgres está rodando
kubectl get pods -n nexo-local -l app.kubernetes.io/name=postgresql

# Testar conexão
kubectl run -it --rm psql --image=postgres:15 --restart=Never -- \
  psql -h postgres.nexo-local -U nexo -d nexo_db

# Verificar secret
kubectl get secret nexo-secrets -n nexo-local -o yaml
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy-local.yml
name: Deploy to Local CloudLab

on:
  push:
    branches: [main]
    paths:
      - "apps/nexo-be/**"

jobs:
  deploy:
    runs-on: self-hosted # Runner no Mac local
    steps:
      - uses: actions/checkout@v3

      - name: Build Image
        run: |
          cd apps/nexo-be
          docker build -t ghcr.io/geraldobl58/nexo-be:${{ github.sha }} .
          docker tag ghcr.io/geraldobl58/nexo-be:${{ github.sha }} \
                     ghcr.io/geraldobl58/nexo-be:latest

      - name: Push Image
        run: |
          docker push ghcr.io/geraldobl58/nexo-be:${{ github.sha }}
          docker push ghcr.io/geraldobl58/nexo-be:latest

      - name: Update Helm Values
        run: |
          sed -i '' "s/tag: \".*\"/tag: \"${{ github.sha }}\"/" \
            local/helm/nexo-be/values-local.yaml
          git add local/helm/nexo-be/values-local.yaml
          git commit -m "chore: update nexo-be to ${{ github.sha }}"
          git push

      - name: Sync ArgoCD
        run: |
          argocd app sync nexo-be-local --force
```

## Próximos Passos

- [06 - Troubleshooting](./06-troubleshooting.md)
- [07 - Cheat Sheet](./07-cheatsheet.md)

---

**Anterior**: [03 - Observabilidade](./03-observability.md) | **Próximo**: [06 - Troubleshooting](./06-troubleshooting.md)
