#!/bin/bash

# Embedded Hive Database Restore Script
# This script restores the embedded Hive database from a backup

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
BLADE_STATE_DIR="${BLADE_STATE_DIR:-./.blade/state}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Embedded Hive Database Restore${NC}"
echo "=================================="

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}❌ Error: Backup directory not found: $BACKUP_DIR${NC}"
    exit 1
fi

# List available backups
echo -e "${GREEN}📋 Available backups:${NC}"
ls -1 "$BACKUP_DIR"/blade-db-*.tar.gz 2>/dev/null | while read -r backup; do
    basename "$backup"
done

# If no backups found
if ! ls "$BACKUP_DIR"/blade-db-*.tar.gz >/dev/null 2>&1; then
    echo -e "${RED}❌ No backups found in $BACKUP_DIR${NC}"
    exit 1
fi

# Ask which backup to restore (or use first argument)
if [ -n "$1" ]; then
    BACKUP_FILE="$BACKUP_DIR/$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Backup file not found: $BACKUP_FILE${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}📝 Please enter the backup filename to restore:${NC}"
    read -p "Backup filename: " BACKUP_FILENAME
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILENAME"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Backup file not found: $BACKUP_FILE${NC}"
        exit 1
    fi
fi

echo -e "${YELLOW}⚠️  WARNING: This will replace the current database!${NC}"
echo "Backup to restore: $BACKUP_FILE"

# Confirm restore
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Restore cancelled${NC}"
    exit 0
fi

# Create backup of current state before restore
CURRENT_BACKUP="$BACKUP_DIR/before-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
if [ -d "$BLADE_STATE_DIR" ]; then
    echo "Creating backup of current state: $CURRENT_BACKUP"
    tar czf "$CURRENT_BACKUP" -C "$(dirname "$BLADE_STATE_DIR")" "$(basename "$BLADE_STATE_DIR")"
fi

# Remove existing state directory
if [ -d "$BLADE_STATE_DIR" ]; then
    echo "Removing existing state directory..."
    rm -rf "$BLADE_STATE_DIR"
fi

# Restore from backup
echo "Restoring database from backup..."
tar xzf "$BACKUP_FILE" -C "$(dirname "$BLADE_STATE_DIR")"

# Verify restore
DB_PATH="$BLADE_STATE_DIR/databases/main/db.sqlite"
if [ -f "$DB_PATH" ]; then
    DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
    echo -e "${GREEN}✅ Database restored successfully!${NC}"
    echo "📁 Database location: $DB_PATH"
    echo "📊 Database size: $DB_SIZE"
    
    # Check database integrity
    if command -v sqlite3 >/dev/null 2>&1; then
        echo "Checking database integrity..."
        if sqlite3 "$DB_PATH" "PRAGMA integrity_check;" | grep -q "ok"; then
            echo -e "${GREEN}✅ Database integrity check passed${NC}"
        else
            echo -e "${YELLOW}⚠️  Database integrity check failed${NC}"
        fi
    fi
else
    echo -e "${RED}❌ Error: Database file not found after restore${NC}"
    exit 1
fi

echo -e "${GREEN}🎉 Restore completed successfully!${NC}"
echo "💡 You can now start your application with the restored database"