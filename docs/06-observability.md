# 📊 Observabilidade - Nexo CloudLab

## Stack Completa

O CloudLab inclui uma stack completa de observabilidade:

- **Prometheus**: Coleta e armazenamento de métricas
- **Grafana**: Visualização e dashboards
- **AlertManager**: Gestão de alertas
- **Node Exporter**: Métricas de sistema
- **Kube State Metrics**: Métricas do Kubernetes

## Arquitetura

```
┌───────────────────────────────────────────────────┐
│                  Applications                     │
│          (nexo-be, nexo-fe, nexo-auth)           │
│                Expose /metrics                    │
└────────────────────┬──────────────────────────────┘
                     │
                     │ Scrape (30s)
                     ↓
┌───────────────────────────────────────────────────┐
│              Prometheus Operator                  │
│  ┌──────────────┐  ┌─────────────────┐           │
│  │ ServiceMon   │  │ PrometheusRules │           │
│  │  (targets)   │  │    (alerts)     │           │
│  └──────────────┘  └─────────────────┘           │
│           ↓                  ↓                    │
│  ┌──────────────────────────────────┐            │
│  │       Prometheus TSDB            │            │
│  │   (Storage: 10Gi, Retention: 7d) │            │
│  └──────────────────────────────────┘            │
└────────────────┬────────────────┬─────────────────┘
                 │                │
        Query    │                │ Alerts
                 ↓                ↓
    ┌────────────────┐  ┌────────────────┐
    │    Grafana     │  │ AlertManager   │
    │  (Dashboards)  │  │ (Notifications)│
    └────────────────┘  └────────────────┘
```

## Acesso aos Dashboards

### Grafana

```bash
# Abrir Grafana
make grafana

# URL: http://grafana.nexo.local
# User: admin
# Pass: nexo@local2026

# Ou port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
open http://localhost:3000
```

### Prometheus

```bash
# Abrir Prometheus
make prometheus

# URL: http://prometheus.nexo.local

# Queries úteis:
# up                                    # Status dos targets
# rate(http_requests_total[5m])        # Taxa de requisições
# container_memory_usage_bytes         # Uso de memória
```

### AlertManager

```bash
# Abrir AlertManager
make alertmanager

# URL: http://alertmanager.nexo.local
```

## Dashboards Pré-configurados

### Nexo CloudLab (Folder)

Os dashboards customizados do Nexo ficam na pasta **Nexo CloudLab** no Grafana:

#### Nexo CloudLab - Overview

Visão geral de todos os ambientes (develop, qa, staging, prod):

- Pods running por ambiente
- Uso de memória e CPU por namespace
- Status dos pods por ambiente (tabelas)
- Pod restarts nos últimos 30 min
- Uptime dos deployments

#### Backend API (nexo-be)

Dashboard dedicado ao backend com filtro por namespace:

- Status e réplicas por namespace
- CPU e Memory usage (timeseries por pod)
- Network RX/TX
- Pod restarts
- Comparação CPU vs Memory por namespace

#### Frontend (nexo-fe)

Dashboard dedicado ao frontend com filtro por namespace:

- Status e réplicas por namespace
- CPU e Memory usage (timeseries por pod)
- Network RX/TX
- Pod restarts
- Comparação CPU vs Memory por namespace

#### Auth / Keycloak (nexo-auth)

Dashboard dedicado ao Keycloak com filtro por namespace:

- Status e réplicas por namespace
- CPU e Memory usage (timeseries por pod)
- Network RX/TX
- Pod restarts
- Comparação CPU vs Memory por namespace

> **Nota:** Todos os dashboards possuem variável `$namespace` que permite
> filtrar por `nexo-develop`, `nexo-qa`, `nexo-staging` ou `nexo-prod`.

### Dashboards Built-in do Kubernetes

Além dos dashboards customizados, o kube-prometheus-stack inclui:

#### Cluster Overview (Dashboard 7249)

Visão geral do cluster:

- Uso de CPU e Memória dos nodes
- Network I/O
- Disk I/O
- Pod count por namespace

### 2. Kubernetes Pods (Dashboard 6417)

Métricas por pod:

- CPU usage
- Memory usage
- Network traffic
- Restart count

### 3. Node Exporter (Dashboard 1860)

Métricas de sistema:

- CPU, Memory, Disk, Network
- Load average
- File descriptors
- Processes

### 4. NGINX Ingress (Dashboard 9614)

Métricas do Ingress:

- Requests por segundo
- Response times
- Status codes
- Upstream health

## Métricas Customizadas

### Instrumentar Aplicação Node.js

```typescript
// Backend: nexo-be/src/libs/metrics.ts
import promClient from "prom-client";

// Registro
const register = new promClient.Registry();

// Métricas padrão
promClient.collectDefaultMetrics({ register });

// Métricas customizadas
export const httpRequestDuration = new promClient.Histogram({
  name: "http_request_duration_seconds",
  help: "Duration of HTTP requests in seconds",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.1, 0.5, 1, 2, 5],
  registers: [register],
});

export const httpRequestTotal = new promClient.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

// Endpoint de métricas
export async function metricsHandler(req, res) {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
}
```

### Middleware de Métricas

```typescript
// nexo-be/src/middleware/metrics.middleware.ts
export function metricsMiddleware(req, res, next) {
  const start = Date.now();

  res.on("finish", () => {
    const duration = (Date.now() - start) / 1000;

    httpRequestDuration.observe(
      {
        method: req.method,
        route: req.route?.path || req.path,
        status_code: res.statusCode,
      },
      duration,
    );

    httpRequestTotal.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode,
    });
  });

  next();
}
```

### ServiceMonitor para App

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nexo-be
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: nexo-be
  namespaceSelector:
    matchNames:
      - nexo-local
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

## Alertas

### Alertas Pré-configurados

#### PodCrashLooping

```yaml
alert: PodCrashLooping
expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
for: 5m
labels:
  severity: critical
annotations:
  summary: "Pod {{ $labels.pod }} está em crash loop"
```

#### HighMemoryUsage

```yaml
alert: HighMemoryUsage
expr: |
  (container_memory_working_set_bytes / container_spec_memory_limit_bytes) > 0.9
for: 5m
labels:
  severity: warning
```

#### HighCPUUsage

```yaml
alert: HighCPUUsage
expr: |
  (rate(container_cpu_usage_seconds_total[5m]) / 
   (container_spec_cpu_quota/container_spec_cpu_period)) > 0.9
for: 5m
```

### Criar Alertas Customizados

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: nexo-custom-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: nexo.api.rules
      interval: 30s
      rules:
        # Alta taxa de erros 5xx
        - alert: HighErrorRate
          expr: |
            (sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (service) /
             sum(rate(http_requests_total[5m])) by (service)) > 0.05
          for: 5m
          labels:
            severity: critical
            team: backend
          annotations:
            summary: "Alta taxa de erros no {{ $labels.service }}"
            description: "{{ $labels.service }} tem {{ $value | humanizePercentage }} de erros nos últimos 5 minutos"

        # Latência alta
        - alert: HighLatency
          expr: |
            histogram_quantile(0.95, 
              sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
            ) > 2
          for: 10m
          labels:
            severity: warning
            team: backend
          annotations:
            summary: "Latência alta no {{ $labels.service }}"
            description: "P95 latency: {{ $value }}s"

        # Database connection pool
        - alert: DatabaseConnectionPoolExhausted
          expr: |
            sum(pg_stat_activity_count) by (instance) / 
            sum(pg_settings_max_connections) by (instance) > 0.8
          for: 5m
          labels:
            severity: warning
            team: infra
          annotations:
            summary: "Pool de conexões do banco está quase esgotado"
```

### Aplicar Alertas

```bash
kubectl apply -f alerts.yaml

# Verificar
kubectl get prometheusrules -n monitoring

# Ver alertas ativos
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Acessar http://localhost:9090/alerts
```

## Queries Prometheus Úteis

### Recursos

```promql
# CPU usage por pod
rate(container_cpu_usage_seconds_total[5m]) * 100

# Memory usage por pod
container_memory_working_set_bytes / 1024 / 1024

# Network RX por pod
rate(container_network_receive_bytes_total[5m])

# Network TX por pod
rate(container_network_transmit_bytes_total[5m])

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100
```

### Aplicação

```promql
# Request rate
rate(http_requests_total[5m])

# Error rate
rate(http_requests_total{status_code=~"5.."}[5m])

# Latência P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Latência P99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Throughput
sum(rate(http_requests_total[5m])) by (method, route)
```

### Kubernetes

```promql
# Pods por fase
count(kube_pod_status_phase) by (phase)

# Pods restartando
rate(kube_pod_container_status_restarts_total[15m]) > 0

# Containers terminados
kube_pod_container_status_terminated_reason

# Eventos
kube_event_count
```

## Grafana Avançado

### Criar Dashboard Customizado

1. **Acessar Grafana**: http://grafana.nexo.local
2. **Create** → **Dashboard** → **Add visualization**
3. **Selecionar Prometheus** como datasource
4. **Adicionar query**

Exemplo de painel:

```json
{
  "title": "API Request Rate",
  "targets": [
    {
      "expr": "sum(rate(http_requests_total[5m])) by (route)",
      "legendFormat": "{{ route }}"
    }
  ],
  "type": "graph"
}
```

### Variáveis de Dashboard

```
Name: namespace
Type: Query
Query: label_values(kube_pod_info, namespace)

Name: pod
Type: Query
Query: label_values(kube_pod_info{namespace="$namespace"}, pod)
```

Usar em queries: `{namespace="$namespace", pod="$pod"}`

### Dashboard as Code

```yaml
# grafana-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nexo-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  nexo-api.json: |
    {
      "dashboard": {
        "title": "Nexo API",
        "panels": [...]
      }
    }
```

## AlertManager Configuration

### Slack Notifications

```yaml
# alertmanager-config.yaml
global:
  slack_api_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

route:
  group_by: ["alertname", "cluster", "service"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: "slack-notifications"
  routes:
    - match:
        severity: critical
      receiver: "slack-critical"

receivers:
  - name: "slack-notifications"
    slack_configs:
      - channel: "#alerts"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
        title: "{{ .GroupLabels.alertname }}"

  - name: "slack-critical"
    slack_configs:
      - channel: "#critical-alerts"
        text: "@here {{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
        title: "🚨 CRITICAL: {{ .GroupLabels.alertname }}"
```

### Aplicar Configuração

```bash
kubectl create secret generic alertmanager-kube-prometheus-stack-alertmanager \
  --from-file=alertmanager.yaml=alertmanager-config.yaml \
  --namespace monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Reload AlertManager
kubectl delete pod -n monitoring -l app.kubernetes.io/name=alertmanager
```

## Recording Rules

Para queries pesadas, use recording rules:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: nexo-recording-rules
  namespace: monitoring
spec:
  groups:
    - name: nexo.recording.rules
      interval: 30s
      rules:
        # Request rate por minuto
        - record: nexo:http_requests:rate1m
          expr: sum(rate(http_requests_total[1m])) by (service, method, route)

        # Error rate por minuto
        - record: nexo:http_errors:rate1m
          expr: |
            sum(rate(http_requests_total{status_code=~"5.."}[1m])) by (service) /
            sum(rate(http_requests_total[1m])) by (service)

        # P95 latency
        - record: nexo:http_request_duration:p95
          expr: |
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
            )
```

Usar em queries: `nexo:http_requests:rate1m`

## Retention e Storage

### Configurar Retention

```bash
# Ver configuração atual
kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus -o yaml | grep retention

# Aumentar retention
# Editar values do Helm e reinstalar
```

### Backup de Métricas

```bash
# Snapshot
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot

# Location do snapshot
kubectl exec -n monitoring prometheus-kube-prometheus-stack-prometheus-0 -- \
  ls /prometheus/snapshots/
```

## Troubleshooting

### Targets Down

```bash
# Ver targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Acessar http://localhost:9090/targets

# Verificar ServiceMonitor
kubectl get servicemonitor -n monitoring

# Ver logs do Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### Alertas não Disparam

```bash
# Verificar PrometheusRules
kubectl get prometheusrules -n monitoring

# Ver regras no Prometheus
# http://localhost:9090/rules

# Testar query manualmente
# http://localhost:9090/graph
```

### Grafana sem Dados

```bash
# Verificar datasource
kubectl get cm -n monitoring kube-prometheus-stack-grafana -o yaml

# Ver logs do Grafana
kubectl logs -n monitoring deploy/kube-prometheus-stack-grafana
```

## Próximos Passos

- [05 - Deploy de Aplicações](./05-applications.md)
- [06 - Troubleshooting](./06-troubleshooting.md)
- [07 - Cheat Sheet](./07-cheatsheet.md)

<!-- Logging (04) foi removido - muito pesado para ambiente local -->

---

**Anterior**: [02 - ArgoCD](./02-argocd.md) | **Próximo**: [05 - Deploy de Aplicações](./05-applications.md)
