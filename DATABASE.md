# Database Guide

Complete guide for the embedded Hive database in your Blade application.

## Overview

Your application uses an **embedded Hive database** built into the Blade framework:
- Stores data using SQLite in `.blade/state/` directory
- Supports multiple storage backends (disk, S3, replication)
- No external database server required
- Automatic migrations and backups

---

## Storage Types & When to Use Them

| Type | Best For | Speed | Durability | Setup |
|------|----------|-------|------------|-------|
| **disk** | Railway/Fly.io single-region | ⚡ <1ms | ✅ Good | Easy |
| **s3** | Cloudflare Workers (required) | 🐌 100-300ms | 💪 Excellent | Medium |
| **replication** | Production apps | ⚡ <1ms | 💪 Excellent | Medium |

**Quick Decision**:
- Railway/Fly.io? → Use `disk` (default)
- Cloudflare Workers? → Must use `s3`
- Production app? → Use `replication` (disk + S3)

---

## Configuration

### Disk Storage (Default)
```bash
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state
```

**Platform Setup**:
- Railway: Automatic (volume created)
- Fly.io: Manual - `flyctl volumes create blade_data --size 1`
- Docker: Configured in docker-compose.yml

### S3 Storage (Required for Cloudflare)

#### Quick Setup
```bash
HIVE_STORAGE_TYPE=s3
HIVE_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

#### AWS S3 Setup Steps

**1. Create S3 Bucket**
- Go to AWS Console → S3 → Create bucket
- Name: `your-app-database` (globally unique)
- Region: `us-east-1` (or closest to users)
- Block all public access: ✅ Enabled

**2. Create IAM Policy**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::your-app-database",
      "arn:aws:s3:::your-app-database/*"
    ]
  }]
}
```

**3. Create IAM User**
- Attach the policy above
- Generate access key → Save Access Key ID & Secret

**4. Set Secrets by Platform**

Railway:
```bash
railway variables set HIVE_STORAGE_TYPE=s3
railway variables set HIVE_S3_BUCKET=your-app-database
railway variables set AWS_ACCESS_KEY_ID=AKIA...
railway variables set AWS_SECRET_ACCESS_KEY=...
railway variables set AWS_REGION=us-east-1
```

Fly.io:
```bash
flyctl secrets set HIVE_STORAGE_TYPE=s3 HIVE_S3_BUCKET=your-app-database
flyctl secrets set AWS_ACCESS_KEY_ID=AKIA... AWS_SECRET_ACCESS_KEY=...
flyctl secrets set AWS_REGION=us-east-1
```

Cloudflare (add to wrangler.jsonc vars, then):
```bash
node_modules/.bin/wrangler secret put AWS_ACCESS_KEY_ID
node_modules/.bin/wrangler secret put AWS_SECRET_ACCESS_KEY
```

**Cost**: ~$0.03-0.05/month for 1GB + 10k requests

### Replication Storage (Production)

Combines disk (fast) + S3 (durable):

```bash
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async              # async or sync
HIVE_CONFLICT_RESOLUTION=latest          # latest, primary, or replica
HIVE_DISK_PATH=.blade/state
# Plus all S3 variables above
```

**Modes**:
- `async`: Fast, writes to disk first (recommended)
- `sync`: Slower, waits for both disk and S3

---

## Common Operations

### Check Status
```bash
bun run storage:status  # Storage health
bun run db:status       # Database status
```

### Backups
```bash
bun run db:backup       # Quick local backup
bun run db:backup:s3    # Backup to S3

# Manual backup
tar -czf backup-$(date +%Y%m%d).tar.gz .blade/state
```

### Restore
```bash
bun run db:restore      # Interactive restore

# Manual restore (stop app first)
rm -rf .blade/state
tar -xzf backup-20240101.tar.gz
```

### Migrations
```bash
blade diff              # Check schema changes
blade apply             # Apply migrations
```

### S3 Sync (Replication)
```bash
bun run db:sync:status   # Check sync status
bun run db:sync:upload   # Force upload to S3
```

---

## Security

### Encryption
```bash
# Generate key
openssl rand -base64 32

# Set by platform
railway variables set HIVE_ENCRYPTION_KEY=...
flyctl secrets set HIVE_ENCRYPTION_KEY=...
node_modules/.bin/wrangler secret put HIVE_ENCRYPTION_KEY
```

⚠️ **Important**: Store encryption key securely - losing it means losing your data!

### S3 Security Checklist
- ✅ Use least-privilege IAM policy
- ✅ Enable S3 bucket encryption at rest
- ✅ Enable bucket versioning (backup)
- ✅ Keep access keys secure
- ✅ Never commit secrets to git

---

## Troubleshooting

### Database Connection Failed
```bash
# Check config
echo $HIVE_STORAGE_TYPE
echo $HIVE_DISK_PATH

# Verify directory (disk)
ls -la .blade/state/

# Check status
bun run storage:status
```

### S3 Issues
```bash
# Test AWS credentials
aws sts get-caller-identity

# Test bucket access
aws s3 ls s3://your-bucket/

# Check environment
echo $AWS_ACCESS_KEY_ID
echo $HIVE_S3_BUCKET
```

### Replication Lag
```bash
# Check sync status
bun run db:sync:status

# Force sync
bun run db:sync:upload

# Check logs
grep -i replication logs/app.log
```

---

## Best Practices

**Backups**:
- Automate daily backups (use cron or platform scheduler)
- Test restore procedures monthly
- Keep: 7 daily, 4 weekly, 12 monthly backups

**Security**:
- Always use encryption for production
- Rotate keys annually
- Use separate IAM users for different environments

**Monitoring**:
- Set up health check alerts
- Monitor query performance (<100ms disk, <500ms S3)
- Track storage growth
- Alert on backup failures

**Performance**:
- Use `disk` for single-region apps
- Use `replication` for production (best of both)
- Add indexes for frequent queries
- Use pagination for large datasets

---

## Migration Examples

### Disk → S3
```bash
# 1. Backup current data
bun run db:backup

# 2. Upload to S3
aws s3 sync .blade/state/ s3://your-bucket/.blade/state/

# 3. Update environment (see S3 config above)
# 4. Deploy
```

### Disk → Replication
```bash
# 1. Set up S3 (see S3 setup)
# 2. Upload initial data
aws s3 sync .blade/state/ s3://your-bucket/.blade/state/

# 3. Update environment variables (keep S3 vars, change type)
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async

# 4. Deploy - will sync automatically
```

---

## Quick Reference

```bash
# Status
bun run storage:status
bun run db:status

# Backups
bun run db:backup
bun run db:backup:s3
bun run db:restore

# Migrations
blade diff
blade apply

# Sync (replication)
bun run db:sync:status
bun run db:sync:upload

# Logs by platform
railway logs
flyctl logs
node_modules/.bin/wrangler tail
docker logs <container>
```

---

## Resources

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Platform deployment guides
- [AWS S3 Docs](https://docs.aws.amazon.com/s3/)
- [AWS Cost Calculator](https://calculator.aws/)

---

**Storage Decision Tree**:
1. Deploying to Cloudflare? → Use **S3** (required)
2. Production app? → Use **replication** (best)
3. Development/simple app? → Use **disk** (default)

**Last Updated**: January 2025
