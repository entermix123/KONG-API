#!/bin/bash

# Deploy to Staging Environment

set -e

echo "=========================================="
echo "Deploying Kong Configuration to STAGING"
echo "=========================================="
echo ""

# Configuration
KONG_ADMIN_URL="${KONG_STAGING_ADMIN_URL:-http://kong-staging.kong.svc.cluster.local:8001}"
CONFIG_FILE="kong.yaml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Environment: STAGING"
echo "Kong Admin URL: $KONG_ADMIN_URL"
echo ""

# Check connectivity
echo "🔍 Checking Kong connectivity..."
if curl -s -f "$KONG_ADMIN_URL/status" > /dev/null; then
    echo -e "${GREEN}✅ Kong is accessible${NC}"
else
    echo -e "${RED}❌ Cannot reach Kong${NC}"
    exit 1
fi
echo ""

# Validate
echo "🔍 Validating configuration..."
if ! deck gateway validate --state "$CONFIG_FILE"; then
    echo -e "${RED}❌ Configuration validation failed${NC}"
    exit 1
fi
echo ""

# Show diff
echo "📊 Changes to be applied:"
deck gateway diff --state "$CONFIG_FILE" --kong-addr "$KONG_ADMIN_URL"
echo ""

# Require explicit confirmation for staging
echo -e "${YELLOW}⚠️  You are deploying to STAGING${NC}"
read -p "Type 'deploy-staging' to confirm: " -r
if [[ $REPLY != "deploy-staging" ]]; then
    echo "Deployment cancelled"
    exit 0
fi
echo ""

# Backup current state
echo "💾 Creating backup..."
BACKUP_FILE="backup-staging-$(date +%Y%m%d-%H%M%S).yaml"
deck gateway dump --kong-addr "$KONG_ADMIN_URL" --output-file "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup saved to: $BACKUP_FILE${NC}"
echo ""

# Apply
echo "🚀 Deploying to STAGING..."
deck gateway sync --state "$CONFIG_FILE" --kong-addr "$KONG_ADMIN_URL"
echo ""

echo "=========================================="
echo -e "${GREEN}✅ Deployment to STAGING completed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Test the changes in staging"
echo "2. If successful, deploy to production: ./scripts/deploy-prod.sh"
echo ""
