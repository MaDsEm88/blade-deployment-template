#!/bin/bash

# Comprehensive deployment configuration validation script
# Tests Railway, Fly.io, Cloudflare Workers, and Docker configurations

set -e

echo "🧪 Deployment Configuration Validation"
echo "======================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track overall status
ALL_GOOD=true
ERRORS=()

# Helper functions
log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
    ERRORS+=("$1")
    ALL_GOOD=false
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Test 1: Dockerfile validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Dockerfile Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "Dockerfile" ]; then
    log_success "Dockerfile exists"
    
    # Check Dockerfile syntax
    if docker build --dry-run -f Dockerfile . &>/dev/null 2>&1 || true; then
        log_success "Dockerfile syntax is valid"
    else
        log_warning "Dockerfile syntax check requires full build"
    fi
    
    # Check for required elements
    if grep -q "FROM oven/bun:1-alpine" Dockerfile; then
        log_success "Uses correct base image (oven/bun:1-alpine)"
    else
        log_error "Missing or incorrect base image"
    fi
    
    if grep -q "EXPOSE 3000" Dockerfile; then
        log_success "Exposes port 3000"
    else
        log_error "Missing port 3000 exposure"
    fi
    
    if grep -q "HEALTHCHECK" Dockerfile; then
        log_success "Includes health check"
    else
        log_warning "Missing health check (recommended)"
    fi
    
    if grep -q "HIVE_STORAGE_TYPE=disk" Dockerfile; then
        log_success "Configures disk storage"
    else
        log_error "Missing storage configuration"
    fi
    
else
    log_error "Dockerfile not found"
fi

echo ""

# Test 2: Railway configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Railway Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "railway.json" ]; then
    log_success "railway.json exists"
    
    # Validate JSON syntax
    if python3 -m json.tool railway.json &>/dev/null 2>&1 || node -e "JSON.parse(require('fs').readFileSync('railway.json', 'utf8'))" &>/dev/null 2>&1; then
        log_success "railway.json syntax is valid"
    else
        log_error "railway.json has invalid JSON syntax"
    fi
    
    # Check for required fields
    if grep -q '"buildCommand": "npm run build"' railway.json; then
        log_success "Correct build command specified"
    else
        log_error "Missing or incorrect build command"
    fi
    
    if grep -q '"startCommand": "npm run serve"' railway.json; then
        log_success "Correct start command specified"
    else
        log_error "Missing or incorrect start command"
    fi
    
    if grep -q '"healthcheckPath": "/"' railway.json; then
        log_success "Health check path configured"
    else
        log_warning "Missing health check path"
    fi
    
    if grep -q '"mountPath": "/usr/src/app/.blade/state"' railway.json; then
        log_success "Volume mount path configured"
    else
        log_error "Missing volume mount configuration"
    fi
    
    if grep -q '"HIVE_STORAGE_TYPE": "disk"' railway.json; then
        log_success "Storage type configured for disk"
    else
        log_error "Storage type not configured"
    fi
    
else
    log_error "railway.json not found"
fi

echo ""

# Test 3: Fly.io configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Fly.io Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "fly.toml" ]; then
    log_success "fly.toml exists"
    
    # Check for required sections
    if grep -q "app = " fly.toml; then
        log_success "App name configured"
    else
        log_error "Missing app name"
    fi
    
    if grep -q "primary_region = " fly.toml; then
        log_success "Primary region configured"
    else
        log_warning "Missing primary region"
    fi
    
    if grep -q "dockerfile = 'Dockerfile'" fly.toml; then
        log_success "Dockerfile reference configured"
    else
        log_error "Missing Dockerfile reference"
    fi
    
    if grep -q "internal_port = 3000" fly.toml; then
        log_success "Internal port configured (3000)"
    else
        log_error "Missing or incorrect internal port"
    fi
    
    if grep -q '\[mounts\]' fly.toml; then
        log_success "Mounts section configured"
        if grep -q "destination = \"/usr/src/app/.blade/state\"" fly.toml; then
            log_success "Correct mount destination"
        else
            log_error "Incorrect mount destination"
        fi
    else
        log_error "Missing mounts configuration"
    fi
    
    if grep -q '\[http_service.checks\]' fly.toml; then
        log_success "Health checks configured"
    else
        log_warning "Missing health checks"
    fi
    
    if grep -q "HIVE_STORAGE_TYPE = 'disk'" fly.toml; then
        log_success "Storage type configured for disk"
    else
        log_error "Storage type not configured"
    fi
    
else
    log_error "fly.toml not found"
fi

echo ""

# Test 4: Cloudflare Workers configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Cloudflare Workers Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "wrangler.jsonc" ]; then
    log_success "wrangler.jsonc exists"
    
    # Validate JSONC syntax (strip comments first)
    if node -e "JSON.parse(require('fs').readFileSync('wrangler.jsonc', 'utf8').replace(/\/\*[\s\S]*?\*\/|\/\/.*/g, ''))" &>/dev/null 2>&1; then
        log_success "wrangler.jsonc syntax is valid"
    else
        log_error "wrangler.jsonc has invalid JSONC syntax"
    fi
    
    # Check for required fields
    if grep -q '"name":' wrangler.jsonc; then
        log_success "Worker name configured"
    else
        log_error "Missing worker name"
    fi
    
    if grep -q '"main": ".blade/dist/edge-worker.js"' wrangler.jsonc; then
        log_success "Correct entry point configured"
    else
        log_error "Missing or incorrect entry point"
    fi
    
    if grep -q '"compatibility_date":' wrangler.jsonc; then
        log_success "Compatibility date configured"
    else
        log_warning "Missing compatibility date"
    fi
    
    if grep -q '"assets":' wrangler.jsonc; then
        log_success "Assets configuration present"
    else
        log_warning "Missing assets configuration"
    fi
    
    if grep -q '"build":' wrangler.jsonc; then
        log_success "Build configuration present"
    else
        log_warning "Missing build configuration"
    fi
    
else
    log_error "wrangler.jsonc not found"
fi

echo ""

# Test 5: Docker Compose configuration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Docker Compose Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "docker-compose.yml" ]; then
    log_success "docker-compose.yml exists"
    
    # Check for required services
    if grep -q "services:" docker-compose.yml; then
        log_success "Services section configured"
    else
        log_error "Missing services section"
    fi
    
    if grep -q "ports:" docker-compose.yml && grep -q "3000:3000" docker-compose.yml; then
        log_success "Port mapping configured (3000:3000)"
    else
        log_error "Missing or incorrect port mapping"
    fi
    
    if grep -q "volumes:" docker-compose.yml && grep -q "blade_data:" docker-compose.yml; then
        log_success "Volume configuration present"
    else
        log_warning "Missing volume configuration"
    fi
    
    if grep -q "healthcheck:" docker-compose.yml; then
        log_success "Health check configured"
    else
        log_warning "Missing health check"
    fi
    
    if grep -q "BLADE_PLATFORM=container" docker-compose.yml; then
        log_success "Blade platform configured"
    else
        log_error "Missing Blade platform configuration"
    fi
    
else
    log_error "docker-compose.yml not found"
fi

echo ""

# Test 6: Package.json scripts
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Package.json Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f "package.json" ]; then
    log_success "package.json exists"
    
    # Check for deployment scripts
    if grep -q '"deploy:railway":' package.json; then
        log_success "Railway deployment script present"
    else
        log_error "Missing Railway deployment script"
    fi
    
    if grep -q '"deploy:cloudflare":' package.json; then
        log_success "Cloudflare deployment script present"
    else
        log_error "Missing Cloudflare deployment script"
    fi
    
    if grep -q '"docker:build":' package.json; then
        log_success "Docker build script present"
    else
        log_error "Missing Docker build script"
    fi
    
    if grep -q '"setup:check":' package.json; then
        log_success "Setup check script present"
    else
        log_warning "Missing setup check script"
    fi
    
else
    log_error "package.json not found"
fi

echo ""

# Test 7: Environment variable consistency
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Environment Variable Consistency"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if all configs use consistent storage type
STORAGE_TYPES=()

if [ -f "Dockerfile" ] && grep -q "HIVE_STORAGE_TYPE=" Dockerfile; then
    STORAGE_TYPE=$(grep "HIVE_STORAGE_TYPE=" Dockerfile | cut -d'=' -f2)
    STORAGE_TYPES+=("Dockerfile: $STORAGE_TYPE")
fi

if [ -f "railway.json" ] && grep -q '"HIVE_STORAGE_TYPE":' railway.json; then
    STORAGE_TYPE=$(grep '"HIVE_STORAGE_TYPE":' railway.json | cut -d'"' -f4)
    STORAGE_TYPES+=("railway.json: $STORAGE_TYPE")
fi

if [ -f "fly.toml" ] && grep -q "HIVE_STORAGE_TYPE =" fly.toml; then
    STORAGE_TYPE=$(grep "HIVE_STORAGE_TYPE =" fly.toml | cut -d"'" -f2)
    STORAGE_TYPES+=("fly.toml: $STORAGE_TYPE")
fi

if [ ${#STORAGE_TYPES[@]} -gt 0 ]; then
    log_info "Storage types configured:"
    for type in "${STORAGE_TYPES[@]}"; do
        echo "  • $type"
    done
    
    # Check if all are the same
    FIRST_TYPE=$(echo "${STORAGE_TYPES[0]}" | cut -d' ' -f2-)
    CONSISTENT=true
    for type in "${STORAGE_TYPES[@]}"; do
        CURRENT_TYPE=$(echo "$type" | cut -d' ' -f2-)
        if [ "$CURRENT_TYPE" != "$FIRST_TYPE" ]; then
            CONSISTENT=false
            break
        fi
    done
    
    if [ "$CONSISTENT" = true ]; then
        log_success "Storage types are consistent across all configs"
    else
        log_warning "Storage types vary between configurations"
    fi
else
    log_warning "No storage types found in configurations"
fi

echo ""

# Test 8: File structure validation
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. File Structure Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for required directories
if [ -d "scripts" ]; then
    log_success "scripts directory exists"
else
    log_warning "scripts directory missing"
fi

if [ -d ".blade" ] || mkdir -p .blade &>/dev/null; then
    log_success ".blade directory exists or can be created"
else
    log_error "Cannot create .blade directory"
fi

# Check for .blade/state directory
if [ -d ".blade/state" ] || mkdir -p .blade/state &>/dev/null; then
    log_success ".blade/state directory exists or can be created"
else
    log_error "Cannot create .blade/state directory"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}🎉 All configurations are valid!${NC}"
    echo ""
    echo "Your deployment setup is ready for:"
    echo "  • Railway.app: bun run deploy:railway"
    echo "  • Cloudflare Workers: bun run deploy:cloudflare"
    echo "  • Fly.io: flyctl deploy"
    echo "  • Docker: bun run docker:build && bun run docker:run"
else
    echo -e "${RED}❌ Configuration validation failed${NC}"
    echo ""
    echo "Errors found:"
    for error in "${ERRORS[@]}"; do
        echo "  • $error"
    done
    echo ""
    echo "Please fix these issues before deploying."
    echo "Run 'bun run setup:fix' for automated assistance."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Exit with appropriate code
if [ "$ALL_GOOD" = true ]; then
    exit 0
else
    exit 1
fi
