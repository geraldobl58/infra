# Aplicações

Hoje rodamos 3 aplicações Crivo. Cada uma é uma pasta em
`helm/crivo-app/apps/<app>/`, contendo um `values.yaml` (defaults da app) e
um `values-<env>.yaml` por ambiente.

## Inventário

| App          | Image                              | Porta | Health           | Stack       |
| ------------ | ---------------------------------- | ----- | ---------------- | ----------- |
| `crivo-auth` | `quay.io/keycloak/keycloak:26.0.7` | 8080 + 9000 mgmt | `/health/ready` (9000) | Keycloak 26 |
| `crivo-be`   | `ghcr.io/geraldobl58/crivo-be`     | 3000  | `/health`        | NestJS + Prisma |
| `crivo-fe`   | `ghcr.io/geraldobl58/crivo-fe`     | 3000  | `/`              | Next.js     |

## Padrão de configuração

Cada app expõe apenas variáveis públicas no `values.yaml`. Tudo sensível
vem por `envFrom` referenciando Kubernetes Secrets criados pelo
`create-app-secrets.sh`.

### crivo-be

- Conecta ao Keycloak via 2 URLs:
  - **`KEYCLOAK_BASE_URL`** / **`KEYCLOAK_ISSUER`** / **`KEYCLOAK_JWKS_URI`**: usa o host **externo**
    (`http://develop.auth.crivo.local`) porque o token precisa bater com o `iss`
    do JWT emitido pro frontend. Isso só funciona dentro do pod porque
    declaramos `hostAliases` apontando esse hostname pro IP do ingress.
  - **`KEYCLOAK_INTERNAL_URL`**: usa o Service ClusterIP
    (`http://crivo-auth.crivo-develop.svc.cluster.local:8080`) para chamadas
    server-to-server que não passam pelo ingress.
- Usa Prisma. Migrations rodam via `prisma migrate deploy`. Hoje rodamos
  manualmente; quando a imagem incluir `prisma.config.ts` + `tsconfig.json`,
  reativamos o `initContainer` em `apps/crivo-be/values.yaml`.

### crivo-fe

- Next.js com Better Auth.
- Variáveis `NEXT_PUBLIC_*` apontam para os hosts **externos**.
- `API_URL` (server-side fetch) também usa host externo em develop e
  Service interno em prod (`crivo-be.crivo-prod.svc.cluster.local:3000`).

### crivo-auth

- Keycloak em modo `start-dev` (apropriado pro lab; em prod-prod real
  usaria `start --optimized`).
- **Probes** apontam para a porta de management (`9000`), não a HTTP (`8080`),
  porque o Keycloak 26 não expõe `/health/*` na porta HTTP.
- Tema custom (Nexo) montado via ConfigMap em `develop` (opcional, montagem
  marcada como `optional: true`).

## Banco de dados

Cada ambiente tem seu próprio Postgres dentro do cluster, no mesmo namespace
da app. Os bancos são criados pelo `init-databases.sh` que vira ConfigMap
`postgres-init`:

| Banco               | Owner | Quem usa                |
| ------------------- | ----- | ----------------------- |
| `crivo_app`         | crivo | `crivo-be` (Prisma)     |
| `crivo_keycloak`    | crivo | `crivo-auth` (Keycloak) |
| `crivo_better_auth` | crivo | `crivo-fe` (Better Auth)|

## Imagens e tags

CI publica nas tags:

- `develop` → ambiente `develop`
- `develop-<sha>` → tag versionada por commit

Em prod, hoje usamos a tag `develop` enquanto o pipeline não cria uma
tag `main`/semver. Quando criar, ajuste `values-prod.yaml`.

## Onde fica a config

```
helm/crivo-app/
└── apps/
    ├── crivo-auth/
    │   ├── values.yaml          # defaults (Keycloak args, probes, etc.)
    │   ├── values-develop.yaml  # KC_HOSTNAME_URL, tema Nexo
    │   └── values-prod.yaml     # KC_HOSTNAME_URL, PDB
    ├── crivo-be/
    │   ├── values.yaml          # env público, envFrom secrets
    │   ├── values-develop.yaml  # KEYCLOAK_*, DATABASE_URL via secret
    │   └── values-prod.yaml
    └── crivo-fe/
        └── ...
```

## Acompanhar / debugar uma app

```bash
# Status de uma app
kubectl get app crivo-be-develop -n argocd -o jsonpath='{.status.sync.status}/{.status.health.status}'

# Logs (todos os pods do app)
make logs SERVICE=crivo-be NAMESPACE=crivo-develop

# Renderizar o Helm sem aplicar (debug)
make helm-template APP=crivo-be ENV=develop | less

# Force-sync uma app
kubectl annotate app crivo-be-develop -n argocd argocd.argoproj.io/refresh=hard --overwrite
```
