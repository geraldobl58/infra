# Nexo CloudLab Ninja - Documentation

> Local Kubernetes development platform with 4 environments, GitOps, and full observability.

## Quick Start

```bash
# 1. Setup completo (cluster + ArgoCD + Prometheus + Grafana)
make setup

# 2. Verificar status
make status

# 3. Destruir tudo
make destroy
```

## Stack

| Component  | Tool                     | Purpose                  |
| ---------- | ------------------------ | ------------------------ |
| Cluster    | k3d (k3s in Docker)      | 1 server + 6 agents      |
| Ingress    | NGINX Ingress Controller | Routing + Load Balancing |
| GitOps     | ArgoCD                   | Continuous Deployment    |
| Monitoring | Prometheus + Grafana     | Metrics + Dashboards     |
| Alerting   | AlertManager             | Alert notification       |
| Auth       | Keycloak                 | Identity + SSO           |

## URLs

### Tools

| Service      | URL                            | Credentials                 |
| ------------ | ------------------------------ | --------------------------- |
| ArgoCD       | http://argocd.nexo.local       | `admin` / (run `make urls`) |
| Grafana      | http://grafana.nexo.local      | `admin` / `nexo@local2026`  |
| Prometheus   | http://prometheus.nexo.local   | —                           |
| AlertManager | http://alertmanager.nexo.local | —                           |

### Applications

| Env         | Frontend                     | Backend                      | Auth                           |
| ----------- | ---------------------------- | ---------------------------- | ------------------------------ |
| **Develop** | http://develop-fe.nexo.local | http://develop-be.nexo.local | http://develop-auth.nexo.local |
| **QA**      | http://qa-fe.nexo.local      | http://qa-be.nexo.local      | http://qa-auth.nexo.local      |
| **Staging** | http://staging-fe.nexo.local | http://staging-be.nexo.local | http://staging-auth.nexo.local |
| **Prod**    | http://fe.nexo.local         | http://be.nexo.local         | http://auth.nexo.local         |

## Make Commands

```
make setup         # Setup completo (primeira vez) - INTERATIVO
make start         # Iniciar cluster parado
make stop          # Parar cluster
make restart       # Reiniciar cluster
make destroy       # Destruir tudo - INTERATIVO
make status        # Status completo
make logs          # Logs: make logs SERVICE=nexo-be NAMESPACE=nexo-develop
make k9s           # Interface visual para K8s
make grafana       # Abrir Grafana no browser
make argocd        # Abrir ArgoCD no browser
```

## Git Flow → Environments

```
feature/* → develop → qa → staging → main
              ↓         ↓       ↓        ↓
          nexo-develop  nexo-qa  nexo-staging  nexo-prod
```

## CI/CD Pipeline

### Pipeline (pipeline.yml)

Trigger: Push/PR em `develop`, `qa`, `staging`, `main`

| Stage          | Descrição                           |
| -------------- | ----------------------------------- |
| AI Review      | Danger.js + CodeRabbit (apenas PRs) |
| Pre-flight     | Branch → Env mapping                |
| Detect Changes | Selective builds por serviço        |
| CI Backend     | lint, test, build                   |
| CI Frontend    | lint, build                         |
| CI Auth        | Dockerfile validation               |
| Build & Push   | Docker multi-arch → GHCR            |
| Deploy         | Atualiza Helm values → ArgoCD sync  |
| Notify         | Discord webhook                     |

### Release (release.yml)

Trigger: Criação de tags `v*.*.*`

```bash
# Criar uma release
git tag v1.0.0
git push --tags
```

| Stage          | Descrição                                          |
| -------------- | -------------------------------------------------- |
| Validate       | Extrai e valida versão semver                      |
| Build          | Docker multi-arch (amd64, arm64) todos os serviços |
| Update Helm    | Atualiza `values-prod.yaml` com tag de versão      |
| GitHub Release | Cria release com changelog automático              |
| Discord Notify | Notifica no canal do Discord                       |

Tags geradas: `v1.0.0`, `1.0` (major.minor), `latest`

Pre-releases: `v1.0.0-rc.1` (marcadas como pre-release no GitHub)

## Directory Structure

```
local/
├── Makefile                    # Comandos make (local)
├── setup.sh                   # Setup automatizado (interativo)
├── destroy.sh                 # Destroy interativo
├── status.sh                  # Status detalhado
├── create-ghcr-secrets.sh     # Criar secrets do GHCR
├── config/
│   ├── k3d-config.yaml        # Configuração do cluster
│   ├── secrets.example.yaml   # Template de secrets
│   └── storage-class.yaml     # StorageClass para SSD
├── helm/
│   ├── nexo-be/               # Helm chart: Backend (NestJS)
│   ├── nexo-fe/               # Helm chart: Frontend (Next.js)
│   └── nexo-auth/             # Helm chart: Auth (Keycloak)
├── argocd/
│   ├── projects/              # ArgoCD Projects (4 envs)
│   └── applicationsets/       # ApplicationSets (12 apps)
├── k8s/
│   ├── grafana-dashboard-nexo.yaml    # Dashboard: Overview
│   ├── grafana-dashboard-apps.yaml    # Dashboards: Backend, Frontend, Auth (por app)
│   └── servicemonitor-apps.yaml       # ServiceMonitors
└── docs/                      # ← Você está aqui
    ├── README.md              # Este arquivo
    ├── 01-installation.md     # Pré-requisitos e instalação
    ├── 02-architecture.md     # Arquitetura completa
    ├── 03-kubernetes.md       # Guia de Kubernetes/k3d
    ├── 04-argocd.md           # Guia do ArgoCD
    ├── 05-applications.md     # Deploy de aplicações
    ├── 06-observability.md    # Prometheus + Grafana + Alertas
    ├── 07-environments.md     # 4 ambientes e promoção
    ├── 08-troubleshooting.md  # Resolução de problemas
    └── 09-cheatsheet.md       # Referência de comandos
```

## Documentation Index

| #   | Document                                 | Description                                  |
| --- | ---------------------------------------- | -------------------------------------------- |
| 01  | [Installation](01-installation.md)       | Prerequisites, hardware, installation steps  |
| 02  | [Architecture](02-architecture.md)       | System design, components, diagrams          |
| 03  | [Kubernetes](03-kubernetes.md)           | k3d cluster, namespaces, networking, storage |
| 04  | [ArgoCD](04-argocd.md)                   | GitOps, sync policies, ApplicationSets       |
| 05  | [Applications](05-applications.md)       | Deploy workflow, Helm charts, rollbacks      |
| 06  | [Observability](06-observability.md)     | Prometheus, Grafana, alerts, dashboards      |
| 07  | [Environments](07-environments.md)       | 4 environments, promotion flow, GHCR secrets |
| 08  | [Troubleshooting](08-troubleshooting.md) | Common problems and solutions                |
| 09  | [Cheatsheet](09-cheatsheet.md)           | kubectl, k3d, ArgoCD, PromQL commands        |

## GHCR Setup (Private Images)

```bash
# 1. Set token in .env (root of project)
GITHUB_TOKEN=ghp_your_token_here

# 2. Create secrets in all namespaces
bash local/create-ghcr-secrets.sh
```

## Scripts Interativos

### `make setup` (setup.sh)

O setup é **interativo** — pede confirmação antes de iniciar:

```
Iniciar setup? (y/N): _
```

**Fluxo de execução (6 etapas):**

1. **Criar cluster k3d** — 1 server + 6 agents via `config/k3d-config.yaml`
2. **Criar namespaces** — nexo-develop, nexo-qa, nexo-staging, nexo-prod, monitoring, argocd
3. **Instalar ArgoCD** — Helm chart + Ingress em `argocd.nexo.local`
4. **Instalar observabilidade** — kube-prometheus-stack (Prometheus, Grafana, AlertManager)
5. **Configurar ArgoCD GitOps** — Aplica projects + ApplicationSets (12 apps)
6. **Configurar DNS local** — Adiciona 16 entradas em `/etc/hosts` (requer sudo)

Tempo estimado: **10-15 minutos**

Se o cluster já existe, o script pula a etapa 1 e continua.

### `make destroy` (destroy.sh)

O destroy é **interativo** com 2 confirmações:

```
1. Tem certeza que deseja continuar? (yes/N): _
   → Precisa digitar "yes" (não apenas "y")

2. Deseja remover os volumes também? (y/N): _
   → Remove /Volumes/Backup/nexo-cloudlab (dados do Prometheus, Grafana)
```

**O que é removido:**

- Cluster k3d e todos os pods
- Entradas do `/etc/hosts`
- Contexto do kubeconfig
- (Opcional) Volumes persistentes em SSD

**O que NÃO é removido:**

- Código fonte do repositório
- Configurações Helm (charts)
- Imagens Docker em cache

### `make status` (status.sh)

Não é interativo — apenas exibe informações. Verifica:

- Cluster e nodes (Ready/NotReady)
- Namespaces (6 esperados)
- ArgoCD (pods running + applications health/sync)
- Grafana, Prometheus, AlertManager
- Pods por ambiente (develop/qa/staging/prod)
