#!/bin/bash

# S3 Backup Script for Embedded Hive Database
# This script backs up the embedded Hive database to Amazon S3

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
BLADE_STATE_DIR="${BLADE_STATE_DIR:-./.blade/state}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="blade-db-${TIMESTAMP}"
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
S3_BUCKET="${S3_BUCKET:-your-database-bucket}"
S3_PREFIX="${S3_PREFIX:-backups/hive-database}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🌐 Starting S3 Backup for Embedded Hive Database${NC}"
echo "================================================"

# Check AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI not found${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Error: AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Check if blade state directory exists
if [ ! -d "$BLADE_STATE_DIR" ]; then
    echo -e "${RED}❌ Error: Blade state directory not found: $BLADE_STATE_DIR${NC}"
    echo "Make sure you're running this from the project root directory"
    exit 1
fi

# Create local backup directory
mkdir -p "$BACKUP_DIR"

# Create local backup
echo -e "${YELLOW}📦 Creating local backup...${NC}"
tar czf "$BACKUP_FILE" -C "$(dirname "$BLADE_STATE_DIR")" "$(basename "$BLADE_STATE_DIR")"

# Verify local backup was created
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}❌ Error: Local backup failed${NC}"
    exit 1
fi

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo -e "${GREEN}✅ Local backup created: ${BACKUP_FILE} (${BACKUP_SIZE})${NC}"

# Upload to S3
echo -e "${YELLOW}📤 Uploading to S3...${NC}"
S3_KEY="${S3_PREFIX}/${BACKUP_NAME}.tar.gz"

if aws s3 cp "$BACKUP_FILE" "s3://${S3_BUCKET}/${S3_KEY}"; then
    echo -e "${GREEN}✅ Successfully uploaded to S3: s3://${S3_BUCKET}/${S3_KEY}${NC}"
else
    echo -e "${RED}❌ Error: S3 upload failed${NC}"
    exit 1
fi

# Set S3 object metadata
echo -e "${YELLOW}🏷️  Setting S3 metadata...${NC}"
aws s3api put-object-tagging \
    --bucket "$S3_BUCKET" \
    --key "$S3_KEY" \
    --tagging 'Environment=Production&Service=HiveDatabase&BackupType=Automated'

# Cleanup old local backups (keep last 7 days)
echo -e "${YELLOW}🧹 Cleaning up old local backups...${NC}"
find "$BACKUP_DIR" -name "blade-db-*.tar.gz" -mtime +7 -delete

# Cleanup old S3 backups (keep last 30 days)
echo -e "${YELLOW}🧹 Cleaning up old S3 backups...${NC}"
aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" | \
    while read -r line; do
        createDate=$(echo "$line" | awk '{print $1" "$2}')
        createDate=$(date -d "$createDate" +%s)
        olderThan=$(date -d "30 days ago" +%s)
        if [[ $createDate -lt $olderThan ]]; then
            fileName=$(echo "$line" | awk '{print $4}')
            if [[ $fileName != "" ]]; then
                aws s3 rm "s3://${S3_BUCKET}/${S3_PREFIX}/${fileName}"
                echo -e "${YELLOW}Deleted old S3 backup: ${fileName}${NC}"
            fi
        fi
    done

# List recent S3 backups
echo -e "${BLUE}📋 Recent S3 backups:${NC}"
aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/" --recursive | tail -10

echo -e "${GREEN}🎉 S3 backup completed successfully!${NC}"
echo -e "${GREEN}📍 S3 Location: s3://${S3_BUCKET}/${S3_KEY}${NC}"