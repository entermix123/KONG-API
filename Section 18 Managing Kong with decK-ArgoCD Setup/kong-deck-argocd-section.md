# Managing Kong with decK and ArgoCD - Production GitOps Approach

## Overview

In production environments, managing Kong through the Kong Manager GUI is not recommended due to security concerns with exposing the Admin API. Instead, we use **decK** (Declarative Kong) to manage Kong configurations as code, combined with **ArgoCD** for automated GitOps deployments.

This approach provides:
- **Security**: Admin API remains on localhost only (127.0.0.1:8001)
- **Version Control**: All Kong configurations in Git
- **Auditability**: Complete history of who changed what and when
- **Automation**: ArgoCD automatically applies configuration changes
- **Consistency**: Declarative configuration prevents configuration drift

---

## What is decK?

decK (Declarative Kong) is Kong's official CLI tool for managing Kong configurations as YAML files. Think of it as "Terraform for Kong" or "Kubectl for Kong."

**Key Features:**
- Export current Kong configuration to YAML
- Apply YAML configurations to Kong
- Diff configurations before applying
- Validate configurations offline
- Sync state between Git and Kong

**Installation:**

```bash
# Linux
curl -sL https://github.com/Kong/deck/releases/latest/download/deck_linux_amd64.tar.gz -o deck.tar.gz
tar -xf deck.tar.gz -C /tmp
sudo cp /tmp/deck /usr/local/bin/

# macOS
brew install deck

# Windows (using Chocolatey)
choco install deck

# Verify installation
deck version
```

---

## Understanding decK Configuration Files

### Basic Structure

A decK configuration file (`kong.yaml`) describes your entire Kong setup:

```yaml
_format_version: "3.0"
_transform: true

services:
- name: my-api
  url: http://backend-service:8000
  routes:
  - name: my-api-route
    paths:
    - /api
    strip_path: true
  plugins:
  - name: rate-limiting
    config:
      minute: 100
      policy: local

consumers:
- username: api-user
  keyauth_credentials:
  - key: my-secret-api-key
  acls:
  - group: developers

plugins:
- name: cors
  config:
    origins:
    - "*"
    methods:
    - GET
    - POST
    headers:
    - Authorization
    exposed_headers:
    - X-Auth-Token
    credentials: true
    max_age: 3600
```

### Configuration Format Versions

- `_format_version: "3.0"` - Latest format (Kong 3.x)
- `_format_version: "1.1"` - Legacy format (Kong 2.x)

Always use the latest format version for new configurations.

---

## Working with decK - Basic Commands

### 1. Export Current Kong Configuration

Export your entire Kong setup to a YAML file:

```bash
# Export all configurations
deck gateway dump --output-file kong.yaml

# Export specific workspace (Kong Enterprise)
deck gateway dump --workspace default --output-file kong-default.yaml

# Export with specific Kong Admin API URL
deck gateway dump --kong-addr http://localhost:8001 --output-file kong.yaml
```

This creates a `kong.yaml` file containing all your services, routes, plugins, consumers, etc.

### 2. Validate Configuration

Check if your YAML file is valid before applying:

```bash
# Validate against Kong's schema
deck gateway validate --state kong.yaml

# Validate and show warnings
deck gateway validate --state kong.yaml --verbose
```

### 3. Preview Changes (Dry Run)

See what would change without actually applying:

```bash
# Show diff between current Kong state and YAML file
deck gateway diff --state kong.yaml

# Output example:
# creating service my-api
# creating route my-api-route (for service my-api)
# updating plugin rate-limiting (for service my-api)
# deleting service old-service
```

### 4. Apply Configuration

Synchronize Kong with your YAML file:

```bash
# Apply changes
deck gateway sync --state kong.yaml

# Apply with confirmation prompt
deck gateway sync --state kong.yaml --select-tag prod

# Apply to specific workspace
deck gateway sync --state kong.yaml --workspace default
```

### 5. Reset Kong

Remove all Kong configurations (useful for testing):

```bash
# WARNING: This deletes everything!
deck gateway reset --force
```

---

## Organizing Kong Configurations

For larger projects, split configurations into multiple files:

### Directory Structure

```
kong-configs/
├── kong.yaml              # Main configuration file
├── services/
│   ├── backend-api.yaml
│   ├── frontend-api.yaml
│   └── admin-api.yaml
├── plugins/
│   ├── global-cors.yaml
│   ├── global-rate-limit.yaml
│   └── security.yaml
├── consumers/
│   ├── developers.yaml
│   └── partners.yaml
└── upstreams/
    └── backend-upstream.yaml
```

### Example: Backend API Service

**services/backend-api.yaml**
```yaml
_format_version: "3.0"

services:
- name: backend-api
  url: http://backend-service.backend-ns.svc.cluster.local:8000
  tags:
  - backend
  - production
  
  routes:
  - name: api-v1
    paths:
    - /api/v1
    strip_path: false
    methods:
    - GET
    - POST
    - PUT
    - DELETE
    tags:
    - api
    
  plugins:
  - name: rate-limiting
    config:
      minute: 1000
      hour: 10000
      policy: redis
      redis:
        host: redis.infrastructure.svc.cluster.local
        port: 6379
        database: 0
    tags:
    - rate-limit
    
  - name: jwt
    config:
      key_claim_name: iss
      secret_is_base64: false
    tags:
    - auth
```

### Example: Global CORS Plugin

**plugins/global-cors.yaml**
```yaml
_format_version: "3.0"

plugins:
- name: cors
  config:
    origins:
    - https://app.example.com
    - https://admin.example.com
    methods:
    - GET
    - POST
    - PUT
    - PATCH
    - DELETE
    - OPTIONS
    headers:
    - Accept
    - Authorization
    - Content-Type
    exposed_headers:
    - X-Auth-Token
    - X-Request-ID
    credentials: true
    max_age: 3600
  tags:
  - global
  - cors
```

### Merging Multiple Files

decK can merge multiple YAML files:

```bash
# Sync using multiple files
deck gateway sync --state kong.yaml --state services/ --state plugins/

# Or use a directory
deck gateway sync --state kong-configs/
```

---

## Using decK with Tags for Environment Management

Tags allow you to manage different environments (dev, staging, prod) from the same configuration:

```yaml
_format_version: "3.0"

services:
- name: backend-api
  url: http://backend-service:8000
  tags:
  - production
  - backend
  
  routes:
  - name: api-v1
    paths:
    - /api/v1
    tags:
    - production

- name: backend-api-dev
  url: http://backend-service-dev:8000
  tags:
  - development
  - backend
  
  routes:
  - name: api-v1-dev
    paths:
    - /dev/api/v1
    tags:
    - development
```

Deploy only production resources:

```bash
deck gateway sync --state kong.yaml --select-tag production
```

Deploy only development resources:

```bash
deck gateway sync --state kong.yaml --select-tag development
```

---

## Integrating decK with ArgoCD

Now let's combine decK with ArgoCD for a complete GitOps workflow.

### Architecture

```
┌─────────────┐
│   Git Repo  │
│             │
│ kong-config/│
│  ├─ kong.yaml
│  └─ ...     │
└──────┬──────┘
       │
       │ (monitors)
       ↓
┌─────────────────┐
│     ArgoCD      │
│                 │
│  ┌───────────┐  │
│  │ Kong App  │  │
│  └─────┬─────┘  │
└────────┼────────┘
         │
         │ (applies via Job)
         ↓
   ┌─────────────┐
   │    Kong     │
   │ Admin API   │
   │ :8001       │
   └─────────────┘
```

### Step 1: Create Git Repository Structure

```
kong-gitops/
├── argocd/
│   └── kong-config-app.yaml      # ArgoCD Application manifest
├── kong-config/
│   ├── kong.yaml                 # Main Kong configuration
│   ├── services/
│   ├── plugins/
│   └── consumers/
└── kubernetes/
    ├── namespace.yaml
    └── deck-sync-job.yaml        # Kubernetes Job to run decK
```

### Step 2: Create decK Sync Job

**kubernetes/deck-sync-job.yaml**

This Kubernetes Job runs decK to apply your Kong configuration:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kong-deck-sync
  namespace: kong
  annotations:
    argocd.argoproj.io/hook: Sync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    metadata:
      name: kong-deck-sync
    spec:
      restartPolicy: Never
      serviceAccountName: kong-deck-sync
      containers:
      - name: deck
        image: kong/deck:v1.38.0
        command:
        - /bin/sh
        - -c
        - |
          echo "Starting Kong configuration sync..."
          
          # Wait for Kong to be ready
          until curl -s http://kong-admin.kong.svc.cluster.local:8001/status; do
            echo "Waiting for Kong Admin API..."
            sleep 2
          done
          
          echo "Kong is ready. Validating configuration..."
          deck gateway validate --state /config
          
          echo "Applying Kong configuration..."
          deck gateway sync --state /config --kong-addr http://kong-admin.kong.svc.cluster.local:8001
          
          echo "Kong configuration applied successfully!"
        volumeMounts:
        - name: kong-config
          mountPath: /config
          readOnly: true
      volumes:
      - name: kong-config
        configMap:
          name: kong-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kong-deck-sync
  namespace: kong
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: kong-deck-sync
  namespace: kong
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kong-deck-sync
  namespace: kong
subjects:
- kind: ServiceAccount
  name: kong-deck-sync
  namespace: kong
roleRef:
  kind: Role
  name: kong-deck-sync
  apiGroup: rbac.authorization.k8s.io
```

### Step 3: Create ConfigMap for Kong Configuration

**kubernetes/kong-configmap.yaml**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kong-config
  namespace: kong
data:
  kong.yaml: |
    _format_version: "3.0"
    _transform: true
    
    services:
    - name: backend-api
      url: http://backend-service.backend-ns.svc.cluster.local:8000
      routes:
      - name: api-v1
        paths:
        - /api/v1
        strip_path: false
      plugins:
      - name: rate-limiting
        config:
          minute: 1000
    
    consumers:
    - username: api-user
      keyauth_credentials:
      - key: $KONG_API_KEY
```

**Alternative: Store configuration files directly**

Instead of a ConfigMap, you can use Kustomize to generate it from files:

**kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: kong

resources:
- namespace.yaml
- deck-sync-job.yaml

configMapGenerator:
- name: kong-config
  files:
  - kong-config/kong.yaml
  - kong-config/services/backend-api.yaml
  - kong-config/plugins/global-cors.yaml
```

### Step 4: Create ArgoCD Application

**argocd/kong-config-app.yaml**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kong-config
  namespace: argocd
spec:
  project: default
  
  source:
    repoURL: https://github.com/your-org/kong-gitops.git
    targetRevision: main
    path: kubernetes
    
  destination:
    server: https://kubernetes.default.svc
    namespace: kong
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
    
  # Run decK sync job on every sync
  ignoreDifferences:
  - group: batch
    kind: Job
    jsonPointers:
    - /spec/template/metadata/labels
```

### Step 5: Apply ArgoCD Application

```bash
# Apply the ArgoCD application
kubectl apply -f argocd/kong-config-app.yaml

# Watch the sync
argocd app get kong-config

# View logs from the decK sync job
kubectl logs -n kong -l job-name=kong-deck-sync -f
```

---

## Advanced: Multi-Environment Setup with Kustomize

For managing multiple environments (dev, staging, prod), use Kustomize overlays:

### Directory Structure

```
kong-gitops/
├── base/
│   ├── kustomization.yaml
│   ├── kong-config.yaml
│   ├── deck-sync-job.yaml
│   └── namespace.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── kong-config-patch.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── kong-config-patch.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── kong-config-patch.yaml
└── argocd/
    ├── kong-config-dev.yaml
    ├── kong-config-staging.yaml
    └── kong-config-prod.yaml
```

### Base Configuration

**base/kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- namespace.yaml
- deck-sync-job.yaml

configMapGenerator:
- name: kong-config
  files:
  - kong-config.yaml
```

### Development Overlay

**overlays/dev/kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: kong-dev

bases:
- ../../base

patches:
- path: kong-config-patch.yaml
  target:
    kind: ConfigMap
    name: kong-config

nameSuffix: -dev
```

**overlays/dev/kong-config-patch.yaml**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kong-config
data:
  kong.yaml: |
    _format_version: "3.0"
    
    services:
    - name: backend-api
      url: http://backend-service-dev:8000
      routes:
      - name: api-v1
        paths:
        - /dev/api/v1
      plugins:
      - name: rate-limiting
        config:
          minute: 100  # Lower limit for dev
```

### Production Overlay

**overlays/prod/kong-config-patch.yaml**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kong-config
data:
  kong.yaml: |
    _format_version: "3.0"
    
    services:
    - name: backend-api
      url: http://backend-service:8000
      routes:
      - name: api-v1
        paths:
        - /api/v1
      plugins:
      - name: rate-limiting
        config:
          minute: 10000  # Higher limit for prod
          policy: redis   # Use Redis for distributed rate limiting
```

### ArgoCD Applications for Each Environment

**argocd/kong-config-prod.yaml**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kong-config-prod
  namespace: argocd
spec:
  project: production
  
  source:
    repoURL: https://github.com/your-org/kong-gitops.git
    targetRevision: main
    path: overlays/prod
    
  destination:
    server: https://kubernetes.default.svc
    namespace: kong-prod
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Managing Secrets with External Secrets Operator

For sensitive data like API keys, use External Secrets Operator with Vault:

### Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets-system --create-namespace
```

### Create SecretStore

**kubernetes/secret-store.yaml**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: kong
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "kong"
```

### Create ExternalSecret for Kong API Keys

**kubernetes/kong-secrets.yaml**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: kong-api-keys
  namespace: kong
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: kong-api-keys
    creationPolicy: Owner
  data:
  - secretKey: admin-api-key
    remoteRef:
      key: kong/admin
      property: api-key
  - secretKey: consumer-api-key
    remoteRef:
      key: kong/consumers
      property: api-key
```

### Reference Secrets in decK Configuration

Use environment variable substitution in your Kong config:

**kong.yaml**
```yaml
_format_version: "3.0"

consumers:
- username: api-user
  keyauth_credentials:
  - key: $KONG_CONSUMER_API_KEY  # Will be replaced by decK
```

Update the decK sync job to inject the secret:

```yaml
spec:
  template:
    spec:
      containers:
      - name: deck
        env:
        - name: KONG_CONSUMER_API_KEY
          valueFrom:
            secretKeyRef:
              name: kong-api-keys
              key: consumer-api-key
        command:
        - /bin/sh
        - -c
        - |
          # decK automatically substitutes $KONG_* environment variables
          deck gateway sync --state /config --kong-addr http://kong-admin:8001
```

---

## Workflow Example: Making Changes

### Scenario: Add a new API endpoint with authentication

**Step 1: Update Kong configuration in Git**

Edit `kong-config/services/backend-api.yaml`:

```yaml
services:
- name: backend-api
  url: http://backend-service:8000
  
  routes:
  - name: api-v1
    paths:
    - /api/v1
    
  # Add new authenticated route
  - name: api-v2-auth
    paths:
    - /api/v2
    plugins:
    - name: jwt
      config:
        key_claim_name: iss
```

**Step 2: Commit and push to Git**

```bash
git add kong-config/services/backend-api.yaml
git commit -m "Add authenticated v2 API endpoint"
git push origin main
```

**Step 3: ArgoCD automatically detects and syncs**

ArgoCD polls your Git repo (or receives webhook) and:
1. Detects the configuration change
2. Triggers the decK sync job
3. decK validates and applies the new configuration to Kong

**Step 4: Verify the change**

```bash
# Check ArgoCD sync status
argocd app get kong-config

# Test the new endpoint
curl -X GET https://api.example.com/api/v2 \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Best Practices

### 1. Always Use Version Control

- Commit every Kong configuration change
- Use meaningful commit messages
- Create pull requests for review before merging

### 2. Test in Non-Production First

```bash
# Apply to dev environment first
deck gateway sync --state kong.yaml --kong-addr http://kong-dev:8001

# After testing, promote to staging
deck gateway sync --state kong.yaml --kong-addr http://kong-staging:8001

# Finally, production
deck gateway sync --state kong.yaml --kong-addr http://kong-prod:8001
```

### 3. Use `deck diff` Before Applying

Always preview changes:

```bash
deck gateway diff --state kong.yaml
```

### 4. Tag Resources

Use tags for organization and filtering:

```yaml
services:
- name: my-service
  tags:
  - team:backend
  - env:production
  - version:v1
```

### 5. Separate Global and Service-Specific Plugins

```yaml
# Global plugins (applied to all requests)
plugins:
- name: correlation-id
  config:
    header_name: X-Request-ID
    
# Service-specific plugins
services:
- name: my-api
  plugins:
  - name: rate-limiting
    config:
      minute: 100
```

### 6. Use Descriptive Names

```yaml
# Good
services:
- name: user-management-api
  routes:
  - name: users-crud-v1

# Bad
services:
- name: api1
  routes:
  - name: route1
```

### 7. Document Your Configuration

Add comments in YAML (though they won't be preserved by decK):

```yaml
# Rate limiting for public API endpoints
# - 1000 requests per minute per consumer
# - Redis policy for distributed rate limiting across Kong instances
plugins:
- name: rate-limiting
  config:
    minute: 1000
    policy: redis
```

Better: maintain a separate `README.md` in your Git repo documenting your Kong architecture.

### 8. Keep Secrets Out of Git

Never commit API keys, passwords, or certificates:

```yaml
# ❌ BAD - API key in configuration
consumers:
- username: api-user
  keyauth_credentials:
  - key: super-secret-key-123

# ✅ GOOD - Use environment variable
consumers:
- username: api-user
  keyauth_credentials:
  - key: $KONG_API_KEY
```

Store secrets in Vault or Kubernetes Secrets, injected at runtime.

---

## Troubleshooting

### Problem: decK sync fails with "conflict" errors

**Cause**: Another process modified Kong between your `diff` and `sync`

**Solution**: Run `deck gateway sync` again - decK will re-evaluate the state

### Problem: Configuration not applying

**Check the decK sync job logs:**

```bash
kubectl logs -n kong -l job-name=kong-deck-sync --tail=100
```

**Common issues:**
- Kong Admin API not accessible (check service name and port)
- Invalid YAML syntax (run `deck gateway validate` locally)
- Missing required fields in configuration

### Problem: ArgoCD shows "OutOfSync" but no changes in Git

**Cause**: The Kubernetes Job object keeps changing (timestamps, status)

**Solution**: Add this to ArgoCD Application:

```yaml
spec:
  ignoreDifferences:
  - group: batch
    kind: Job
    jsonPointers:
    - /status
    - /spec/template/metadata
```

### Problem: Secrets not substituting

**Check environment variables are set:**

```bash
kubectl exec -n kong deployment/kong-admin -- env | grep KONG
```

**Ensure the secret exists:**

```bash
kubectl get secret -n kong kong-api-keys -o yaml
```

---

## Comparison: Kong Manager vs decK + ArgoCD

| Feature | Kong Manager | decK + ArgoCD |
|---------|-------------|---------------|
| **Security** | Requires exposed Admin API | Admin API on localhost only |
| **Version Control** | Manual exports | Native Git integration |
| **Audit Trail** | Limited | Full Git history |
| **Automation** | Manual clicks | Automatic GitOps |
| **Multi-Environment** | Manual replication | Kustomize overlays |
| **Collaboration** | Single user at a time | Pull request workflow |
| **Rollback** | Manual | Git revert + ArgoCD sync |
| **CI/CD Integration** | Difficult | Native |
| **Learning Curve** | Easy (GUI) | Steeper (YAML + Git) |
| **Production Ready** | No (security concerns) | Yes |

---

## Summary

You've learned how to:

1. ✅ Install and use decK for declarative Kong management
2. ✅ Export Kong configurations to YAML files
3. ✅ Validate and preview changes before applying
4. ✅ Organize configurations into modular files
5. ✅ Integrate decK with ArgoCD for GitOps
6. ✅ Manage multiple environments with Kustomize
7. ✅ Handle secrets securely with External Secrets Operator
8. ✅ Follow best practices for production Kong management

**Next Steps:**

1. Export your current Kong configuration: `deck gateway dump`
2. Store it in a Git repository
3. Create an ArgoCD application to manage it
4. Close port 8001 and use only the decK + ArgoCD workflow

This approach aligns perfectly with the Istio and ArgoCD concepts you've learned, creating a unified GitOps platform for your entire infrastructure!

---

## Additional Resources

- **decK Documentation**: https://docs.konghq.com/deck/
- **Kong Gateway Configuration Reference**: https://docs.konghq.com/gateway/latest/reference/configuration/
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **External Secrets Operator**: https://external-secrets.io/
- **Kustomize**: https://kustomize.io/

---

## Exercise: Hands-On Practice

**Task**: Convert your current Kong Manager setup to decK + ArgoCD

1. Export your Kong configuration using decK
2. Create a Git repository with the exported configuration
3. Create a Kubernetes Job that runs decK sync
4. Create an ArgoCD Application to manage the deployment
5. Make a change to the configuration in Git and observe ArgoCD sync it automatically
6. Roll back the change using Git and verify ArgoCD restores the previous state

**Success Criteria**:
- Kong Admin API is accessible only from localhost
- All configuration changes go through Git
- ArgoCD automatically applies changes
- You can see the full audit trail in Git history
