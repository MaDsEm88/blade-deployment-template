#!/bin/bash

# Embedded Hive Database Backup Script
# This script backs up the embedded Hive database stored in .blade/state/

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
BLADE_STATE_DIR="${BLADE_STATE_DIR:-./.blade/state}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="blade-db-${TIMESTAMP}"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🗄️  Starting Embedded Hive Database Backup${NC}"
echo "========================================"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Check if blade state directory exists
if [ ! -d "$BLADE_STATE_DIR" ]; then
    echo -e "${RED}❌ Error: Blade state directory not found: $BLADE_STATE_DIR${NC}"
    echo "Make sure you're running this from the project root directory"
    exit 1
fi

# Check if database exists
DB_PATH="$BLADE_STATE_DIR/databases/main/db.sqlite"
if [ ! -f "$DB_PATH" ]; then
    echo -e "${YELLOW}⚠️  Warning: Database file not found: $DB_PATH${NC}"
    echo "The database might not be initialized yet"
fi

# Create backup
echo "Creating backup: $BACKUP_FILE"
tar czf "$BACKUP_FILE" -C "$(dirname "$BLADE_STATE_DIR")" "$(basename "$BLADE_STATE_DIR")"

# Verify backup was created
if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo -e "${GREEN}✅ Backup created successfully!${NC}"
    echo "📁 Location: $BACKUP_FILE"
    echo "📊 Size: $BACKUP_SIZE"
else
    echo -e "${RED}❌ Error: Backup failed to create${NC}"
    exit 1
fi

# Cleanup old backups (keep last 7 days)
echo "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "blade-db-*.tar.gz" -mtime +7 -delete

# List remaining backups
echo -e "${GREEN}📋 Current backups:${NC}"
ls -lh "$BACKUP_DIR"/blade-db-*.tar.gz 2>/dev/null || echo "No backups found"

echo -e "${GREEN}🎉 Backup completed successfully!${NC}"