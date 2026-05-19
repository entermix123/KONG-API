#!/bin/bash

# Deploy to Production Environment
# This script includes extra safety checks for production deployments

set -e

echo "=========================================="
echo "Deploying Kong Configuration to PRODUCTION"
echo "=========================================="
echo ""

# Configuration
KONG_ADMIN_URL="${KONG_PROD_ADMIN_URL:-http://kong-admin.kong.svc.cluster.local:8001}"
CONFIG_FILE="kong.yaml"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Environment: PRODUCTION"
echo "Kong Admin URL: $KONG_ADMIN_URL"
echo ""

# Pre-flight checks
echo "🔍 Running pre-flight checks..."

# 1. Check if on main branch
if [ -d .git ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    if [ "$CURRENT_BRANCH" != "main" ] && [ "$CURRENT_BRANCH" != "master" ]; then
        echo -e "${RED}❌ Not on main branch. Current branch: $CURRENT_BRANCH${NC}"
        echo "Production deployments must be from main/master branch"
        exit 1
    fi
    echo -e "${GREEN}✅ On main branch${NC}"
fi

# 2. Check for uncommitted changes
if [ -d .git ]; then
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}❌ Uncommitted changes detected${NC}"
        echo "Commit all changes before deploying to production"
        exit 1
    fi
    echo -e "${GREEN}✅ No uncommitted changes${NC}"
fi

# 3. Check Kong connectivity
echo -e "\n🔍 Checking Kong connectivity..."
if ! curl -s -f "$KONG_ADMIN_URL/status" > /dev/null; then
    echo -e "${RED}❌ Cannot reach Kong${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kong is accessible${NC}"

# 4. Validate configuration
echo -e "\n🔍 Validating configuration..."
if ! deck gateway validate --state "$CONFIG_FILE"; then
    echo -e "${RED}❌ Configuration validation failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Configuration is valid${NC}"
echo ""

# 5. Show diff
echo "📊 Changes to be applied to PRODUCTION:"
echo "=========================================="
deck gateway diff --state "$CONFIG_FILE" --kong-addr "$KONG_ADMIN_URL"
echo "=========================================="
echo ""

# Multiple confirmation steps
echo -e "${RED}⚠️  WARNING: You are deploying to PRODUCTION${NC}"
echo ""
read -p "Have you tested these changes in staging? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Please test in staging first"
    exit 0
fi

echo ""
read -p "Type the full environment name 'PRODUCTION' to confirm: " -r
if [[ $REPLY != "PRODUCTION" ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Create backup
echo ""
echo "💾 Creating backup..."
BACKUP_FILE="backup-production-$(date +%Y%m%d-%H%M%S).yaml"
deck gateway dump --kong-addr "$KONG_ADMIN_URL" --output-file "$BACKUP_FILE"
echo -e "${GREEN}✅ Backup saved to: $BACKUP_FILE${NC}"
echo ""

# Final confirmation
read -p "Final confirmation - deploy to PRODUCTION? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy]es$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi
echo ""

# Apply changes
echo "🚀 Deploying to PRODUCTION..."
if deck gateway sync --state "$CONFIG_FILE" --kong-addr "$KONG_ADMIN_URL"; then
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ Deployment to PRODUCTION completed!${NC}"
    echo "=========================================="
    echo ""
    
    # Save deployment record
    if [ -d .git ]; then
        COMMIT_SHA=$(git rev-parse HEAD)
        echo "Deployed commit: $COMMIT_SHA" >> deployments.log
        echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")" >> deployments.log
        echo "Backup: $BACKUP_FILE" >> deployments.log
        echo "---" >> deployments.log
    fi
    
    echo "Deployment details logged to: deployments.log"
    echo "Backup available at: $BACKUP_FILE"
    echo ""
    echo "🔍 Monitor your services for any issues"
    echo "To rollback: deck gateway sync --state $BACKUP_FILE --kong-addr $KONG_ADMIN_URL"
else
    echo ""
    echo -e "${RED}❌ Deployment failed!${NC}"
    echo "To rollback: deck gateway sync --state $BACKUP_FILE --kong-addr $KONG_ADMIN_URL"
    exit 1
fi
