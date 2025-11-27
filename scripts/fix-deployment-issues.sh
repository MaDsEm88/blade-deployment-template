#!/bin/bash

# Quick fix script for common deployment issues
# This script helps resolve authentication and CLI installation problems

set -e

echo "🔧 Deployment Issue Resolver"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ask which platform
echo "Which platform are you having issues with?"
echo ""
echo "1) Railway.app"
echo "2) Cloudflare Workers"
echo "3) Fly.io"
echo "4) Sliplane"
echo "5) All of them (full setup)"
echo ""
read -p "Enter number (1-5): " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}━━━ Railway.app Setup ━━━${NC}"
        echo ""
        
        # Check if Railway CLI is installed
        if ! command -v railway &> /dev/null; then
            echo -e "${YELLOW}Installing Railway CLI globally...${NC}"
            npm install -g @railway/cli
            echo -e "${GREEN}✓ Railway CLI installed${NC}"
        else
            echo -e "${GREEN}✓ Railway CLI already installed${NC}"
        fi
        
        echo ""
        echo -e "${YELLOW}Starting Railway authentication...${NC}"
        railway login
        
        echo ""
        echo -e "${GREEN}✓ Railway setup complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Create a project: railway init"
        echo "2. Link to project: railway link"
        echo "3. Deploy: bun run deploy:railway"
        ;;
        
    2)
        echo ""
        echo -e "${BLUE}━━━ Cloudflare Workers Setup ━━━${NC}"
        echo ""
        
        echo -e "${YELLOW}Starting Wrangler authentication...${NC}"
        node_modules/.bin/wrangler login

echo ""
echo -e "${YELLOW}Verifying authentication...${NC}"
node_modules/.bin/wrangler whoami
        
        echo ""
        echo -e "${GREEN}✓ Cloudflare setup complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "1. Deploy: bun run deploy:cloudflare"
echo "2. Set secrets: node_modules/.bin/wrangler secret put BLADE_AUTH_SECRET"
        ;;
        
    3)
        echo ""
        echo -e "${BLUE}━━━ Fly.io Setup ━━━${NC}"
        echo ""

        # Check if flyctl is installed
        if ! command -v flyctl &> /dev/null; then
            echo -e "${YELLOW}flyctl is not installed.${NC}"
            echo ""
            echo "Please install flyctl using one of these methods:"
            echo ""
            echo "Linux/WSL:"
            echo "  curl -L https://fly.io/install.sh | sh"
            echo ""
            echo "macOS:"
            echo "  brew install flyctl"
            echo ""
            echo "Windows:"
            echo "  powershell -Command \"iwr https://fly.io/install.ps1 -useb | iex\""
            echo ""
            read -p "Press Enter after installing flyctl..."
        fi

        if command -v flyctl &> /dev/null; then
            echo ""
            echo -e "${YELLOW}Starting Fly.io authentication...${NC}"
            flyctl auth login

            echo ""
            echo -e "${GREEN}✓ Fly.io setup complete!${NC}"
            echo ""
            echo "Next steps:"
            echo "1. Create volume: flyctl volumes create blade_data --size 1"
            echo "2. Set secrets: flyctl secrets set BLADE_AUTH_SECRET=your-secret"
            echo "3. Deploy: flyctl deploy"
        else
            echo -e "${RED}✗ flyctl not found. Please install it first.${NC}"
            exit 1
        fi
        ;;

    4)
        echo ""
        echo -e "${BLUE}━━━ Sliplane Setup ━━━${NC}"
        echo ""

        # Check if sliplane CLI is installed
        if ! command -v sliplane &> /dev/null; then
            echo -e "${YELLOW}Sliplane CLI is not installed.${NC}"
            echo ""
            echo "Please install sliplane-cli using:"
            echo "  brew install sliplane-cli"
            echo ""
            echo "Or download from: https://sliplane.io/docs/getting-started/installation"
            echo ""
            read -p "Press Enter after installing sliplane-cli..."
        fi

        if command -v sliplane &> /dev/null; then
            echo ""
            echo -e "${YELLOW}Starting Sliplane authentication...${NC}"
            sliplane auth login

            echo ""
            echo -e "${GREEN}✓ Sliplane setup complete!${NC}"
            echo ""
            echo "Next steps:"
            echo "1. Create project: sliplane project create --name my-project"
            echo "2. Create app: sliplane app create --name blade-hive-app"
            echo "3. Set env vars: sliplane app set-env BLADE_AUTH_SECRET=your-secret --name blade-hive-app"
            echo "4. Deploy: bun run deploy:sliplane"
            echo ""
            echo "For detailed instructions, see: SLIPLANE.md"
        else
            echo -e "${RED}✗ sliplane-cli not found. Please install it first.${NC}"
            exit 1
        fi
        ;;

    5)
        echo ""
        echo -e "${BLUE}━━━ Full Platform Setup ━━━${NC}"
        echo ""
        
        # Railway
        echo -e "${YELLOW}[1/4] Setting up Railway...${NC}"
        if ! command -v railway &> /dev/null; then
            npm install -g @railway/cli
        fi
        railway login || true
        
        # Cloudflare
        echo ""
        echo -e "${YELLOW}[2/4] Setting up Cloudflare...${NC}"
        node_modules/.bin/wrangler login || true
        
        # Fly.io
        echo ""
        echo -e "${YELLOW}[3/4] Setting up Fly.io...${NC}"
        if command -v flyctl &> /dev/null; then
            flyctl auth login || true
        else
            echo -e "${YELLOW}flyctl not installed - skipping${NC}"
            echo "Install from: https://fly.io/docs/hands-on/install-flyctl/"
        fi
        
        # Sliplane
        echo ""
        echo -e "${YELLOW}[4/4] Setting up Sliplane...${NC}"
        if command -v sliplane &> /dev/null; then
            sliplane auth login || true
        else
            echo -e "${YELLOW}sliplane-cli not installed - skipping${NC}"
            echo "Install from: brew install sliplane-cli"
        fi
        
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ Setup complete!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        ;;
        
    *)
        echo -e "${RED}Invalid choice. Please run again and select 1-5.${NC}"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "For detailed instructions, see: DEPLOYMENT_SETUP.md"
echo "To check all platforms: bun run setup:check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
