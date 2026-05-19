#!/bin/bash

# Deploy to Development Environment

set -e

echo "=========================================="
echo "Deploying Kong Configuration to DEV"
echo "=========================================="
echo ""

# Configuration
KONG_ADMIN_URL="${KONG_DEV_ADMIN_URL:-http://kong-dev.kong.svc.cluster.local:8001}"
CONFIG_FILE="kong.yaml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Environment: DEVELOPMENT"
echo "Kong Admin URL: $KONG_ADMIN_URL"
echo ""

# Check connectivity
echo "🔍 Checking Kong connectivity..."
if curl -s -f "$KONG_ADMIN_URL/status" > /dev/null; then
    echo -e "${GREEN}✅ Kong is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Cannot reach Kong. Make sure you're connected to the cluster${NC}"
    echo "Tip: kubectl port-forward -n kong svc/kong-admin 8001:8001"
    exit 1
fi
echo ""

# Validate
echo "🔍 Validating configuration..."
deck gateway validate --state "$CONFIG_FILE"
echo ""

# Show diff
echo "📊 Changes to be applied:"
deck gateway diff --state "$CONFIG_FILE" --kong-addr "$KONG_ADMIN_URL"
echo ""

# Confirm
read -p "Do you want to apply these changes to DEV? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi
echo ""

# Apply
echo "🚀 Deploying to DEV..."
deck gateway sync --state "$CONFIG_FILE" --kong-addr "$KONG_ADMIN_URL"
echo ""

echo "=========================================="
echo -e "${GREEN}✅ Deployment to DEV completed!${NC}"
echo "=========================================="
echo ""
echo "Test your changes:"
echo "  curl http://kong-dev:8000/api/v1/public"
echo ""
