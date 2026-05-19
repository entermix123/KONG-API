# decK Quick Reference Cheat Sheet

## Essential Commands

### Export / Backup

```bash
# Export entire Kong configuration
deck gateway dump --output-file kong.yaml

# Export with specific Kong URL
deck gateway dump --kong-addr http://localhost:8001 --output-file kong.yaml

# Export specific workspace (Enterprise)
deck gateway dump --workspace production --output-file kong-prod.yaml

# Export with tags filter
deck gateway dump --select-tag production --output-file kong-prod.yaml
```

### Validate

```bash
# Validate configuration file
deck gateway validate --state kong.yaml

# Validate with verbose output
deck gateway validate --state kong.yaml --verbose

# Validate directory of files
deck gateway validate --state kong-configs/
```

### Preview Changes (Dry Run)

```bash
# Show what would change
deck gateway diff --state kong.yaml

# Diff with specific tags
deck gateway diff --state kong.yaml --select-tag production

# Diff against specific Kong instance
deck gateway diff --state kong.yaml --kong-addr http://kong:8001
```

### Apply Configuration

```bash
# Sync configuration to Kong
deck gateway sync --state kong.yaml

# Sync with specific tags only
deck gateway sync --state kong.yaml --select-tag production

# Sync to specific Kong instance
deck gateway sync --state kong.yaml --kong-addr http://kong:8001

# Sync directory of files
deck gateway sync --state kong-configs/

# Sync with workspace (Enterprise)
deck gateway sync --state kong.yaml --workspace production
```

### Backup & Reset

```bash
# Reset Kong (delete everything)
deck gateway reset --force

# Create backup before making changes
deck gateway dump --output-file backup-$(date +%Y%m%d-%H%M%S).yaml
```

### Ping Kong

```bash
# Check if Kong Admin API is accessible
deck gateway ping

# Ping specific Kong instance
deck gateway ping --kong-addr http://kong:8001
```

## Common Flags

| Flag | Description | Example |
|------|-------------|---------|
| `--state` | Configuration file or directory | `--state kong.yaml` |
| `--kong-addr` | Kong Admin API URL | `--kong-addr http://kong:8001` |
| `--select-tag` | Filter resources by tag | `--select-tag production` |
| `--workspace` | Target workspace (Enterprise) | `--workspace default` |
| `--output-file` | Output file for dump | `--output-file kong.yaml` |
| `--verbose` | Verbose output | `--verbose` |
| `--force` | Skip confirmation prompts | `--force` |

## Environment Variables

```bash
# Set Kong Admin API URL
export DECK_KONG_ADDR=http://localhost:8001

# Set Kong Admin API authentication
export DECK_KONG_ADMIN_TOKEN=your-admin-token

# Set headers for Admin API
export DECK_HEADERS="Kong-Admin-Token:secret"

# Set TLS verification (disable for self-signed certs)
export DECK_TLS_SKIP_VERIFY=true
```

## Configuration File Format

### Minimal Example

```yaml
_format_version: "3.0"

services:
- name: my-service
  url: http://backend:8000
  routes:
  - name: my-route
    paths:
    - /api
```

### Complete Example

```yaml
_format_version: "3.0"
_transform: true

# Services
services:
- name: backend-api
  url: http://backend:8000
  protocol: http
  port: 8000
  connect_timeout: 60000
  write_timeout: 60000
  read_timeout: 60000
  retries: 5
  tags:
  - backend
  - production
  
  # Routes
  routes:
  - name: api-route
    paths:
    - /api
    methods:
    - GET
    - POST
    strip_path: true
    preserve_host: false
    tags:
    - api
  
  # Service-level plugins
  plugins:
  - name: rate-limiting
    config:
      minute: 100
      hour: 1000

# Global plugins
plugins:
- name: cors
  config:
    origins:
    - "*"
    methods:
    - GET
    - POST

# Consumers
consumers:
- username: api-user
  custom_id: user123
  tags:
  - external
  
  # Credentials
  keyauth_credentials:
  - key: secret-api-key
  
  # ACL groups
  acls:
  - group: developers

# Upstreams (load balancing)
upstreams:
- name: backend-upstream
  algorithm: round-robin
  hash_on: none
  hash_fallback: none
  slots: 10000
  healthchecks:
    active:
      healthy:
        interval: 5
        successes: 2
      unhealthy:
        interval: 5
        http_failures: 3
  
  # Targets
  targets:
  - target: backend-1:8000
    weight: 100
  - target: backend-2:8000
    weight: 100

# Certificates
certificates:
- cert: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
  snis:
  - example.com
  - "*.example.com"
```

## Common Workflows

### Initial Setup

```bash
# 1. Install decK
brew install deck  # macOS
# or download from: https://github.com/Kong/deck/releases

# 2. Export current Kong config
deck gateway dump --output-file kong.yaml

# 3. Initialize Git repo
git init
git add kong.yaml
git commit -m "Initial Kong configuration"
```

### Making Changes

```bash
# 1. Edit configuration
vim kong.yaml

# 2. Validate changes
deck gateway validate --state kong.yaml

# 3. Preview changes
deck gateway diff --state kong.yaml

# 4. Apply changes
deck gateway sync --state kong.yaml

# 5. Commit to Git
git add kong.yaml
git commit -m "Add new API endpoint"
git push
```

### Emergency Rollback

```bash
# 1. Find previous working version
git log --oneline

# 2. Checkout previous version
git checkout abc123 -- kong.yaml

# 3. Apply previous configuration
deck gateway sync --state kong.yaml

# 4. Commit rollback
git commit -m "Rollback to previous version"
git push
```

### Multi-Environment Deployment

```bash
# Development
deck gateway sync --state kong.yaml --kong-addr http://kong-dev:8001

# Staging
deck gateway sync --state kong.yaml --kong-addr http://kong-staging:8001

# Production
deck gateway sync --state kong.yaml --kong-addr http://kong-prod:8001
```

## Kong Configuration Patterns

### Service with Multiple Routes

```yaml
services:
- name: api-service
  url: http://backend:8000
  routes:
  - name: public-route
    paths:
    - /public
  - name: authenticated-route
    paths:
    - /private
    plugins:
    - name: jwt
```

### Rate Limiting by Consumer

```yaml
consumers:
- username: free-tier
  plugins:
  - name: rate-limiting
    config:
      minute: 10
      
- username: premium-tier
  plugins:
  - name: rate-limiting
    config:
      minute: 1000
```

### Load Balanced Service

```yaml
upstreams:
- name: backend-cluster
  targets:
  - target: backend-1:8000
    weight: 100
  - target: backend-2:8000
    weight: 100

services:
- name: api-service
  host: backend-cluster  # Reference upstream
  routes:
  - paths:
    - /api
```

### Authentication Chain

```yaml
services:
- name: secure-api
  plugins:
  - name: jwt  # First authenticate
  - name: acl  # Then check authorization
    config:
      allow:
      - admin-group
```

## Troubleshooting

### Connection Issues

```bash
# Test connectivity
deck gateway ping --kong-addr http://kong:8001

# Check Kong status
curl http://kong:8001/status

# Verify network
kubectl exec -it deploy/app -- curl http://kong-admin.kong.svc:8001/status
```

### Configuration Errors

```bash
# Validate before applying
deck gateway validate --state kong.yaml

# Check for syntax errors
yamllint kong.yaml

# View detailed error messages
deck gateway sync --state kong.yaml --verbose
```

### State Mismatch

```bash
# See current Kong state
deck gateway dump --output-file current.yaml

# Compare with desired state
diff kong.yaml current.yaml

# Force sync (overwrite Kong)
deck gateway sync --state kong.yaml
```

### Missing Resources

```bash
# Export everything including defaults
deck gateway dump --with-id --output-file kong-full.yaml

# Check specific resource
curl http://kong:8001/services/my-service
curl http://kong:8001/routes/my-route
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: Deploy Kong Config

on:
  push:
    branches:
    - main
    paths:
    - 'kong-config/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Install decK
      run: |
        curl -sL https://github.com/Kong/deck/releases/latest/download/deck_linux_amd64.tar.gz -o deck.tar.gz
        tar -xf deck.tar.gz
        sudo mv deck /usr/local/bin/
    
    - name: Validate
      run: deck gateway validate --state kong-config/
    
    - name: Deploy to Staging
      run: deck gateway sync --state kong-config/ --kong-addr ${{ secrets.KONG_STAGING_URL }}
      
    - name: Deploy to Production
      if: github.ref == 'refs/heads/main'
      run: deck gateway sync --state kong-config/ --kong-addr ${{ secrets.KONG_PROD_URL }}
```

### GitLab CI Example

```yaml
stages:
  - validate
  - deploy

validate:
  stage: validate
  image: kong/deck:latest
  script:
    - deck gateway validate --state kong-config/

deploy-staging:
  stage: deploy
  image: kong/deck:latest
  script:
    - deck gateway sync --state kong-config/ --kong-addr $KONG_STAGING_URL
  only:
    - develop

deploy-production:
  stage: deploy
  image: kong/deck:latest
  script:
    - deck gateway sync --state kong-config/ --kong-addr $KONG_PROD_URL
  only:
    - main
  when: manual
```

## Tips & Best Practices

### 1. Use Tags for Organization

```yaml
services:
- name: my-service
  tags:
  - team:backend
  - env:production
  - owner:john
```

### 2. Split Large Configurations

Instead of one huge file:
```
kong-config/
├── services/
│   ├── user-api.yaml
│   └── payment-api.yaml
├── plugins/
│   └── global-cors.yaml
└── consumers/
    └── partners.yaml
```

### 3. Version Your Configurations

```yaml
# Include version in service name or tag
services:
- name: api-v1
  tags:
  - version:1.0.0
```

### 4. Use Environment Variables for Secrets

```yaml
consumers:
- username: api-user
  keyauth_credentials:
  - key: $KONG_API_KEY
```

### 5. Regular Backups

```bash
# Daily backup cron job
0 0 * * * deck gateway dump --output-file /backups/kong-$(date +\%Y\%m\%d).yaml
```

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `connection refused` | Kong Admin API not accessible | Check Kong is running, verify URL |
| `invalid config` | YAML syntax error | Run `deck gateway validate` |
| `entity already exists` | Duplicate name/ID | Check for duplicates in config |
| `foreign key constraint` | Missing referenced entity | Ensure services exist before routes |
| `unauthorized` | Missing auth token | Set `DECK_KONG_ADMIN_TOKEN` |

## Version Compatibility

| decK Version | Kong Version | Format Version |
|--------------|--------------|----------------|
| 1.28+ | 3.x | 3.0 |
| 1.12-1.27 | 2.x | 1.1 |
| <1.12 | 1.x | 1.1 |

Check versions:
```bash
deck version
curl http://kong:8001 | jq .version
```
