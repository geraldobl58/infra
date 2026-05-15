# Troubleshooting

## Application fica `OutOfSync` indefinidamente

Causa comum: o `spec.selector` do Deployment é imutável. Se você mudou
labels (`app.kubernetes.io/instance`, etc.) num chart já implantado, o
patch falha.

```bash
kubectl describe app <app-name> -n argocd | grep -A 2 "Message:"
# Procure por: 'Invalid value: ...selector: field is immutable'
```

**Solução**: apague o Deployment, Argo recria com as labels novas.

```bash
kubectl delete deploy <name> -n <namespace>
kubectl annotate app <app-name> -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

## Pod do `crivo-be` falha com `relation "public.Plan" does not exist`

Faltam migrations do Prisma. Hoje rodamos manualmente porque a imagem
runtime não inclui `prisma.config.ts` (corrigido no Dockerfile, mas
depende da próxima build no CI).

```bash
# port-forward pra rodar local apontando pro cluster
kubectl port-forward -n crivo-develop svc/postgres 5432:5432 &
cd ~/Development/fullstack/crivo/apps/crivo-be
DATABASE_URL='postgresql://crivo:crivo_password@127.0.0.1:5432/crivo_app?schema=public' \
  npx prisma migrate deploy
kill %1
```

Quando a imagem nova sair, reative o init container nos values:

```yaml
# helm/crivo-app/apps/crivo-be/values-<env>.yaml
initContainers:
  - name: prisma-migrate
    command: ["sh", "-c", "npx prisma migrate deploy"]
```

(O default em `apps/crivo-be/values.yaml` já habilita. Em `values-<env>.yaml`
hoje há `initContainers: []` desativando — basta remover essa linha.)

## Keycloak: `503 Service Temporarily Unavailable` no admin console

Causas comuns:
1. Pod ainda subindo (Keycloak 26 demora 1-2min no `start-dev`).
2. Probe configurado na porta errada (deve ser `management` = 9000, não `http` = 8080).
3. Conflito `KC_HOSTNAME` + `KC_HOSTNAME_URL` no env (use só `KC_HOSTNAME_URL`).

```bash
kubectl logs -n crivo-develop deploy/crivo-auth --tail=30
```

Procure por:
- `started in X.Xs` → tudo OK, é só esperar.
- `You can not set both 'hostname' and 'hostname-url'` → remover `KC_HOSTNAME` dos values.

## Pods em `ImagePullBackOff`

```bash
kubectl describe pod <pod> -n <ns> | grep -A 3 Failed
```

Possibilidades:

- **Tag não existe**: a tag que está em `values-<env>.yaml` não foi
  publicada no GHCR. Confirme em https://github.com/users/geraldobl58/packages
  ou rode o pipeline CI da branch correspondente.
- **Sem `ghcr-secret`**: rode `./create-ghcr-secrets.sh`.
- **GitHub token expirado**: gere um novo em
  https://github.com/settings/tokens, atualize `.env`, rode
  `./create-ghcr-secrets.sh`.

## Pod do Postgres em `Pending` com `persistentvolumeclaim "postgres-pvc" not found`

PVC não foi criado. Crie manualmente:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: crivo-prod
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 5Gi
EOF
```

## Pod do Postgres em `ContainerCreating` com `configmap "postgres-init" not found`

```bash
# Copia o configmap do ambiente que funciona
kubectl get cm postgres-init -n crivo-develop -o yaml | \
  yq eval 'del(.metadata.resourceVersion, .metadata.uid, .metadata.creationTimestamp, .metadata.managedFields) | .metadata.namespace = "crivo-prod"' - | \
  kubectl apply -f -

# Mata o pod pra recriar (kubelet cacheia o mount falho)
kubectl delete pod -n crivo-prod -l app=postgres
```

## App `Synced` mas `Degraded`

Pode ser readiness probe falhando. Confira:

```bash
kubectl describe app <name> -n argocd | grep -A 5 "Health:"
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
```

## /etc/hosts errado / 404 no browser mas curl com Host funciona

Cache de DNS do macOS pode ser teimoso:

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

E confirme que `/etc/hosts` tem só uma linha por host (sem duplicatas).

## Saber o que está em sync com o git agora

```bash
kubectl get app -n argocd -o custom-columns=\
NAME:.metadata.name,REV:.status.sync.revision,STATUS:.status.sync.status,HEALTH:.status.health.status
```

## Comparar values renderizado entre develop e prod

```bash
diff \
  <(make helm-template APP=crivo-be ENV=develop) \
  <(make helm-template APP=crivo-be ENV=prod)
```
