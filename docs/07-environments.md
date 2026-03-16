# 🌍 Ambientes CloudLab Local

## Visão Geral

O CloudLab Nexo possui **4 ambientes** completos rodando localmente:

| Ambiente   | Branch    | Namespace      | URL Base                          | Auto-Deploy |
| ---------- | --------- | -------------- | --------------------------------- | ----------- |
| Develop    | `develop` | `nexo-develop` | `develop-{fe,be,auth}.nexo.local` | ✅ Sim      |
| QA         | `qa`      | `nexo-qa`      | `qa-{fe,be,auth}.nexo.local`      | ✅ Sim      |
| Staging    | `staging` | `nexo-staging` | `staging-{fe,be,auth}.nexo.local` | ✅ Sim      |
| Production | `main`    | `nexo-prod`    | `{fe,be,auth}.nexo.local`         | ✅ Sim      |

> 💡 **100% LOCAL:** Todos os ambientes rodam em k3d no seu Mac, sem dependências de cloud.

---

## 📋 Detalhamento dos Ambientes

### 🔧 Develop (Desenvolvimento)

**Branch:** `develop` (default)  
**Namespace:** `nexo-develop`  
**Propósito:** Integração contínua de features

#### URLs:

- **Frontend:** http://develop-fe.nexo.local
- **Backend API:** http://develop-be.nexo.local
- **Auth (Keycloak):** http://develop-auth.nexo.local

#### Características:

- ✅ Auto-deploy ao fazer push
- ✅ Swagger habilitado
- ✅ Log level: `debug`
- ✅ Hot-reload para Auth (start-dev)
- ✅ NODE_ENV: `development`
- ⚠️ Não usar para demos ou testes importantes

#### Quando usar:

```bash
# Criar feature branch
git checkout -b feature/nova-feature

# Desenvolver e testar localmente
# ...

# Fazer PR para develop
git push origin feature/nova-feature
# Criar PR no GitHub: feature/nova-feature → develop

# Após merge, deploy automático para develop
```

---

### 🧪 QA (Quality Assurance)

**Branch:** `qa`  
**Namespace:** `nexo-qa`  
**Propósito:** Testes de qualidade e validações do QA team

#### URLs:

- **Frontend:** http://qa-fe.nexo.local
- **Backend API:** http://qa-be.nexo.local
- **Auth (Keycloak):** http://qa-auth.nexo.local

#### Características:

- ✅ Auto-deploy ao fazer push
- ✅ Swagger habilitado
- ✅ Log level: `info`
- ✅ Keycloak em dev mode (`start-dev`)
- ✅ NODE_ENV: `production`
- ✅ Ambiente estável para testes

#### Quando usar:

```bash
# Após features testadas em develop, promover para QA
git checkout qa
git merge develop
git push origin qa

# QA team testa features integradas
# Se bugs encontrados, fix em develop e merge novamente
```

#### Testes recomendados:

- 🧪 Testes funcionais
- 🧪 Testes de integração
- 🧪 Testes de regressão
- 🧪 Validação de regras de negócio

---

### 🎭 Staging (Homologação)

**Branch:** `staging`  
**Namespace:** `nexo-staging`  
**Propósito:** Ambiente espelho de produção para testes finais

#### URLs:

- **Frontend:** http://staging-fe.nexo.local
- **Backend API:** http://staging-be.nexo.local
- **Auth (Keycloak):** http://staging-auth.nexo.local

#### Características:

- ✅ Auto-deploy ao fazer push
- ✅ Swagger habilitado
- ✅ Log level: `info`
- ✅ Keycloak em dev mode (`start-dev`)
- ✅ NODE_ENV: `production`
- ✅ Ambiente para testes de aceite (UAT)

#### Quando usar:

```bash
# Após QA aprovar, promover para staging
git checkout staging
git merge qa
git push origin staging

# Stakeholders testam e homologam
# Testes de performance e carga
# Aprovação final para produção
```

#### Testes recomendados:

- 🎯 User Acceptance Testing (UAT)
- 🎯 Testes de performance
- 🎯 Testes de carga
- 🎯 Smoke tests
- 🎯 Aprovação de stakeholders

---

### 🚀 Production (Produção)

**Branch:** `main`  
**Namespace:** `nexo-prod`  
**Propósito:** Ambiente de produção (simulado localmente)

#### URLs:

- **Frontend:** http://fe.nexo.local
- **Backend API:** http://be.nexo.local
- **Auth (Keycloak):** http://auth.nexo.local

#### Características:

- ✅ Auto-deploy ao fazer push (se necessário, pode ser manual)
- ✅ Swagger habilitado
- ✅ Log level: `info`
- ✅ Alta disponibilidade
- ✅ NODE_ENV: `production`
- ⚠️ Deploy apenas após aprovação em staging

#### Quando usar:

```bash
# Após aprovação final em staging, promover para produção
git checkout main
git merge staging
git push origin main

# OU criar release tag
git tag v1.0.0
git push origin v1.0.0
```

#### Monitoramento:

- 📊 Grafana: http://grafana.nexo.local
- 📊 Prometheus: http://prometheus.nexo.local
- 📊 AlertManager: http://alertmanager.nexo.local

---

## 🔄 Fluxo de Promoção entre Ambientes

### Fluxo Normal (Feature → Production)

```
1. Feature Branch
   ↓ PR + Merge
2. Develop (nexo-develop)
   ↓ Merge após testes iniciais
3. QA (nexo-qa)
   ↓ Merge após testes de qualidade
4. Staging (nexo-staging)
   ↓ Merge após homologação
5. Production (nexo-prod)
```

### Comandos Git para Promoção

```bash
# Develop → QA
git checkout qa
git merge develop
git push origin qa

# QA → Staging
git checkout staging
git merge qa
git push origin staging

# Staging → Production
git checkout main
git merge staging
git push origin main
```

### Rollback Rápido

Se houver problema em produção:

```bash
# Opção 1: Reverter commit problemático
git checkout main
git revert <commit-sha>
git push origin main

# Opção 2: Usar release tag anterior
# No ArgoCD UI:
# Applications → nexo-{service}-prod →
# APP DETAILS → Sync → Revision: v1.0.0 (tag anterior)
```

---

## 🎯 Estratégias de Deploy

### Deploy por Ambiente

| Ambiente   | Estratégia         | Aprovação    | Rollback  |
| ---------- | ------------------ | ------------ | --------- |
| Develop    | Automático (push)  | Não          | Rápido    |
| QA         | Automático (merge) | Dev Team     | Rápido    |
| Staging    | Automático (merge) | QA Team      | Médio     |
| Production | Automático ou Tag  | Stakeholders | Cauteloso |

### Hotfix em Produção

Para correções urgentes em produção:

```bash
# Criar hotfix branch a partir de main
git checkout main
git checkout -b hotfix/critical-bug

# Fazer fix
git add .
git commit -m "hotfix: corrige bug crítico X"

# Merge direto em main
git checkout main
git merge hotfix/critical-bug
git push origin main

# Deploy automático para produção

# NÃO ESQUECER: Fazer backmerge para outras branches
git checkout staging
git merge main
git push origin staging

git checkout qa
git merge staging
git push origin qa

git checkout develop
git merge qa
git push origin develop
```

---

## 📊 Recursos por Ambiente

### Limites de Recursos

Todos os ambientes compartilham os mesmos limites (ambiente de estudos):

| Serviço   | CPU Limit | Memory Limit | CPU Request | Memory Request |
| --------- | --------- | ------------ | ----------- | -------------- |
| nexo-be   | 200m      | 256Mi        | 10m         | 64Mi           |
| nexo-fe   | 200m      | 256Mi        | 10m         | 64Mi           |
| nexo-auth | 400m      | 768Mi        | 10m         | 128Mi          |

### Réplicas

Todos os ambientes: `replicaCount: 1`

> 💡 **Nota:** Em ambiente de produção real, considere:
>
> - Produção: 3+ réplicas com PodDisruptionBudget
> - Staging: 2 réplicas
> - QA: 1 réplica
> - Develop: 1 réplica

---

## 🔐 Secrets por Ambiente

Cada ambiente possui seus próprios secrets:

```bash
# Listar secrets
kubectl get secrets -n nexo-develop
kubectl get secrets -n nexo-qa
kubectl get secrets -n nexo-staging
kubectl get secrets -n nexo-prod

# Secrets comuns em todos:
# - ghcr-secret (pull images do GitHub Container Registry)
# - postgres-secret (conexão com banco de dados)
# - keycloak-secret (admin credentials do Keycloak)
```

### Criar secrets para novo ambiente

```bash
# Exemplo para QA
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=geraldobl58 \
  --docker-password=$GITHUB_TOKEN \
  -n nexo-qa

kubectl create secret generic postgres-secret \
  --from-literal=host=postgres-qa.internal \
  --from-literal=password=qa-pass \
  -n nexo-qa
```

---

## 📈 Monitoramento por Ambiente

### ServiceMonitors (Prometheus)

Cada ambiente tem seus próprios ServiceMonitors:

- `nexo-be-develop` → `http://nexo-be-develop:3000/metrics`
- `nexo-be-qa` → `http://nexo-be-qa:3000/metrics`
- `nexo-be-staging` → `http://nexo-be-staging:3000/metrics`
- `nexo-be-prod` → `http://nexo-be-prod:3000/metrics`

### Grafana Dashboards

Acesse Grafana e filtre por namespace:

```
http://grafana.nexo.local
Login: admin / nexo@local2026

# No dashboard, filtrar por:
- namespace: nexo-develop
- namespace: nexo-qa
- namespace: nexo-staging
- namespace: nexo-prod
```

---

## ✅ Checklist de Deploy

### Antes de promover para QA:

- [ ] Todas as features testadas localmente
- [ ] CI passou em develop
- [ ] Code review aprovado
- [ ] Migrations rodaram sem erros

### Antes de promover para Staging:

- [ ] QA team aprovou testes funcionais
- [ ] Testes de regressão passaram
- [ ] Performance aceitável
- [ ] Logs sem erros críticos

### Antes de promover para Production:

- [ ] Stakeholders homologaram em staging
- [ ] Testes de carga bem-sucedidos
- [ ] Smoke tests passaram
- [ ] Plano de rollback definido
- [ ] Comunicação enviada aos usuários (se necessário)
- [ ] Monitoramento configurado

---

## 🎯 Resumo dos Comandos

```bash
# Ver todos os ambientes
kubectl get namespaces | grep nexo

# Ver apps em cada ambiente
kubectl get pods -n nexo-develop
kubectl get pods -n nexo-qa
kubectl get pods -n nexo-staging
kubectl get pods -n nexo-prod

# Ver deployments do ArgoCD
kubectl get applications -n argocd | grep nexo

# Ver projetos do ArgoCD
kubectl get appproject -n argocd

# Forçar sync de um app
argocd app sync nexo-be-qa
argocd app sync nexo-fe-staging
```

---

**4 ambientes completos para desenvolvimento seguro e confiável! 🚀**
