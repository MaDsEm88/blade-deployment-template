#!/bin/bash

# Check deployment setup for Railway, Cloudflare, and Fly.io
# This script verifies that CLI tools are installed and authenticated

set -e

echo "🔍 Checking deployment setup..."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track overall status
ALL_GOOD=true

# Check Railway
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Railway.app"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v railway &> /dev/null; then
    echo -e "${GREEN}✓${NC} Railway CLI installed"
    
    if railway whoami &> /dev/null; then
        echo -e "${GREEN}✓${NC} Railway authenticated"
        railway whoami 2>/dev/null || true
    else
        echo -e "${RED}✗${NC} Railway not authenticated"
        echo -e "${YELLOW}→${NC} Run: railway login"
        ALL_GOOD=false
    fi
else
    echo -e "${RED}✗${NC} Railway CLI not installed"
    echo -e "${YELLOW}→${NC} Install: npm install -g @railway/cli"
    echo -e "${YELLOW}→${NC} Or run: bun run setup:railway"
    ALL_GOOD=false
fi
echo ""

# Check Cloudflare/Wrangler
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cloudflare Workers"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if bun x wrangler whoami &> /dev/null; then
    echo -e "${GREEN}✓${NC} Wrangler authenticated"
    bun x wrangler whoami 2>/dev/null || true
else
    echo -e "${RED}✗${NC} Wrangler not authenticated"
    echo -e "${YELLOW}→${NC} Run: bun x wrangler login"
    echo -e "${YELLOW}→${NC} Or run: bun run setup:cloudflare"
    ALL_GOOD=false
fi
echo ""

# Check Fly.io
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fly.io"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v flyctl &> /dev/null; then
    echo -e "${GREEN}✓${NC} flyctl installed"
    
    if flyctl auth whoami &> /dev/null; then
        echo -e "${GREEN}✓${NC} Fly.io authenticated"
        flyctl auth whoami 2>/dev/null || true
    else
        echo -e "${RED}✗${NC} Fly.io not authenticated"
        echo -e "${YELLOW}→${NC} Run: flyctl auth login"
        ALL_GOOD=false
    fi
else
    echo -e "${RED}✗${NC} flyctl not installed"
    echo -e "${YELLOW}→${NC} Install: curl -L https://fly.io/install.sh | sh"
    echo -e "${YELLOW}→${NC} Or run: bun run setup:fly"
    ALL_GOOD=false
fi
echo ""

# Final summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✓ All deployment tools are set up correctly!${NC}"
    echo ""
    echo "You can now deploy with:"
    echo "  • bun run deploy:railway"
    echo "  • bun run deploy:cloudflare"
    echo "  • bun run deploy:fly"
else
    echo -e "${RED}✗ Some deployment tools need setup${NC}"
    echo ""
    echo "Run: bun run setup:fix"
    echo "Or see: DEPLOYMENT.md for detailed instructions"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
