# 🏗️ Arquitetura da Lab

Visão geral da infraestrutura local completa do projeto DevOps.

---

## 📐 Arquitetura Geral

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           macOS Host Machine                                 │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Docker Desktop                                   │ │
│  │  ┌──────────────────────────────────────────────────────────────────┐  │ │
│  │  │                  k3d Cluster (devops-lab)                         │  │ │
│  │  │                                                                    │  │ │
│  │  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │  │ │
│  │  │  │  k3d-server-0   │  │  k3d-agent-0    │  │  k3d-agent-1    │  │  │ │
│  │  │  │  (Control Plane)│  │  (Worker Node)  │  │  (Worker Node)  │  │  │ │
│  │  │  └─────────────────┘  └─────────────────┘  └─────────────────┘  │  │ │
│  │  │                                                                    │  │ │
│  │  │  ┌────────────────────────────────────────────────────────────┐  │  │ │
│  │  │  │                  NGINX Ingress Controller                   │  │ │ │
│  │  │  │              (Port Mapping: 80:80, 443:443)                 │  │ │ │
│  │  │  └────────────────────────────────────────────────────────────┘  │  │ │
│  │  │                                                                    │  │ │
│  │  │  ┌────────────────────────────────────────────────────────────┐  │  │ │
│  │  │  │                   Namespaces & Services                     │  │ │ │
│  │  │  │                                                              │  │ │ │
│  │  │  │  • argocd         (GitOps)                                  │  │ │ │
│  │  │  │  • monitoring     (Prometheus + Grafana)                    │  │ │ │
│  │  │  │  • devops-develop   (Apps: devops-be, devops-fe, devops-auth)      │  │ │ │
│  │  │  │  • devops-qa        (Apps: devops-be, devops-fe, devops-auth)      │  │ │ │
│  │  │  │  • devops-staging   (Apps: devops-be, devops-fe, devops-auth)      │  │ │ │
│  │  │  │  • devops-prod      (Apps: devops-be, devops-fe, devops-auth)      │  │ │ │
│  │  │  └────────────────────────────────────────────────────────────┘  │  │ │
│  │  └──────────────────────────────────────────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │              External SSD: /Volumes/Backup/devops-lab               │ │
│  │         (Persistent Volumes for DBs)                               │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
│  /etc/hosts mappings:                                                        │
│  127.0.0.1  *-fe.devops.local *-be.devops.local *-auth.devops.local               │
│  127.0.0.1  argocd.devops.local grafana.devops.local prometheus.devops.local ...   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Componentes Principais

### 1. Cluster Kubernetes (k3d)

```
k3d-devops-lab
├── k3d-server-0  (Control Plane + etcd)
│   ├── CPU: 2 cores
│   ├── Memory: 4GB
│   └── Roles: control-plane, master
│
├── k3d-agent-0   (Worker Node)
│   ├── CPU: 2 cores
│   ├── Memory: 4GB
│   └── Roles: worker
│
└── k3d-agent-1   (Worker Node)
    ├── CPU: 2 cores
    ├── Memory: 4GB
    └── Roles: worker

Volumes montados:
- /Volumes/Backup/devops-lab → /mnt/data (em cada node)
```

### 2. GitOps Stack (ArgoCD)

```
Namespace: argocd

┌────────────────────────────────────────┐
│           ArgoCD Server                │
│  http://argocd.devops.local              │
├────────────────────────────────────────┤
│  • Application Controller              │
│  • Repo Server                         │
│  • ApplicationSet Controller           │
│  • Notifications Controller            │
└────────────────────────────────────────┘
          │
          ├─── Git Repository (GitHub)
          │    https://github.com/usuario/devops
          │    ├── apps/devops-be/**
          │    ├── apps/devops-fe/**
          │    ├── apps/devops-auth/**
          │    └── local/helm/**
          │
          └─── Auto-sync com apps:
               ├── devops-be-local
               ├── devops-fe-local
               └── devops-auth-local
```

### 3. Observability Stack (Prometheus + Grafana)

```
Namespace: monitoring

┌──────────────────────────────────────────────────────────┐
│                    Prometheus Stack                       │
│                                                            │
│  ┌────────────────┐        ┌─────────────────┐          │
│  │   Prometheus   │────────│  AlertManager   │          │
│  │   :9090        │        │     :9093       │          │
│  └────────────────┘        └─────────────────┘          │
│         │                           │                     │
│         │                           │                     │
│         ├───────────────────────────┤                     │
│         │                           │                     │
│  ┌──────▼──────────────────────────▼──────┐             │
│  │           Grafana                       │             │
│  │   http://grafana.devops.local             │             │
│  │                                          │             │
│  │  Dashboards:                             │             │
│  │  • DevOps Lab - Overview              │             │
│  │  • DevOps Lab - Backend API           │             │
│  │  • DevOps Lab - Frontend              │             │
│  │  • DevOps Lab - Auth/Keycloak         │             │
│  └──────────────────────────────────────────┘             │
└──────────────────────────────────────────────────────────┘

Integrations:
├── Node Exporter (métricas de host)
├── Kube State Metrics (métricas de K8s)
├── ServiceMonitors (custom app metrics)
└── Alert Rules (notificações via webhook)
```

### 4. Application Stack (DevOps Apps)

```
Namespace: devops-lab

┌──────────────────────────────────────────────────────────┐
│                     DevOps Applications                     │
│                                                            │
│  Frontend (Next.js)                                       │
│  ┌────────────────────────────────────────────┐          │
│  │  devops-fe                                    │          │
│  │  http://develop-fe.devops.local                  │          │
│  │  ├── Replicas: 2                            │          │
│  │  ├── Resources: 512Mi RAM, 500m CPU        │          │
│  │  └── Env: NEXT_PUBLIC_API_URL,             │          │
│  │           NEXT_PUBLIC_AUTH_URL              │          │
│  └────────────────────────────────────────────┘          │
│                      │                                     │
│                      │ HTTP requests                       │
│                      ▼                                     │
│  Backend (NestJS)                                         │
│  ┌────────────────────────────────────────────┐          │
│  │  devops-be                                    │          │
│  │  http://develop-be.devops.local              │          │
│  │  ├── Replicas: 2                            │          │
│  │  ├── Resources: 1Gi RAM, 1000m CPU         │          │
│  │  ├── Health: /health/live, /health/ready   │          │
│  │  └── Dependencies:                          │          │
│  │      ├── PostgreSQL                         │          │
│  │      ├── Redis                              │          │
│  │      └── Keycloak                           │          │
│  └────────────────────────────────────────────┘          │
│                      │                                     │
│                      │ Authentication                      │
│                      ▼                                     │
│  Auth Service (Keycloak)                                  │
│  ┌────────────────────────────────────────────┐          │
│  │  devops-auth                                  │          │
│  │  http://develop-auth.devops.local             │          │
│  │  ├── Replicas: 1                            │          │
│  │  ├── Resources: 1Gi RAM, 500m CPU          │          │
│  │  ├── Realm: devops                            │          │
│  │  ├── Clients: devops-fe, devops-be             │          │
│  │  └── Custom Themes: /themes/devops           │          │
│  └────────────────────────────────────────────┘          │
│                      │                                     │
│  Databases                                                 │
│  ┌────────────────────────────────────────────┐          │
│  │  PostgreSQL 16                              │          │
│  │  ├── Databases: devops, devops_auth, devops_qa   │          │
│  │  └── PVC: /Volumes/Backup/devops-lab    │          │
│  └────────────────────────────────────────────┘          │
│  ┌────────────────────────────────────────────┐          │
│  │  Redis 7                                    │          │
│  │  ├── Cache & Sessions                       │          │
│  │  └── AOF persistence                        │          │
│  └────────────────────────────────────────────┘          │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 Deploy Flow (GitOps)

```
Developer ──┐
            │
            ▼
┌─────────────────────┐
│   Git Push          │
│   (develop branch)  │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│          GitHub Actions Workflow                 │
│  1. Run tests (CI)                               │
│  2. Build Docker images                          │
│  3. Push to GHCR (ghcr.io/geraldobl58)           │
│  4. Update Helm values (Git commit)              │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│              ArgoCD Detects Changes              │
│  • Polls Git repository (every 3min)            │
│  • Compares desired state vs current state      │
│  • Auto-sync enabled                             │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│           ArgoCD Applies Changes                 │
│  1. Pull new Helm values from Git               │
│  2. Render templates                             │
│  3. Apply to Kubernetes                          │
│  4. Wait for health checks                       │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│      Kubernetes Rolling Update                   │
│  • Terminate old pods gracefully                 │
│  • Start new pods with new image                 │
│  • Health checks (liveness + readiness)          │
│  • Zero-downtime deployment                      │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│            Application Running                   │
│  • New version deployed                          │
│  • Metrics sent to Prometheus                    │
│  • Logs sent to Elasticsearch                    │
│  • ArgoCD status: Synced + Healthy              │
└─────────────────────────────────────────────────┘
```

---

## 🌍 Multi-Environment Strategy

```
┌────────────────────────────────────────────────────────┐
│                   DNS Mapping                           │
├────────────────────────────────────────────────────────┤
│                                                          │
│  /etc/hosts configuration (auto-managed):               │
│                                                          │
│  127.0.0.1  develop-fe.devops.local                          │
│  127.0.0.1  develop-be.devops.local                      │
│  127.0.0.1  develop-auth.devops.local                     │
│                                                          │
│  127.0.0.1  qa-fe.devops.local                               │
│  127.0.0.1  qa-be.devops.local                           │
│  127.0.0.1  qa-auth.devops.local                          │
│                                                          │
│  127.0.0.1  staging-fe.devops.local                          │
│  127.0.0.1  staging-be.devops.local                      │
│  127.0.0.1  staging-auth.devops.local                     │
│                                                          │
│  127.0.0.1  fe.devops.local                             │
│  127.0.0.1  fe.devops.local                               │
│  127.0.0.1  be.devops.local                               │
│  127.0.0.1  auth.devops.local                             │
│                                                          │
│  # Tooling                                              │
│  127.0.0.1  argocd.devops.local                           │
│  127.0.0.1  grafana.devops.local                          │
│  127.0.0.1  prometheus.devops.local                       │
│  127.0.0.1  alertmanager.devops.local                     │
└────────────────────────────────────────────────────────┘
           │
           ▼
┌────────────────────────────────────────────────────────┐
│            NGINX Ingress Controller                     │
│         (Host-based routing)                            │
├────────────────────────────────────────────────────────┤
│                                                          │
│  Ingress Rules:                                         │
│                                                          │
│  develop-* ─────────► devops-develop namespace            │
│  qa-*      ─────────► devops-qa namespace                 │
│  staging-* ─────────► devops-staging namespace            │
│  {be,fe,auth}.devops.local ► devops-prod namespace          │
│                                                          │
│  argocd.*       ─────► argocd namespace                 │
│  grafana.*      ─────► monitoring namespace             │
└────────────────────────────────────────────────────────┘
```

---

## 📊 Resource Allocation

### Cluster Total Resources

```
Total Nodes:         3 (1 server + 2 agents)
Total CPU:           6 cores
Total Memory:        12 GB
Total Storage:       External SSD (/Volumes/Backup)
Network:             Docker bridge (localhost)
```

### Resource Distribution by Namespace

| Namespace     | CPU Request | CPU Limit | Memory Request | Memory Limit | Storage    |
| ------------- | ----------- | --------- | -------------- | ------------ | ---------- |
| argocd        | 500m        | 2000m     | 512Mi          | 2Gi          | 10Gi       |
| monitoring    | 1000m       | 3000m     | 2Gi            | 6Gi          | 50Gi       |
| logging       | 2000m       | 4000m     | 4Gi            | 8Gi          | 100Gi      |
| harbor-system | 1000m       | 2000m     | 2Gi            | 4Gi          | 50Gi       |
| devops-lab    | 2000m       | 4000m     | 3Gi            | 6Gi          | 20Gi       |
| **TOTAL**     | **6.5**     | **15**    | **11.5 Gi**    | **26 Gi**    | **230 Gi** |

---

## 🔒 Security & Access Control

```
┌────────────────────────────────────────────────────────┐
│                   Access Control                        │
├────────────────────────────────────────────────────────┤
│                                                          │
│  Layer 1: Network (Docker)                              │
│  ├── Local network only (127.0.0.1)                     │
│  ├── No external exposure                               │
│  └── Firewall: Docker internal bridge                   │
│                                                          │
│  Layer 2: Kubernetes RBAC                               │
│  ├── ServiceAccounts per app                            │
│  ├── Role/ClusterRole definitions                       │
│  ├── RoleBindings per namespace                         │
│  └── ArgoCD: admin-level cluster access                 │
│                                                          │
│  Layer 3: Application                                   │
│  ├── Keycloak: OAuth2 + OIDC                            │
│  ├── JWT tokens (15min access, 7d refresh)              │
│  ├── Role-based permissions (admin, user, guest)        │
│  └── Session management via Redis                       │
│                                                          │
│  Layer 4: Harbor Registry                               │
│  ├── Admin: admin/Harbor12345                           │
│  ├── Project-level access control                       │
│  └── Vulnerability scanning (Trivy)                     │
│                                                          │
│  Layer 5: Database                                      │
│  ├── PostgreSQL: user/password auth                     │
│  ├── Network policies (only from devops-be)               │
│  └── Encrypted at rest (SSD encryption)                 │
└────────────────────────────────────────────────────────┘
```

---

## 📈 Monitoring & Observability

### Metrics Collection

```
┌────────────────────────────────────────────────────────┐
│              Prometheus Metrics Flow                    │
├────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐                                       │
│  │  devops-be     │ ─── /metrics ────┐                   │
│  │  (NestJS)    │                  │                    │
│  └──────────────┘                  │                    │
│                                     │                    │
│  ┌──────────────┐                  │                    │
│  │ Node Exporter│ ─── :9100 ───────┤                   │
│  │ (DaemonSet)  │                  │                    │
│  └──────────────┘                  │                    │
│                                     ▼                    │
│  ┌──────────────┐           ┌──────────────┐           │
│  │ Kube State   │ ─────────►│  Prometheus  │           │
│  │ Metrics      │           │   (tsdb)     │           │
│  └──────────────┘           └──────┬───────┘           │
│                                     │                    │
│                                     ▼                    │
│                              ┌──────────────┐           │
│                              │   Grafana    │           │
│                              │ (Dashboards) │           │
│                              └──────────────┘           │
└────────────────────────────────────────────────────────┘

Default Metrics Collected:
• Container CPU/Memory usage
• Pod restart count
• Request rate & latency
• Database connections
• Cache hit/miss ratio
• API endpoint performance
```

### Logging Pipeline

```
┌────────────────────────────────────────────────────────┐
│              Logging Flow                               │
├────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐                                       │
│  │  devops-be     │ ─── stdout/stderr ───┐               │
│  │  (container) │                       │               │
│  └──────────────┘                       │               │
│                                          │               │
│  ┌──────────────┐                       │               │
│  │  devops-fe     │ ─── stdout/stderr ────┤               │
│  │  (container) │                       │               │
│  └──────────────┘                       │               │
│                                          ▼               │
│                                   ┌──────────────┐      │
│                                   │   Filebeat   │      │
│                                   │ (DaemonSet)  │      │
│                                   └──────┬───────┘      │
│                                          │               │
│                                          ▼               │
│                                   ┌──────────────┐      │
│                                   │Elasticsearch │      │
│                                   │  (3 nodes)   │      │
│                                   └──────┬───────┘      │
│                                          │               │
│                                          ▼               │
│                                   ┌──────────────┐      │
│                                   │    Kibana    │      │
│                                   │  (Web UI)    │      │
│                                   └──────────────┘      │
└────────────────────────────────────────────────────────┘

Log Structure:
{
  "@timestamp": "2025-06-10T10:30:00Z",
  "level": "info",
  "service": "devops-be",
  "namespace": "devops-lab",
  "pod": "devops-be-7d89f-xk2p9",
  "message": "Request processed",
  "context": {
    "method": "GET",
    "path": "/api/users",
    "duration": 45,
    "status": 200
  }
}
```

---

## 🔧 Operations & Maintenance

### Daily Operations

```bash
# Ver status geral do cluster
make status

# Ver uso de recursos
make top

# Ver logs de uma aplicação
make logs SERVICE=devops-be NAMESPACE=devops-lab

# Acessar dashboards
make dashboard    # ArgoCD
make grafana      # Grafana
make kibana       # Kibana
```

### Regular Maintenance

```bash
# Limpar resources não utilizados
docker system prune -af

# Backup do cluster
make backup

# Restart do cluster
make restart

# Troubleshooting completo
make troubleshoot
```

### Emergency Procedures

```bash
# Cluster não responde
k3d cluster stop devops-lab
k3d cluster start devops-lab

# Aplicação crashando
kubectl delete pod -n devops-lab -l app=devops-be

# Rollback de deploy
argocd app rollback devops-be-local

# Restaurar do backup
make restore
```

---

## 📚 Referências

- [k3d Documentation](https://k3d.io/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Elastic Stack](https://www.elastic.co/guide/index.html)
- [Harbor Registry](https://goharbor.io/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
