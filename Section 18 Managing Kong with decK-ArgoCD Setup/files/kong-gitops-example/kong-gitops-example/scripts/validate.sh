#!/bin/bash

# Kong Configuration Validation Script
# This script validates the Kong configuration before deployment

set -e

echo "=========================================="
echo "Kong Configuration Validation"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if decK is installed
if ! command -v deck &> /dev/null; then
    echo -e "${RED}❌ decK is not installed${NC}"
    echo "Install it from: https://github.com/Kong/deck/releases"
    exit 1
fi

echo -e "${GREEN}✅ decK is installed${NC}"
echo "decK version: $(deck version)"
echo ""

# Validate Kong configuration
echo "🔍 Validating Kong configuration..."
if deck gateway validate --state kong.yaml; then
    echo -e "${GREEN}✅ Kong configuration is valid${NC}"
else
    echo -e "${RED}❌ Kong configuration validation failed${NC}"
    exit 1
fi
echo ""

# Check YAML syntax
echo "🔍 Checking YAML syntax..."
if command -v yamllint &> /dev/null; then
    if yamllint -d relaxed kong.yaml; then
        echo -e "${GREEN}✅ YAML syntax is valid${NC}"
    else
        echo -e "${YELLOW}⚠️  YAML has some formatting issues (non-critical)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  yamllint not installed, skipping YAML syntax check${NC}"
fi
echo ""

# Check for common issues
echo "🔍 Checking for common issues..."

# Check for hardcoded secrets
if grep -E '(password|secret|key):.*[a-zA-Z0-9]{8,}' kong.yaml | grep -v '\$'; then
    echo -e "${RED}❌ Found hardcoded secrets in configuration!${NC}"
    echo "Use environment variables instead (e.g., \$KONG_API_KEY)"
    exit 1
else
    echo -e "${GREEN}✅ No hardcoded secrets found${NC}"
fi

# Check for environment variable usage
if grep -E '\$[A-Z_]+' kong.yaml > /dev/null; then
    echo -e "${GREEN}✅ Using environment variables for secrets${NC}"
    echo "Required environment variables:"
    grep -oE '\$[A-Z_]+' kong.yaml | sort -u | sed 's/^/  - /'
else
    echo -e "${YELLOW}⚠️  No environment variables found${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo -e "${GREEN}✅ Validation completed successfully!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Commit your changes: git add kong.yaml && git commit -m 'Update Kong config'"
echo "2. Push to Git: git push origin main"
echo "3. ArgoCD will automatically sync the changes"
echo ""
