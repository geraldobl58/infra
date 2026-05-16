# Crivo Infra

Plataforma local de desenvolvimento Kubernetes com GitOps (ArgoCD) e
observabilidade (Prometheus + Grafana), focada em rodar as 3 apps Crivo
(`crivo-auth`, `crivo-be`, `crivo-fe`) em 2 ambientes (`develop`, `prod`).

## Conceitos

A infra foi desenhada para responder duas perguntas com uma resposta só:

1. **Como adiciono um app novo?** — copie um diretório em
   `helm/crivo-app/apps/`, ajuste 3 arquivos de values, adicione o nome do
   app na lista do ApplicationSet. Sem novo chart, sem novo template.
2. **Como adiciono um ambiente novo?** — adicione um `{env, branch}` na
   lista do ApplicationSet e crie um AppProject. Tudo o mais é derivado.

## Arquitetura

```
helm/crivo-app/                         ← chart genérico único
├── Chart.yaml
├── values.yaml                         ← defaults
├── templates/                          ← deployment, service, ingress, hpa, pdb
└── apps/
    ├── crivo-auth/
    │   ├── values.yaml                 ← config comum ao app
    │   ├── values-develop.yaml         ← overrides do ambiente
    │   └── values-prod.yaml
    ├── crivo-be/...
    └── crivo-fe/...

argocd/
├── projects/crivo-environments.yaml    ← 1 AppProject por ambiente
└── applicationsets/crivo-apps.yaml     ← 1 ApplicationSet (matrix env × app)

config/
├── secrets.develop.env                 ← gitignored, gerado de .example
├── secrets.prod.env                    ← gitignored
└── ...

scripts/
├── create-app-secrets.sh               ← gera todos os Secrets de um ambiente
└── ...
```

## Stack

| Componente   | Ferramenta               |
| ------------ | ------------------------ |
| Cluster      | k3d (k3s no Docker)      |
| Ingress      | NGINX Ingress Controller |
| GitOps       | ArgoCD                   |
| Observ.      | Prometheus + Grafana     |
| Identity     | Keycloak 26              |
| Container DB | PostgreSQL 16            |

## URLs

### Ferramentas

| Serviço      | URL                              |
| ------------ | -------------------------------- |
| ArgoCD       | http://argocd.devops.local       |
| Grafana      | http://grafana.devops.local      |
| Prometheus   | http://prometheus.devops.local   |
| AlertManager | http://alertmanager.devops.local |

### Apps

| Ambiente | Frontend                      | API Gateway (Kong)            | Backend (direto)              | Auth                            |
| -------- | ----------------------------- | ----------------------------- | ----------------------------- | ------------------------------- |
| develop  | http://develop.fe.crivo.local | http://develop.api.crivo.local | http://develop.be.crivo.local | http://develop.auth.crivo.local |
| prod     | http://prod.fe.crivo.local    | http://prod.api.crivo.local    | http://prod.be.crivo.local    | http://prod.auth.crivo.local    |

O browser fala com o **Frontend** e com a **API via Kong** (que faz JWT
validation, rate limiting por plano, CORS centralizado). O Backend direto
existe apenas pra debug — o FE em prod nunca o usa.

Adicionar entradas no `/etc/hosts` é parte do `make setup`.

## Setup do zero

```bash
# 1. Cria o cluster, ArgoCD, observabilidade, namespaces, Postgres em cada env.
make setup

# 2. Prepara secrets de cada ambiente. Cada um precisa do seu .env:
cp config/secrets.develop.env.example config/secrets.develop.env
$EDITOR config/secrets.develop.env        # preencher valores reais
make secrets ENV=develop

cp config/secrets.prod.env.example config/secrets.prod.env
$EDITOR config/secrets.prod.env
make secrets ENV=prod

# 3. ArgoCD sincroniza Apps automaticamente. Aguarde Keycloak subir
#    (1-2min). Importe o realm:
make import-realm ENV=develop FILE=path/to/realm.json
make import-realm ENV=prod    FILE=path/to/realm.json

# 4. Rode migrations + seed do BE:
make migrate ENV=develop
make seed    ENV=develop
make migrate ENV=prod
make seed    ENV=prod

# 5. Aplique a config do Kong (busca a chave RS256 do realm
#    automaticamente):
make kong-config ENV=develop
make kong-config ENV=prod

# 6. Status:
make status
make argocd        # abre UI
```

## Adicionar um app novo

Suponha o app `crivo-billing`.

```bash
mkdir -p helm/crivo-app/apps/crivo-billing
cp helm/crivo-app/apps/crivo-be/values.yaml         helm/crivo-app/apps/crivo-billing/
cp helm/crivo-app/apps/crivo-be/values-develop.yaml helm/crivo-app/apps/crivo-billing/
cp helm/crivo-app/apps/crivo-be/values-prod.yaml    helm/crivo-app/apps/crivo-billing/
# Edite cada arquivo: nome, image.repository, env, host, envFrom secrets.
```

Adicione na lista de apps em [`argocd/applicationsets/crivo-apps.yaml`](../argocd/applicationsets/crivo-apps.yaml):

```yaml
- app: crivo-billing
```

Faça commit + push. ArgoCD cria `crivo-billing-develop` e `crivo-billing-prod`.

## Adicionar um ambiente novo

Suponha `staging`.

1. Crie a branch `staging` no GitHub.
2. Adicione em [`argocd/applicationsets/crivo-apps.yaml`](../argocd/applicationsets/crivo-apps.yaml):
   ```yaml
   - env: staging
     branch: staging
   ```
3. Adicione em [`argocd/projects/crivo-environments.yaml`](../argocd/projects/crivo-environments.yaml) um novo `AppProject` chamado `crivo-staging`.
4. Crie `helm/crivo-app/apps/<app>/values-staging.yaml` para cada app.
5. Crie `config/secrets.staging.env` e rode `make secrets ENV=staging`.

## Secrets

Tudo sensível mora em Kubernetes Secrets criados via `scripts/create-app-secrets.sh`.
Os charts referenciam por `envFrom: [{ secretRef: <nome> }]`.

| Secret                | Conteúdo                                                 |
| --------------------- | -------------------------------------------------------- |
| `crivo-auth-admin`    | `KC_BOOTSTRAP_ADMIN_USERNAME`, `KC_BOOTSTRAP_ADMIN_PASSWORD` |
| `crivo-auth-db`       | `KC_DB_URL`, `KC_DB_USERNAME`, `KC_DB_PASSWORD`          |
| `crivo-be-app`        | `DATABASE_URL`, `KEYCLOAK_CLIENT_SECRET`, `BETTER_AUTH_SECRET` |
| `crivo-be-cloudinary` | `CLOUDINARY_*`                                           |
| `crivo-be-stripe`     | `STRIPE_*`                                               |
| `crivo-be-mail`       | `MAILTRAP_*`                                             |
| `crivo-be-ai`         | `ANTHROPIC_API_KEY`                                      |
| `crivo-be-storage`    | `AWS_*`, `S3_BUCKET`                                     |
| `crivo-fe-auth`       | `BETTER_AUTH_SECRET`                                     |
| `ghcr-secret`         | docker-registry, criado por `create-ghcr-secrets.sh`     |

## Make targets

```
make setup           # primeiro setup (cluster + observabilidade + projects)
make secrets ENV=develop   # aplica/atualiza Secrets de um ambiente
make apply-argocd    # (re)aplica AppProjects e ApplicationSet
make helm-lint       # valida o chart contra todos os values
make helm-template APP=crivo-be ENV=develop   # renderiza pra inspecionar
make logs SERVICE=crivo-be NAMESPACE=crivo-develop
make status
make destroy
```

## Git flow

```
feature/* → develop → main
              ↓         ↓
        crivo-develop  crivo-prod
```

Os ApplicationSets sincronizam:
- branch `develop` → ambiente `crivo-develop`
- branch `main`    → ambiente `crivo-prod`

## Próxima leitura

- [01-installation.md](01-installation.md) – Pré-requisitos e setup do zero
- [02-architecture.md](02-architecture.md) – Arquitetura e decisões
- [04-argocd.md](04-argocd.md) – ApplicationSet + AppProjects
- [05-applications.md](05-applications.md) – Como cada app está modelada
- [07-environments.md](07-environments.md) – Multi-env e como adicionar um novo
- [08-troubleshooting.md](08-troubleshooting.md) – Problemas comuns + soluções
- [09-cheatsheet.md](09-cheatsheet.md) – Atalhos do dia-a-dia
