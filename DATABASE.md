# Database Guide

This guide covers the embedded Hive database for your Blade application.

## Overview

Your application uses two database systems:

1. **Embedded Hive Database** - Primary storage for application data

## Embedded Hive Database

### Architecture

Hive is embedded directly into the Blade framework and stores data in the `.blade/state/` directory using SQLite.

### Storage Configuration

The database supports multiple storage backends configured via environment variables:

#### Disk Storage (Default)
```bash
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state
```

#### S3 Storage
```bash
HIVE_STORAGE_TYPE=s3
HIVE_S3_BUCKET=my-database-bucket
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_REGION=us-east-1
```

#### Remote API Storage
```bash
HIVE_STORAGE_TYPE=remote
REMOTE_STORAGE_ENDPOINT=https://api.example.com/storage
REMOTE_STORAGE_API_KEY=your-key
```

#### Replication Storage (Hybrid)
```bash
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async      # sync or async
HIVE_CONFLICT_RESOLUTION=latest   # latest, primary, replica
```

### Database Operations

#### Status Check
```bash
bun run storage:status
```

#### Backup
```bash
# Quick backup
bun run db:backup

# Full backup with script
bun run db:backup:script

# Backup to S3
bun run db:backup:s3
```

#### Restore
```bash
bun run db:restore
```

#### Migration
```bash
bun run migrate          # Apply migrations
bun run migrate:check    # Check pending migrations
```

### Database Schema

The schema is defined in `schema/index.ts` with Blade schema definitions:

```typescript
// Account model
export const Account = schema.table({
  id: schema.string(),
  email: schema.string(),
  password: schema.string(),
  handle: schema.string(),
  emailVerified: schema.boolean(),
  // ... other fields
});

// Session model
export const Session = schema.table({
  id: schema.string(),
  account: schema.string(),
  browser: schema.string(),
  // ... other fields
});
```

### Database Features

- **Embedded**: No external database required
- **SQLite**: Reliable, file-based storage
- **Migrations**: Automatic schema migrations
- **Backups**: Built-in backup and restore
- **Multi-storage**: Disk, S3, Remote, Replication
- **Encryption**: Optional data encryption



#### Upload to Remote Storage
```bash
bun run db:sync:upload
```

#### Download from Remote Storage
```bash
bun run db:sync:download
```

#### Sync Status
```bash
bun run db:sync:status
```

## Backup and Recovery

### Automated Backups

#### Local Backup Script
```bash
#!/bin/bash
# Creates timestamped backup in backups/ directory
./scripts/backup-db.sh
```

#### S3 Backup Script
```bash
#!/bin/bash
# Uploads backup to S3
./scripts/backup-to-s3.sh
```

### Manual Backup

```bash
# Create backup
cp -r .blade/state backup-$(date +%Y%m%d-%H%M%S)

# Using storage configuration
node -e "
import { getHiveStorageConfig } from './lib/hive-storage-config.js';
const config = await getHiveStorageConfig();
await config.createBackup('manual-backup');
"
```

### Recovery

#### From Local Backup
```bash
# Stop application
# Restore data
cp -r backup-20240101-120000/.blade/state .blade/
# Start application
```

#### From Script
```bash
./scripts/restore-db.sh backup-file.tar.gz
```

## Performance Optimization

### Hive Database

1. **Storage Type**: Use appropriate storage for workload
   - Disk: Best performance, local only
   - S3: Durable, slower, multi-region
   - Replication: Best of both worlds

2. **Indexing**: Add indexes for frequent queries
3. **Connection Pooling**: Managed automatically
4. **Caching**: Built-in caching layer


## Security

### Hive Database

1. **Encryption**: Enable with `HIVE_ENCRYPTION_KEY`
2. **Access Control**: File system permissions
3. **Network**: Local access only (unless using remote storage)
4. **Backups**: Encrypt backup files

## Monitoring

### Health Checks

```bash
# Check Hive storage health
bun run storage:status

# Check database status
bun run db:status
```

### Logs

- Application logs include database operations
- Storage operations are logged with timestamps

### Metrics

- Query response times
- Storage usage
- Backup success/failure rates
- Sync operation status

## Troubleshooting

### Common Issues

**Database Connection Failed**
- Check storage configuration
- Verify file permissions
- Ensure sufficient disk space

**Migration Errors**
- Check schema compatibility
- Verify migration files
- Run migrations manually


**Backup Failures**
- Check storage permissions
- Verify available space
- Check network connectivity for remote backups

### Debug Commands

```bash
# Check database status
bun run db:status

# Check storage health
bun run storage:status

# Test database connection
bun run dev  # Check logs for database initialization

```

## Best Practices

1. **Regular Backups**: Schedule automated backups
2. **Monitoring**: Set up health checks and alerts
3. **Testing**: Test restore procedures regularly
4. **Security**: Use encryption for sensitive data
5. **Performance**: Monitor and optimize slow queries
6. **Documentation**: Keep schema and configuration documented
7. **Version Control**: Track schema changes in version control