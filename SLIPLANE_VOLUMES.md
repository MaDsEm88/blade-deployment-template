# Sliplane Volume Management for Embedded Hive Database

This guide explains how to host your embedded Hive database on Sliplane.io using persistent volumes, ensuring data persists across deployments and container restarts.

## Overview

Your Blade application uses an **embedded Hive (SQLite) database** that stores data locally in the `.blade/state` directory. When deploying to Sliplane, you need to configure **persistent volumes** to ensure this data isn't lost when containers are restarted or redeployed.

**Key Concept**: Sliplane uses **disk storage with persistent volumes** - your database stays on disk, but Sliplane's volume system ensures it persists across container lifecycles and provides automatic backups.

---

## Why Use Sliplane Volumes?

### Without Volumes (❌ Don't Do This)
- Database stored in container's ephemeral filesystem
- Data **lost on every deploy or restart**
- No backup capabilities
- Not suitable for production

### With Volumes (✅ Recommended)
- Database stored in persistent Docker volume
- Data **survives deploys and restarts**
- Automatic daily backups by Sliplane
- Can scale volume size as data grows
- Share volumes between multiple services if needed

---

## Quick Start

### 1. Create a Volume

Via Sliplane Dashboard:
1. Go to **Server Settings** > **Volumes** tab
2. Click **"Add Volume"**
3. Enter volume name: `blade-data` (or your preferred name)
4. Recommended initial size: **1GB** (can be increased later)
5. Click **Create**

### 2. Deploy Your Service

When deploying your Docker image to Sliplane:

1. **Build and push your Docker image**:
   ```bash
   # Build the image
   docker build -t your-registry/your-app:latest .
   
   # Push to your registry (Docker Hub, GitHub Container Registry, etc.)
   docker push your-registry/your-app:latest
   ```

2. **Create service in Sliplane Dashboard**:
   - Click **"Deploy a Service"**
   - Select your Docker image
   - Configure settings

3. **Set environment variables**:
   ```bash
   NODE_ENV=production
   BLADE_PLATFORM=container
   HIVE_STORAGE_TYPE=disk
   HIVE_DISK_PATH=.blade/state
   BLADE_AUTH_SECRET=<generate-with-openssl-rand-base64-30>
   BLADE_PUBLIC_URL=https://your-domain.example.com
   ```

4. **Attach the volume**:
   - In Service Settings > **Volumes** tab
   - Click **"Attach a Volume"**
   - Select: `blade-data` (the volume you created)
   - Mount path: `/usr/src/app/.blade/state`
   - Click **Attach**

5. **Deploy** the service

---

## Configuration Reference

### Volume Configuration

| Setting | Value | Required |
|---------|-------|----------|
| Volume Name | `blade-data` (or custom) | ✅ Yes |
| Mount Path | `/usr/src/app/.blade/state` | ✅ Yes (exact path) |
| Initial Size | 1GB minimum | ✅ Yes |
| Backup | Automatic daily | ✅ Enabled by default |

### Environment Variables

```bash
# Required for disk storage
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state

# Application configuration
NODE_ENV=production
BLADE_PLATFORM=container
BLADE_AUTH_SECRET=<your-secret>
BLADE_PUBLIC_URL=<your-url>

# Optional: Enable encryption
HIVE_ENCRYPTION_KEY=<generate-with-openssl>
```

---

## Scaling Your Database

### Monitor Storage Usage

Check your database size:
```bash
# Via Sliplane Dashboard: Server Settings > Volumes > blade-data
# Shows current usage and capacity
```

### Increase Volume Size

When your application grows:

1. Go to **Server Settings** > **Volumes** tab
2. Select your `blade-data` volume
3. Click the **three-dot menu** (top right)
4. Select **Edit**
5. Increase size (e.g., 1GB → 5GB → 10GB)
6. Save changes

**Note**: Volume size can be **increased but not decreased**. Plan accordingly.

### Size Guidelines

| Application Size | Recommended Volume | Database Rows |
|------------------|-------------------|---------------|
| Small (testing) | 1GB | < 100k rows |
| Medium (startup) | 5GB | 100k - 1M rows |
| Large (growth) | 10GB - 50GB | 1M - 10M rows |
| Enterprise | 50GB+ | 10M+ rows |

---

## Advanced: When to Move Beyond Disk Storage

As your application scales, you may need more advanced storage solutions:

### Option 1: Stay on Sliplane Volumes (Recommended for most)
**Good for**: Most applications, up to millions of records
- ✅ Fast (< 1ms latency)
- ✅ Simple configuration
- ✅ Automatic backups
- ✅ Cost-effective
- ❌ Limited to single server
- ❌ Manual volume scaling

**When to use**: Your app is on a single server and you don't need multi-region distribution.

### Option 2: AWS S3 Storage
**Good for**: Multi-region or serverless deployments (like Cloudflare Workers)
- ✅ Global availability
- ✅ Unlimited scalability
- ✅ Pay-per-use pricing
- ❌ Slower (100-300ms latency)
- ❌ More complex setup
- ❌ Additional AWS costs

**When to use**: You need global distribution or are deploying to edge/serverless platforms.

**Configuration**:
```bash
HIVE_STORAGE_TYPE=s3
HIVE_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

See [DATABASE.md](./DATABASE.md) for full S3 setup instructions.

### Option 3: Replication (Disk + S3)
**Good for**: Production apps needing both speed and durability
- ✅ Fast reads/writes (disk)
- ✅ Durable backups (S3)
- ✅ Automatic sync
- ❌ More complex configuration
- ❌ Higher costs

**When to use**: Production apps with high reliability requirements.

**Configuration**:
```bash
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async
HIVE_DISK_PATH=.blade/state
# Plus all S3 variables above
```

---

## Backup & Restore

### Automatic Backups (Sliplane)

Sliplane automatically backs up your volumes daily:

1. Go to **Server Settings** > **Volumes** > `blade-data`
2. View backup history
3. Restore any backup:
   - Click **Restore** button next to backup
   - New volume created with backup data
   - Manually detach old volume and attach new one

**Important**: Verify backups can be restored regularly!

### Manual Backups

Create a backup manually:
1. Go to volume details
2. Click **three-dot menu** (top right)
3. Select **"Create Backup"**
4. Backup created (limited to one per 30 minutes)

### Local Backup Scripts

Use built-in scripts for additional backups:
```bash
# Local backup
bun run db:backup

# Backup to S3 (if configured)
bun run db:backup:s3
```

### Restore from Backup

Via Sliplane Dashboard:
1. Navigate to volume backups
2. Select backup to restore
3. Click **Restore**
4. Wait for new volume creation
5. Detach old volume from service
6. Attach restored volume to service
7. Redeploy service

---

## Sharing Volumes Between Services

Multiple services can share the same volume if needed:

**Example Use Case**: Separate read/write services accessing the same database

1. Create volume once
2. Attach to **primary service** (read/write)
3. Attach to **secondary service** (read-only recommended)
4. Set mount path: `/usr/src/app/.blade/state` for both

**Caution**: 
- ⚠️ Only one service should write to avoid conflicts
- Consider read-only mounts for secondary services
- Use replication for true multi-service writes

---

## Troubleshooting

### Database Not Persisting After Restart

**Symptoms**: Data disappears after container restart

**Solution**:
1. Check volume is attached:
   - Service Settings > Volumes tab
   - Should show `blade-data` attached
2. Verify mount path is exactly: `/usr/src/app/.blade/state`
3. Check environment variable: `HIVE_DISK_PATH=.blade/state`
4. Restart service after fixing

### Mount Path Mismatch Error

**Symptoms**: Container fails to start, mount errors in logs

**Solution**:
1. Ensure mount path is: `/usr/src/app/.blade/state` (not `.blade/state`)
2. Volume must be attached before deployment
3. Path is case-sensitive and must be exact

### Volume Not Found

**Symptoms**: Deployment fails with volume errors

**Solution**:
1. Create volume first in Server Settings > Volumes
2. Volume must be on the same server as service
3. Cannot reference volumes from different servers

### Database Files Corrupted

**Symptoms**: App crashes with SQLite errors

**Solution**:
1. Stop the service
2. Restore from latest Sliplane backup
3. Or restore from manual backup:
   ```bash
   bun run db:restore
   ```
4. Consider enabling encryption to prevent corruption

### Running Out of Space

**Symptoms**: Write operations fail, disk full errors

**Solution**:
1. Check volume usage in dashboard
2. Increase volume size (see "Scaling Your Database")
3. Consider:
   - Archive old data
   - Move to larger volume
   - Switch to S3 for unlimited storage

### Backup Restore Takes Too Long

**Expected**: Large databases may take minutes to hours to restore

**Tips**:
- Test restore procedure with smaller datasets first
- Schedule maintenance windows for restores
- Consider incremental backups for very large databases
- Monitor restore progress in dashboard

---

## Best Practices

### Security
- ✅ Set `HIVE_ENCRYPTION_KEY` for production databases
- ✅ Use Sliplane's secure environment variables for secrets
- ✅ Never commit `.env` files or secrets to git
- ✅ Rotate encryption keys annually
- ✅ Restrict volume access to necessary services only

### Performance
- ✅ Start with 1GB volume, scale as needed
- ✅ Use disk storage for single-region deployments (fastest)
- ✅ Add database indexes for frequently queried fields
- ✅ Monitor query performance (<100ms typical)
- ✅ Use pagination for large result sets

### Reliability
- ✅ Test backup restore procedure monthly
- ✅ Keep: 7 daily backups (automatic on Sliplane)
- ✅ Create manual backups before major changes
- ✅ Use replication for mission-critical production apps
- ✅ Monitor disk space usage (alert at 80% full)

### Monitoring
- ✅ Set up health checks in Sliplane
- ✅ Monitor service logs for database errors
- ✅ Track storage growth over time
- ✅ Alert on backup failures
- ✅ Review volume metrics weekly

---

## Migration Guides

### Migrating FROM Another Platform TO Sliplane

#### From Railway/Fly.io (Disk)
```bash
# 1. Export data from old platform
bun run db:backup  # Creates local backup

# 2. Download backup to local machine
railway run bun run db:backup  # Or: fly ssh console

# 3. Create volume on Sliplane
# Via dashboard: Server Settings > Volumes > Add Volume

# 4. Deploy to Sliplane with volume attached
# Follow "Quick Start" section above

# 5. Upload data to Sliplane service
# Via Sliplane SSH or file upload feature

# 6. Restore backup
bun run db:restore
```

#### From Cloudflare Workers (S3)
```bash
# 1. Sync S3 data to local disk
aws s3 sync s3://your-bucket/.blade/state/ .blade/state/

# 2. Create backup
bun run db:backup

# 3. Deploy to Sliplane (follow Quick Start)

# 4. Upload and restore backup
# Or keep S3 storage and use HIVE_STORAGE_TYPE=s3
```

### Migrating FROM Sliplane TO S3 (Scaling Up)

When your app grows and needs multi-region support:

```bash
# 1. Set up AWS S3 bucket (see DATABASE.md)

# 2. Export current data
bun run db:backup

# 3. Upload to S3
aws s3 sync .blade/state/ s3://your-bucket/.blade/state/

# 4. Update environment variables
HIVE_STORAGE_TYPE=s3
HIVE_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1

# 5. Redeploy service
# Can now detach Sliplane volume if desired
```

### Switching to Replication (Best of Both)

Keep Sliplane volume for speed + S3 for durability:

```bash
# 1. Keep existing Sliplane volume attached

# 2. Set up AWS S3 (see DATABASE.md)

# 3. Initial S3 sync
aws s3 sync .blade/state/ s3://your-bucket/.blade/state/

# 4. Update environment (keep volume attached)
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async
HIVE_DISK_PATH=.blade/state
# Plus S3 credentials

# 5. Redeploy - will sync automatically
```

---

## Cost Estimation

### Sliplane Volume Costs
- Included in server pricing
- No additional per-GB charges for volumes
- Backups included

### Comparison with S3
| Storage Type | 10GB Data | 100k Requests/Month | Total |
|--------------|-----------|---------------------|-------|
| Sliplane Volume | Included | Included | ~$0/month extra |
| AWS S3 | ~$0.23 | ~$0.05 | ~$0.28/month |

**Winner**: Sliplane volumes are more cost-effective for single-region deployments.

---

## Quick Reference

### Essential Commands
```bash
# Check storage status
bun run storage:status

# Create backup
bun run db:backup

# Restore backup
bun run db:restore

# Check logs (via Sliplane Dashboard)
# Service > Logs tab
```

### Important Paths
- **Container mount path**: `/usr/src/app/.blade/state`
- **App-relative path**: `.blade/state`
- **Environment variable**: `HIVE_DISK_PATH=.blade/state`

### Configuration Checklist
- [ ] Volume created in Server Settings > Volumes
- [ ] Volume size ≥ 1GB (scale as needed)
- [ ] Volume attached to service
- [ ] Mount path: `/usr/src/app/.blade/state` (exact)
- [ ] `HIVE_STORAGE_TYPE=disk`
- [ ] `HIVE_DISK_PATH=.blade/state`
- [ ] `BLADE_PLATFORM=container`
- [ ] Secrets configured (AUTH_SECRET, etc.)
- [ ] Test backup restore procedure
- [ ] Health checks enabled

---

## Next Steps

1. ✅ **Create Volume**: Server Settings > Volumes > Add Volume (`blade-data`)
2. ✅ **Deploy Service**: Follow "Quick Start" section
3. ✅ **Verify Persistence**: Create test data, restart service, verify data still exists
4. ✅ **Test Backup Restore**: Restore from automatic backup to verify it works
5. ✅ **Monitor**: Set up alerts for storage usage
6. ✅ **Scale**: Increase volume size as data grows

**When to Consider S3**:
- Need multi-region distribution
- Database > 50GB
- Deploying to serverless/edge platforms
- Need unlimited storage scaling

**When to Stay on Sliplane Volumes**:
- Single-region deployment
- Database < 50GB
- Want simplest setup
- Need best performance (<1ms)

---

## Resources

- [Sliplane Volumes Documentation](https://docs.sliplane.io/volumes)
- [DATABASE.md](./DATABASE.md) - Storage configuration guide
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Platform deployment guides
- [Docker Volumes Documentation](https://docs.docker.com/storage/volumes/)

---

## Support

**Issues?**
1. Run `bun run setup:check` for configuration validation
2. Check Sliplane service logs
3. Review this guide's troubleshooting section
4. Verify volume is attached in dashboard

**Questions?**
- Sliplane Support: https://sliplane.io/support
- Blade Framework: https://blade.dev
