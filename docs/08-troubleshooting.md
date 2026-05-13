# 🚨 Troubleshooting Guide - DevOps Lab

Guia de solução de problemas comuns no Lab.

## Script Automático

```bash
# Rodar diagnóstico completo
./scripts/troubleshoot.sh

# Ou via Make
make troubleshoot
```

## Problemas Comuns

### 1. Cluster não inicia

#### Sintoma

```bash
k3d cluster create --config config/k3d-config.yaml
# Error: ...
```

#### Soluções

**Docker não está rodando**

```bash
# Verificar
docker info

# Solução
open -a Docker
# Aguardar Docker iniciar
```

**Porta já em uso**

```bash
# Ver o que está usando as portas
lsof -i :80
lsof -i :443

# Matar processo
kill -9 <PID>

# Ou usar portas diferentes em k3d-config.yaml
```

**SSD não montado**

```bash
# Verificar
ls -la /Volumes/Backup

# Se não existir, montar o disco ou criar diretório local
mkdir -p ~/devops-lab-storage
# Editar config/k3d-config.yaml para usar ~/devops-lab-storage
```

### 2. Pods em CrashLoopBackOff

#### Sintoma

```bash
kubectl get pods -A
# NAME              STATUS             RESTARTS
# my-pod-xxx        CrashLoopBackOff   5
```

#### Debug

```bash
# Ver logs atuais
kubectl logs <pod> -n <namespace>

# Ver logs do container anterior
kubectl logs <pod> -n <namespace> --previous

# Describe para ver eventos
kubectl describe pod <pod> -n <namespace>

# Ver eventos do namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

#### Causas Comuns

**Image Pull Error**

```bash
# Sintoma: ImagePullBackOff

# Verificar
kubectl describe pod <pod> -n <namespace> | grep -A 5 "Events:"

# Soluções:
# 1. Verificar se imagem existe
docker pull <image>

# 2. Verificar imagePullSecrets
kubectl get deployment <name> -n <namespace> -o yaml | grep imagePullSecrets

# 3. Criar secret se necessário
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=<user> \
  --docker-password=<token> \
  -n <namespace>
```

**Falta de Recursos**

```bash
# Sintoma: Insufficient memory/cpu

# Ver recursos disponíveis
kubectl describe node | grep -A 5 "Allocated resources"

# Soluções:
# 1. Reduzir resources do pod
# 2. Aumentar recursos do Docker Desktop (Settings → Resources)
# 3. Deletar pods não usados
kubectl delete pod <pod> -n <namespace>
```

**ConfigMap/Secret não existe**

```bash
# Sintoma: Error: couldn't find key X in ConfigMap

# Verificar
kubectl get configmap -n <namespace>
kubectl get secret -n <namespace>

# Criar se necessário
kubectl create configmap <name> --from-literal=key=value -n <namespace>
kubectl create secret generic <name> --from-literal=key=value -n <namespace>
```

### 3. Ingress não funciona

#### Sintoma

```bash
curl http://develop-be.devops.local
# Connection refused / 404
```

#### Debug

```bash
# Verificar Ingress Controller
kubectl get pods -n ingress-nginx

# Ver logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Ver ingresses
kubectl get ingress -A

# Describe ingress
kubectl describe ingress <name> -n <namespace>
```

#### Soluções

**Ingress Controller não está rodando**

```bash
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

**DNS não configurado**

```bash
# Verificar /etc/hosts
cat /etc/hosts | grep local.devops.dev

# Adicionar se não existir
echo "127.0.0.1 develop-be.devops.local" | sudo tee -a /etc/hosts
```

**Service não existe**

```bash
# Ver services
kubectl get svc -n <namespace>

# Se não existir, verificar deployment
kubectl get deployment -n <namespace>
```

### 4. ArgoCD não sincroniza

#### Sintoma

```bash
argocd app get myapp
# Status: OutOfSync
# Sync: Failed
```

#### Debug

```bash
# Ver detalhes do erro
argocd app get myapp

# Ver logs do sync
argocd app logs myapp

# Ver diff
argocd app diff myapp

# Ver eventos
kubectl get events -n argocd --sort-by='.lastTimestamp'
```

#### Soluções

**Erro de sintaxe no YAML**

```bash
# Validar manifesto localmente
helm template ./chart --debug

# Ou
kubectl apply --dry-run=client -f manifest.yaml
```

**Repo não acessível**

```bash
# Verificar repo
argocd repo list

# Adicionar credenciais se necessário
argocd repo add https://github.com/user/repo \
  --username <user> \
  --password <token>
```

**Path não existe**

```bash
# Verificar path no repo
git clone <repo>
ls -la <path>

# Corrigir Application
kubectl edit application myapp -n argocd
```

### 5. Prometheus sem métricas

#### Sintoma

```
Grafana: No data
Prometheus: Target down
```

#### Debug

```bash
# Ver targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Acessar: http://localhost:9090/targets

# Ver ServiceMonitors
kubectl get servicemonitor -n monitoring

# Ver logs do Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

#### Soluções

**ServiceMonitor não tem label correto**

```yaml
# ServiceMonitor precisa ter:
metadata:
  labels:
    release: kube-prometheus-stack
```

**Service não expõe /metrics**

```bash
# Testar diretamente
kubectl port-forward -n <namespace> svc/<service> 8080:8080
curl http://localhost:8080/metrics
```

**Namespace não está sendo monitorado**

```yaml
# Verificar namespaceSelector no ServiceMonitor
spec:
  namespaceSelector:
    matchNames:
      - <namespace>
```

### 7. Pods Pending

#### Sintoma

```bash
kubectl get pods
# NAME         STATUS    RESTARTS
# my-pod-xxx   Pending   0
```

#### Debug

```bash
kubectl describe pod <pod> -n <namespace>
# Ver seção "Events:"
```

#### Causas

**Insufficient CPU/Memory**

```bash
# Ver recursos disponíveis
kubectl top nodes

# Soluções:
# 1. Deletar pods não usados
# 2. Reduzir resources.requests
# 3. Aumentar recursos do cluster
```

**Volume não pode ser montado**

```bash
# Ver PVC
kubectl get pvc -n <namespace>

# Se Pending, verificar StorageClass
kubectl get storageclass

# Ver events do PVC
kubectl describe pvc <pvc-name> -n <namespace>
```

**Node selector não matched**

```bash
# Ver node labels
kubectl get nodes --show-labels

# Remover nodeSelector ou adicionar label ao node
kubectl label node <node> <key>=<value>
```

### 8. Out of Memory

#### Sintoma

```bash
kubectl get pods
# NAME         STATUS    RESTARTS
# my-pod-xxx   OOMKilled 5
```

#### Soluções

```yaml
# Aumentar memory limit
resources:
  limits:
    memory: 1Gi # Era 512Mi
  requests:
    memory: 512Mi
```

```bash
# Ver uso de memória
kubectl top pods -n <namespace>

# Ver histórico no Grafana
# Dashboard → Kubernetes Pods → Memory Usage
```

### 9. Network Policies bloqueando

#### Sintoma

```
Pods não conseguem comunicar
Timeout ao chamar services
```

#### Debug

```bash
# Ver network policies
kubectl get networkpolicies -A

# Describe
kubectl describe networkpolicy <name> -n <namespace>

# Testar conectividade
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash
# Dentro do pod:
curl http://service-name.namespace:port
```

#### Solução

```bash
# Deletar policy temporariamente
kubectl delete networkpolicy <name> -n <namespace>

# Ou corrigir policy para permitir tráfego
```

### 10. Certificate/TLS Issues

#### Sintoma

```
x509: certificate signed by unknown authority
```

#### Para ambiente local

```yaml
# Desabilitar TLS verificatio em ingress
ingress:
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
```

### 11. Keycloak / Auth Issues

#### Sintoma: "Web Crypto API is not available"

O frontend exibe erro no console:

```
Web Crypto API is not available
```

#### Causa

O `keycloak-js` foi configurado com `pkceMethod: "S256"`, que utiliza a Web Crypto API (`crypto.subtle`). Essa API só está disponível em **secure contexts** (HTTPS ou localhost). Como o Lab usa HTTP com domínios `.devops.local`, o browser bloqueia o acesso.

#### Solução

Remover `pkceMethod: "S256"` do `keycloak.init()` em `auth-provider.tsx`:

```typescript
// ❌ Não funciona em HTTP
keycloak.init({ onLoad: "check-sso", pkceMethod: "S256" });

// ✅ Funciona em HTTP
keycloak.init({ onLoad: "check-sso" });
```

> **Nota:** Em produção com HTTPS real, pode-se reativar PKCE S256 para maior segurança.

#### Sintoma: Keycloak 503 Service Temporarily Unavailable

O Keycloak retorna 503 durante o startup. Isso é **normal** — o Keycloak leva 2-4 minutos para inicializar completamente.

#### Solução

```bash
# Verificar se o pod está rodando
kubectl get pods -n crivo-develop -l app=crivo-auth

# Aguardar readiness probe (180-240s initial delay)
kubectl wait --for=condition=ready pod -l app=crivo-auth -n crivo-develop --timeout=300s

# Testar endpoint
curl -s -o /dev/null -w "%{http_code}" http://develop-auth.devops.local/realms/master
```

#### Sintoma: Keycloak em loop de restart (QA/Staging)

Se o Keycloak em QA/staging fica em CrashLoopBackOff, verifique se está usando `start-dev` e não `start`:

```yaml
# values-qa.yaml / values-staging.yaml
keycloak:
  args: "start-dev" # ✅ Dev mode (mais rápido, sem build otimizado)
  # args: "start"    # ❌ Production mode (requer configurações extras)
```

#### Sintoma: Keycloak "HTTPS required" (Docker Compose)

Ao acessar `http://localhost:8080/admin/`, o Keycloak exibe "We are sorry... HTTPS required".

#### Causa

Dados antigos do Keycloak com `sslRequired=EXTERNAL` nos realms, ou falta de configuração HTTP.

#### Solução

1. Limpar dados antigos e reiniciar:

```bash
docker compose down -v
docker compose up -d
```

2. Garantir que o `docker-compose.yml` tenha as env vars corretas:

```yaml
environment:
  KC_HTTP_ENABLED: "true"
  KC_HOSTNAME: "http://localhost:8080"
  KC_HOSTNAME_STRICT: "false"
  KC_PROXY_HEADERS: "xforwarded"
```

### 12. Docker Compose - PostgreSQL no SSD Externo

#### Sintoma: "dependency postgres failed to start" / container unhealthy

```
Container devops-postgres-dev  Error dependency postgres failed to start
```

#### Causa

O SSD externo (exFAT/HFS+) cria resource forks do macOS (`._*` files) nos bind mounts diretos. O PostgreSQL não consegue ler esses arquivos e falha no startup.

#### Solução

Usar Docker named volumes com driver local (bind) ao invés de bind mounts diretos:

```yaml
# ✅ Named volume com driver local (evita ._* files)
volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /Volumes/Backup/devops-lab/data/postgres

# ❌ Bind mount direto no SSD (cria ._* files)
volumes:
  - /Volumes/Backup/devops-lab/data/postgres:/var/lib/postgresql/data
```

Se o problema persistir, limpar os dados e reiniciar:

```bash
rm -rf /Volumes/Backup/devops-lab/data/postgres
mkdir -p /Volumes/Backup/devops-lab/data/postgres
docker compose down -v
docker compose up -d
```

---

## Comandos de Emergência

### Restart Everything

```bash
# Restart todos pods de um namespace
kubectl delete pods --all -n <namespace>

# Restart deployment
kubectl rollout restart deployment <name> -n <namespace>

# Restart daemonset
kubectl rollout restart daemonset <name> -n <namespace>
```

### Force Delete

```bash
# Deletar pod travado
kubectl delete pod <pod> -n <namespace> --force --grace-period=0

# Remover finalizers
kubectl patch pod <pod> -n <namespace> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Clean Cluster

```bash
# Deletar pods failed/completed
kubectl delete pods --field-selector=status.phase=Failed -A
kubectl delete pods --field-selector=status.phase=Succeeded -A

# Limpar Docker
docker system prune -a
```

### Nuclear Option

```bash
# Deletar tudo e recomeçar
make clean
make install
```

## Logs Importantes

### Cluster

```bash
# Kubernetes events
kubectl get events -A --sort-by='.lastTimestamp' | tail -n 50

# Node logs (via Docker)
docker logs k3d-devops-lab-server-0
docker logs k3d-devops-lab-agent-0
```

### Componentes

```bash
# ArgoCD
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0

# Grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Elasticsearch
kubectl logs -n logging elasticsearch-master-0

# Ingress
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

## 🗑️ Quando Reinstalar do Zero

Às vezes, a solução mais rápida é destruir tudo e reinstalar. Use o comando **destroy** quando:

- Muitas coisas quebradas ao mesmo tempo
- Configurações corrompidas
- Problemas persistentes sem causa clara
- Quer começar limpo após testes

### Opções de Limpeza

#### 1. Delete (apenas cluster)

Remove apenas o cluster, mantém volumes:

```bash
make delete
# ou
k3d cluster delete devops-lab
```

**Use quando:** Quer recriar o cluster mas manter dados (Prometheus, ES, etc)

#### 2. Clean (cluster + volumes)

Remove cluster e limpa volumes do SSD:

```bash
make clean
```

**Use quando:** Quer limpar dados mas manter /etc/hosts

#### 3. Destroy (TUDO)

Remove TUDO de forma interativa com confirmação:

```bash
make destroy
# ou
cd local && ./destroy.sh
```

**Remove:**

- ✅ Todos os Helm releases (ArgoCD, Prometheus, ES, etc)
- ✅ Todos os namespaces
- ✅ Cluster k3d completo
- ✅ Volumes persistentes (com confirmação)
- ✅ Entradas no /etc/hosts (com confirmação)

**Use quando:**

- Problemas graves sem solução clara
- Quer começar 100% do zero
- Vai recriar o ambiente completo

### Processo Completo de Reinstalação

```bash
# 1. Destroy completo
cd local
make destroy
# Confirme as opções interativas (volumes e /etc/hosts)

# 2. Reinstalar
make setup

# 3. Verificar
make status
make urls
```

### Backup Antes de Destroy

**SEMPRE faça backup antes de destruir:**

```bash
# Backup completo
make backup

# Backup manual de recursos importantes
kubectl get all -A -o yaml > backup-all-resources.yaml
kubectl get configmaps -A -o yaml > backup-configmaps.yaml
kubectl get secrets -A -o yaml > backup-secrets.yaml
```

Os backups ficam em: `/Volumes/Backup/devops-lab/backups/`

## Quando Pedir Ajuda

Se nada funcionar, colete informações e peça ajuda:

```bash
# Gerar relatório completo
./scripts/troubleshoot.sh > troubleshoot-report.txt

# Adicionar logs específicos
kubectl logs <pod> -n <namespace> >> troubleshoot-report.txt

# Compartilhar relatório (remova senhas!)
```

## Recursos Externos

- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug/)
- [k3d Issues](https://github.com/k3d-io/k3d/issues)
- [ArgoCD Troubleshooting](https://argo-cd.readthedocs.io/en/stable/operator-manual/troubleshooting/)
- [Prometheus Troubleshooting](https://prometheus.io/docs/prometheus/latest/troubleshooting/)

---

**Dica**: Sempre comece com `./scripts/troubleshoot.sh` para diagnóstico automático!
