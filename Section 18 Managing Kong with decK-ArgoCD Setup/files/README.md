# Kong GitOps Example Project

This is a complete example of managing Kong Gateway with decK and ArgoCD using GitOps principles.

## 📁 Project Structure

```
kong-gitops-example/
├── README.md                          # This file
├── kong.yaml                          # Main Kong configuration
├── kubernetes/                        # Kubernetes manifests
│   ├── namespace.yaml                 # Kong namespace
│   ├── deck-sync-job.yaml            # Job that runs decK sync
│   ├── kong-configmap.yaml           # ConfigMap with Kong config
│   ├── kong-secrets.yaml             # ExternalSecret for API keys
│   ├── secret-store.yaml             # Vault SecretStore
│   └── service-account.yaml          # RBAC for decK job
├── argocd/                           # ArgoCD applications
│   └── kong-config-app.yaml          # ArgoCD app manifest
└── scripts/                          # Helper scripts
    ├── validate.sh                    # Validate configuration
    ├── deploy-dev.sh                  # Deploy to dev
    ├── deploy-staging.sh              # Deploy to staging
    └── deploy-prod.sh                 # Deploy to production
```

## 🚀 Quick Start

### Prerequisites

1. **Kubernetes cluster** with Kong installed
2. **ArgoCD** installed in the cluster
3. **decK CLI** installed locally
4. **Vault** or another secrets manager (optional)

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/kong-gitops-example.git
cd kong-gitops-example
```

### Step 2: Set Up Secrets

Create a Kubernetes secret for API keys (or use Vault):

```bash
kubectl create secret generic kong-api-keys -n kong \
  --from-literal=free-user-key=your-free-key \
  --from-literal=premium-user-key=your-premium-key \
  --from-literal=admin-key=your-admin-key
```

### Step 3: Validate Configuration

```bash
# Validate the Kong configuration
./scripts/validate.sh
```

### Step 4: Deploy with ArgoCD

```bash
# Apply the ArgoCD application
kubectl apply -f argocd/kong-config-app.yaml

# Watch the sync
argocd app get kong-config --watch
```

### Step 5: Verify Deployment

```bash
# Check Kong configuration
curl http://localhost:8000/api/v1/public

# Test authenticated endpoint
curl http://localhost:8000/api/v1/auth \
  -H "Authorization: Bearer YOUR_JWT"
```

## 📖 Kong Configuration Overview

### Services

- **backend-api**: Main backend API service
  - Public routes: `/api/v1/public`
  - Authenticated routes: `/api/v1/auth` (requires JWT)
  - Rate limited: 1000 req/min

- **frontend-api**: Frontend application
  - Routes: `/`, `/app`

- **kong-admin**: Kong Admin API (secured)
  - Route: `/admin`
  - Requires API key + ACL

### Consumers

- **free-user**: Limited access (10 req/min)
- **premium-user**: High access (1000 req/min)
- **kong-admin**: Full admin access

### Global Plugins

- **CORS**: Cross-origin resource sharing
- **correlation-id**: Request ID generation for tracing
- **prometheus**: Metrics collection

## 🔧 Development Workflow

### Making Changes

1. **Edit configuration**
   ```bash
   vim kong.yaml
   ```

2. **Validate locally**
   ```bash
   deck gateway validate --state kong.yaml
   ```

3. **Preview changes**
   ```bash
   deck gateway diff --state kong.yaml --kong-addr http://localhost:8001
   ```

4. **Commit and push**
   ```bash
   git add kong.yaml
   git commit -m "Add new API endpoint"
   git push origin main
   ```

5. **ArgoCD automatically syncs** (or trigger manually)
   ```bash
   argocd app sync kong-config
   ```

### Testing Locally

```bash
# Apply to local Kong instance
deck gateway sync --state kong.yaml --kong-addr http://localhost:8001

# Verify
curl http://localhost:8000/api/v1/public
```

### Rollback

```bash
# Option 1: Git revert
git revert HEAD
git push origin main

# Option 2: ArgoCD rollback
argocd app rollback kong-config

# Option 3: Manual decK sync
git checkout previous-commit -- kong.yaml
deck gateway sync --state kong.yaml
```

## 🌍 Multi-Environment Deployment

### Development

```bash
./scripts/deploy-dev.sh
```

### Staging

```bash
./scripts/deploy-staging.sh
```

### Production

```bash
./scripts/deploy-prod.sh
```

## 🔒 Security Best Practices

### 1. Keep Admin API on Localhost

Kong Admin API should only be accessible from inside the cluster:

```yaml
# docker-compose.yml or Kong deployment
environment:
  KONG_ADMIN_LISTEN: 127.0.0.1:8001
```

### 2. Use Secrets Manager

Never commit secrets to Git. Use Vault, AWS Secrets Manager, or Kubernetes Secrets:

```yaml
# In kong.yaml, use environment variables
consumers:
- username: api-user
  keyauth_credentials:
  - key: $KONG_API_KEY
```

### 3. Implement RBAC

Use ArgoCD RBAC to control who can sync configurations:

```yaml
# argocd-rbac-cm ConfigMap
p, role:developer, applications, sync, default/kong-config, allow
g, alice, role:developer
```

### 4. Enable Audit Logging

Track all changes through Git history and ArgoCD audit logs.

## 📊 Monitoring

### Prometheus Metrics

Kong exports metrics at `/metrics` endpoint:

```bash
curl http://kong:8001/metrics
```

### Grafana Dashboard

Import Kong Grafana dashboard:
- Dashboard ID: 7424
- URL: https://grafana.com/grafana/dashboards/7424

### Distributed Tracing

Kong integrates with Jaeger, Zipkin, or DataDog for distributed tracing.

## 🐛 Troubleshooting

### Configuration Not Applying

**Check decK sync job logs:**
```bash
kubectl logs -n kong -l job-name=kong-deck-sync --tail=100
```

**Common issues:**
- Kong Admin API not accessible
- Invalid YAML syntax
- Missing environment variables

### ArgoCD Shows OutOfSync

**Check diff:**
```bash
argocd app diff kong-config
```

**Force sync:**
```bash
argocd app sync kong-config --force
```

### Kong Returning 404

**Verify route exists:**
```bash
curl http://kong:8001/routes
```

**Check service:**
```bash
curl http://kong:8001/services
```

## 📚 Additional Resources

- [decK Documentation](https://docs.konghq.com/deck/)
- [Kong Gateway Documentation](https://docs.konghq.com/gateway/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally
5. Submit a pull request

## 📝 License

MIT License - see LICENSE file for details

## 💬 Support

For questions or issues:
- Open a GitHub issue
- Contact the platform team
- Check Kong community forums

---

**Happy Kong-ing! 🦍**
