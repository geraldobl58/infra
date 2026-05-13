# 🚀 Deploy de Aplicações - DevOps Lab

## Visão Geral

Este guia mostra como fazer deploy das aplicações DevOps (Backend, Frontend, Auth) no Lab usando ArgoCD e GitOps.

## Arquitetura de Deploy

```
┌─────────────────────────────────────────────┐
│         GitHub Repository                   │
│  local/helm/crivo-be/values-local.yaml       │
│  local/helm/crivo-fe/values-local.yaml       │
│  local/helm/crivo-auth/values-local.yaml     │
└──────────────┬──────────────────────────────┘
               │
               │ ArgoCD Poll/Sync
               ↓
┌──────────────────────────────────────────────┐
│            ArgoCD                            │
│  ApplicationSet: devops-apps-local             │
│    - crivo-be-local                           │
│    - crivo-fe-local                           │
│    - crivo-auth-local                         │
└──────────────┬───────────────────────────────┘
               │
               │ Apply to Kubernetes
               ↓
┌──────────────────────────────────────────────┐
│         devops-lab namespace                 │
│  - crivo-be (Backend API)                     │
│  - crivo-fe (Frontend Next.js)                │
│  - crivo-auth (Keycloak)                      │
│  - postgres (Database)                       │
└──────────────────────────────────────────────┘
```

## Pré-requisitos

### 1. Build das Imagens

```bash
# Navegar para cada aplicação
cd apps/crivo-be

# Build da imagem
docker build -t ghcr.io/geraldobl58/crivo-be:latest .

# Push para registry local
docker push ghcr.io/geraldobl58/crivo-be:latest

# Repetir para crivo-fe e crivo-auth
cd ../crivo-fe
docker build -t ghcr.io/geraldobl58/crivo-fe:latest .
docker push ghcr.io/geraldobl58/crivo-fe:latest

cd ../crivo-auth
docker build -t ghcr.io/geraldobl58/crivo-auth:latest .
docker push ghcr.io/geraldobl58/crivo-auth:latest
```

### 2. Criar Secrets

```bash
# Criar secret com credenciais do banco e outras configs
kubectl create secret generic devops-secrets \
  --from-literal=database-url='postgresql://devops:devops123@postgres:5432/devops_db' \
  --from-literal=jwt-secret='super-secret-key-change-in-production' \
  --from-literal=db-username='devops' \
  --from-literal=db-password='devops123' \
  --from-literal=keycloak-db-url='jdbc:postgresql://postgres:5432/keycloak' \
  --from-literal=keycloak-admin-password='admin123' \
  -n devops-lab
```

### 3. Deploy PostgreSQL

```bash
# Via Helm
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install postgres bitnami/postgresql \
  --namespace devops-lab \
  --create-namespace \
  --set auth.username=devops \
  --set auth.password=devops123 \
  --set auth.database=devops_db \
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
  name: devops-apps-local
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - service: crivo-be
            path: local/helm/crivo-be
          - service: crivo-fe
            path: local/helm/crivo-fe
          - service: crivo-auth
            path: local/helm/crivo-auth

  template:
    metadata:
      name: "{{service}}-local"
      labels:
        app: "{{service}}"
        environment: local
    spec:
      project: devops-lab
      source:
        repoURL: https://github.com/geraldobl58/devops.git
        targetRevision: main
        path: "{{path}}"
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
        syncOptions:
          - CreateNamespace=true
EOF

# Aguardar sync
argocd app list
argocd app sync crivo-be-local
argocd app sync crivo-fe-local
argocd app sync crivo-auth-local
```

## Verificar Deploy

### Status das Apps

```bash
# Via ArgoCD CLI
argocd app list

# Output esperado:
# NAME              CLUSTER                         NAMESPACE    PROJECT      STATUS  HEALTH
# crivo-be-local     https://kubernetes.default.svc  devops-lab   devops-lab   Synced  Healthy
# crivo-fe-local     https://kubernetes.default.svc  devops-lab   devops-lab   Synced  Healthy
# crivo-auth-local   https://kubernetes.default.svc  devops-lab   devops-lab   Synced  Healthy
```

### Pods

```bash
kubectl get pods -n devops-lab

# Output esperado:
# NAME                         READY   STATUS    RESTARTS   AGE
# crivo-be-xxx                  1/1     Running   0          5m
# crivo-fe-xxx                  1/1     Running   0          5m
# crivo-auth-xxx                1/1     Running   0          5m
# postgres-xxx                 1/1     Running   0          10m
```

### Services e Ingress

```bash
kubectl get svc,ingress -n devops-lab

# Testar endpoints
curl http://develop-be.devops.local/health
curl http://develop-fe.devops.local
curl http://develop-auth.devops.local
```

## Configuração dos Helm Charts

### Backend (crivo-be)

```yaml
# local/helm/crivo-be/values-local.yaml
replicaCount: 1

image:
  repository: ghcr.io/geraldobl58/crivo-be
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
        name: devops-secrets
        key: database-url

ingress:
  enabled: true
  hosts:
    - host: develop-be.devops.local
      paths:
        - path: /
          pathType: Prefix
```

### Frontend (crivo-fe)

```yaml
# local/helm/crivo-fe/values-local.yaml
replicaCount: 1

image:
  repository: ghcr.io/geraldobl58/crivo-fe
  tag: "latest"

env:
  - name: NEXT_PUBLIC_API_URL
    value: "http://develop-be.devops.local"
  - name: NEXT_PUBLIC_AUTH_URL
    value: "http://develop-auth.devops.local"

ingress:
  enabled: true
  hosts:
    - host: develop-fe.devops.local
```

### Auth (crivo-auth/Keycloak)

```yaml
# local/helm/crivo-auth/values-local.yaml
replicaCount: 1

image:
  repository: ghcr.io/geraldobl58/crivo-auth
  tag: "latest"

env:
  - name: KC_DB
    value: "postgres"
  - name: KC_DB_URL
    valueFrom:
      secretKeyRef:
        name: devops-secrets
        key: keycloak-db-url

ingress:
  enabled: true
  hosts:
    - host: develop-auth.devops.local
```

## Workflow de Desenvolvimento

### 1. Fazer Mudanças no Código

```bash
cd apps/crivo-be
# Editar código...
git add .
git commit -m "feat: nova feature"
```

### 2. Build e Push Nova Imagem

```bash
# Com versão específica
VERSION=v1.2.3
docker build -t ghcr.io/geraldobl58/crivo-be:$VERSION .
docker push ghcr.io/geraldobl58/crivo-be:$VERSION

# Ou latest
docker build -t ghcr.io/geraldobl58/crivo-be:latest .
docker push ghcr.io/geraldobl58/crivo-be:latest
```

### 3. Atualizar Helm Values (se usar versão)

```yaml
# local/helm/crivo-be/values-local.yaml
image:
  tag: "v1.2.3" # Atualizar
```

```bash
git add local/helm/crivo-be/values-local.yaml
git commit -m "release: crivo-be v1.2.3"
git push
```

### 4. ArgoCD Faz Sync Automático

```bash
# Monitorar sync
argocd app get crivo-be-local --watch

# Ou forçar sync imediato
argocd app sync crivo-be-local
```

### 5. Verificar Deploy

```bash
# Ver rollout
kubectl rollout status deployment crivo-be -n devops-lab

# Ver pods novos
kubectl get pods -n devops-lab -l app=crivo-be

# Testar aplicação
curl http://develop-be.devops.local/health
```

## Rollback

### Via ArgoCD

```bash
# Ver histórico
argocd app history crivo-be-local

# Rollback para revisão anterior
argocd app rollback crivo-be-local 2
```

### Via Kubectl

```bash
# Rollback deployment
kubectl rollout undo deployment crivo-be -n devops-lab

# Rollback para revisão específica
kubectl rollout undo deployment crivo-be --to-revision=3 -n devops-lab
```

## Scaling

### Manual

```bash
# Scale up
kubectl scale deployment crivo-be --replicas=3 -n devops-lab

# Scale down
kubectl scale deployment crivo-be --replicas=1 -n devops-lab
```

### Horizontal Pod Autoscaler (HPA)

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: crivo-be-hpa
  namespace: devops-lab
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: crivo-be
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
kubectl get hpa -n devops-lab
```

## Migrations e Seeds

### Pre-Sync Hook para Migrations

```yaml
# migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: crivo-be-migration
  namespace: devops-lab
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: ghcr.io/geraldobl58/crivo-be:latest
          command: ["npm", "run", "migrate"]
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: devops-secrets
                  key: database-url
      restartPolicy: Never
  backoffLimit: 3
```

### Executar Migration Manualmente

```bash
# Via Job
kubectl create job --from=cronjob/migrations manual-migration -n devops-lab

# Ou exec no pod
kubectl exec -it <crivo-be-pod> -n devops-lab -- npm run migrate
```

## Monitoramento

### Métricas no Grafana

1. Acessar: http://grafana.devops.local
2. Dashboard → Kubernetes Pods
3. Filtrar por namespace: devops-lab

### Verificar Health

```bash
# Backend health check
curl http://develop-be.devops.local/health

# Ver métricas
curl http://develop-be.devops.local/metrics

# Frontend
curl -I http://develop-fe.devops.local

# Auth
curl http://develop-auth.devops.local/health/ready
```

### Logs

```bash
# Via kubectl
make logs SERVICE=crivo-be

# Ou
kubectl logs -n devops-lab -l app=crivo-be --follow

# No Kibana
# Query: kubernetes.namespace: "devops-lab"
```

## Troubleshooting

### App não sincroniza

```bash
# Ver detalhes
argocd app get crivo-be-local

# Ver diff
argocd app diff crivo-be-local

# Logs do sync
argocd app logs crivo-be-local

# Forçar refresh
argocd app get crivo-be-local --refresh
```

### Pod crashando

```bash
# Ver logs
kubectl logs -n devops-lab <pod> --previous

# Describe
kubectl describe pod -n devops-lab <pod>

# Events
kubectl get events -n devops-lab --sort-by='.lastTimestamp'
```

### Database connection failed

```bash
# Verificar se postgres está rodando
kubectl get pods -n devops-lab -l app.kubernetes.io/name=postgresql

# Testar conexão
kubectl run -it --rm psql --image=postgres:15 --restart=Never -- \
  psql -h postgres.devops-lab -U devops -d devops_db

# Verificar secret
kubectl get secret devops-secrets -n devops-lab -o yaml
```

## CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy-local.yml
name: Deploy to Local Lab

on:
  push:
    branches: [main]
    paths:
      - "apps/crivo-be/**"

jobs:
  deploy:
    runs-on: self-hosted # Runner no Mac local
    steps:
      - uses: actions/checkout@v3

      - name: Build Image
        run: |
          cd apps/crivo-be
          docker build -t ghcr.io/geraldobl58/crivo-be:${{ github.sha }} .
          docker tag ghcr.io/geraldobl58/crivo-be:${{ github.sha }} \
                     ghcr.io/geraldobl58/crivo-be:latest

      - name: Push Image
        run: |
          docker push ghcr.io/geraldobl58/crivo-be:${{ github.sha }}
          docker push ghcr.io/geraldobl58/crivo-be:latest

      - name: Update Helm Values
        run: |
          sed -i '' "s/tag: \".*\"/tag: \"${{ github.sha }}\"/" \
            local/helm/crivo-be/values-local.yaml
          git add local/helm/crivo-be/values-local.yaml
          git commit -m "chore: update crivo-be to ${{ github.sha }}"
          git push

      - name: Sync ArgoCD
        run: |
          argocd app sync crivo-be-local --force
```

## Próximos Passos

- [06 - Troubleshooting](./06-troubleshooting.md)
- [07 - Cheat Sheet](./07-cheatsheet.md)

---

**Anterior**: [03 - Observabilidade](./03-observability.md) | **Próximo**: [06 - Troubleshooting](./06-troubleshooting.md)
