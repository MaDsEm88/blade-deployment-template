# Sliplane Deployment Guide

Deploy your Blade application with embedded Hive database to Sliplane with persistent volume storage and optional Cloudflare integration.

## Quick Start

```bash
# 1. Check setup
bun run setup:check

# 2. Fix any issues
bun run setup:fix

# 3. Deploy to Sliplane
bun run deploy:sliplane
```

---

## Sliplane Setup

### Prerequisites

1. **Sliplane Account**: Sign up at https://sliplane.io
2. **CLI Installation**:
   ```bash
   # macOS/Linux using Homebrew
   brew install sliplane-cli

   # Or download from
   https://sliplane.io/docs/getting-started/installation
   ```

3. **Authentication**:
   ```bash
   sliplane auth login
   ```

### Initial Configuration

1. **Create Project** (if first time):
   ```bash
   sliplane project create --name my-project
   sliplane project set-default my-project
   ```

2. **Create Sliplane App**:
   ```bash
   sliplane app create --name blade-hive-app
   ```

---

## Storage Configuration

### Persistent Volumes

Sliplane uses **volumes** for persistent database storage. The `sliplane.yml` configuration includes:

```yaml
volumes:
  - name: blade-data
    mount_path: /usr/src/app/.blade/state
    size: 5Gi
    type: persistent
```

**Key Points**:
- Volume name: `blade-data` (persists across deployments)
- Mount path: `.blade/state` (where Hive stores SQLite database)
- Size: 5Gi (adjust based on your data needs)
- Type: `persistent` (data survives pod restarts)

### Storage Type Configuration

The application uses **disk storage** with Sliplane volumes:

```bash
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state
```

This is the default and recommended setup for Sliplane.

---

## Environment Variables Setup

### Required Variables

Set these in your Sliplane app:

```bash
sliplane app set-env --name blade-hive-app \
  BLADE_AUTH_SECRET=$(openssl rand -base64 30) \
  BLADE_PUBLIC_URL=https://your-domain.com \
  RESEND_API_KEY=your-resend-key
```

Or set individually:

```bash
sliplane app set-env BLADE_AUTH_SECRET your-secret --name blade-hive-app
sliplane app set-env BLADE_PUBLIC_URL https://your-domain.com --name blade-hive-app
sliplane app set-env RESEND_API_KEY your-resend-key --name blade-hive-app
```

### Storage Variables (Already configured)

```bash
NODE_ENV=production
BLADE_PLATFORM=container
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state
```

### Optional: Encryption

For production, enable encryption:

```bash
HIVE_ENCRYPTION_KEY=$(openssl rand -base64 32)
sliplane app set-env HIVE_ENCRYPTION_KEY $HIVE_ENCRYPTION_KEY --name blade-hive-app
```

---

## Deployment

### Method 1: Using `sliplane.yml` (Recommended)

```bash
# Deploy using configuration file
bun run deploy:sliplane

# Or manually
sliplane deploy --config sliplane.yml
```

### Method 2: Direct CLI

```bash
# Build and push Docker image
docker build -t blade-hive-app .
docker tag blade-hive-app your-registry/blade-hive-app:latest
docker push your-registry/blade-hive-app:latest

# Deploy
sliplane app deploy --image your-registry/blade-hive-app:latest
```

### Monitoring Deployment

```bash
# Check deployment status
sliplane app status --name blade-hive-app

# View logs
sliplane app logs --name blade-hive-app

# Watch in real-time
sliplane app logs --follow --name blade-hive-app
```

---

## Cloudflare Integration

### Setup Custom Domain with Cloudflare

1. **Add Domain in Sliplane**:
   ```bash
   sliplane domain add --name your-domain.com
   ```

2. **Get Nameservers from Sliplane**:
   ```bash
   sliplane domain show your-domain.com
   ```
   This will display the nameservers you need to configure.

3. **Configure in Cloudflare**:
   - Go to Cloudflare Dashboard
   - Add site > your-domain.com
   - Change nameservers to Sliplane's nameservers
   - Point to your Sliplane app endpoint

### Point Sliplane App to Cloudflare Domain

```bash
# Link domain to app
sliplane app domain-add --app blade-hive-app --domain your-domain.com

# Verify setup
sliplane app domain-list --app blade-hive-app
```

### Alternative: Cloudflare DNS Only (CNAME)

If using Cloudflare DNS only (not nameservers):

1. In Cloudflare:
   - Add CNAME record: `your-domain.com` → `your-app.sliplane.app`
   - Set SSL/TLS to "Full" or "Full (Strict)"

2. In Sliplane:
   ```bash
   sliplane app custom-domain --app blade-hive-app \
     --domain your-domain.com \
     --target your-app.sliplane.app
   ```

### HTTPS Configuration

Sliplane automatically provides HTTPS certificates:

```bash
# Verify SSL status
sliplane app ssl-status --app blade-hive-app

# Check certificate
sliplane app ssl-info --app blade-hive-app
```

---

## Backup & Restore

### Manual Backup (Before deployment)

```bash
# Backup local database to file
bun run db:backup

# Backup to Sliplane (via your app)
sliplane app backup create --app blade-hive-app --name pre-deployment
```

### Restore from Backup

```bash
# List available backups
sliplane app backup list --app blade-hive-app

# Restore from backup
sliplane app backup restore --app blade-hive-app --backup-id <id>
```

### Volume Snapshots

```bash
# Create volume snapshot
sliplane volume snapshot create --volume blade-data

# List snapshots
sliplane volume snapshot list --volume blade-data

# Restore from snapshot
sliplane volume snapshot restore --volume blade-data --snapshot-id <id>
```

---

## Scaling

### Horizontal Scaling

Sliplane automatically scales based on CPU/memory usage:

```yaml
scaling:
  min_instances: 1
  max_instances: 3
  target_cpu_utilization: 70
  target_memory_utilization: 80
```

To modify:

```bash
sliplane app scale --app blade-hive-app \
  --min 1 --max 5 \
  --target-cpu 70 --target-memory 80
```

### Vertical Scaling

Adjust resources:

```bash
sliplane app resources --app blade-hive-app \
  --cpu 2 --memory 1Gi
```

---

## Troubleshooting

### Application won't start

```bash
# Check logs
sliplane app logs --app blade-hive-app --tail 100

# Check status
sliplane app status --app blade-hive-app

# Restart app
sliplane app restart --app blade-hive-app
```

### Database persistence issues

```bash
# Check volume status
sliplane volume status --volume blade-data

# Verify mount
sliplane app exec --app blade-hive-app -- ls -la .blade/state/

# Check disk space
sliplane app exec --app blade-hive-app -- df -h
```

### Domain/SSL issues

```bash
# Check domain configuration
sliplane domain show your-domain.com

# Verify app routes
sliplane app routes --app blade-hive-app

# Renew SSL certificate (if needed)
sliplane app ssl-renew --app blade-hive-app
```

### Environment variable issues

```bash
# List all variables
sliplane app env list --app blade-hive-app

# Check specific variable
sliplane app env get --app blade-hive-app --key BLADE_AUTH_SECRET

# Update variable
sliplane app set-env VARIABLE_NAME new-value --app blade-hive-app
```

---

## Health Checks

The application includes HTTP health checks:

```yaml
health_checks:
  - type: http
    path: /
    port: 3000
    interval: 30s
    timeout: 5s
    initial_delay: 10s
```

View health status:

```bash
sliplane app health --app blade-hive-app
```

---

## Monitoring & Metrics

### Enable Metrics Collection

Metrics are enabled in `sliplane.yml`:

```yaml
monitoring:
  enabled: true
  collect_metrics: true
  expose_metrics: true
```

### View Metrics

```bash
# CPU usage
sliplane app metrics --app blade-hive-app --metric cpu

# Memory usage
sliplane app metrics --app blade-hive-app --metric memory

# Request count
sliplane app metrics --app blade-hive-app --metric requests

# Response time
sliplane app metrics --app blade-hive-app --metric latency
```

---

## Production Checklist

- [ ] Generate strong auth secret: `openssl rand -base64 30`
- [ ] Set `BLADE_PUBLIC_URL` to your domain
- [ ] Configure `RESEND_API_KEY` for email
- [ ] Enable `HIVE_ENCRYPTION_KEY`
- [ ] Set up persistent volume (already configured in sliplane.yml)
- [ ] Configure custom domain and HTTPS
- [ ] Enable automatic backups
- [ ] Set up monitoring and alerts
- [ ] Test health checks
- [ ] Configure auto-scaling if needed
- [ ] Test database persistence (redeploy and verify data)
- [ ] Set up regular backups

---

## Performance Tips

1. **Resource Allocation**: Start with 1CPU/512Mi, scale up based on metrics
2. **Volume Size**: Monitor database growth, pre-allocate space
3. **Connection Pooling**: The app handles this automatically via Hive
4. **Caching**: Enable for static assets via Sliplane CDN
5. **Monitoring**: Set up alerts for high CPU/memory usage

---

## Comparison with Other Platforms

| Feature | Sliplane | Railway | Fly.io | Cloudflare |
|---------|----------|---------|--------|------------|
| Setup | ⭐⭐ Medium | ⭐⭐⭐ Easy | ⭐⭐ Medium | ⭐ Hard |
| Storage | Disk (volumes) | Disk (auto) | Disk (manual) | S3 (required) |
| Scaling | ✅ Auto | ⚠️ Limited | ✅ Good | N/A |
| Cloudflare | ✅ Integrated | ⚠️ DNS only | ⚠️ DNS only | ✅ Native |
| Global | Multi-region | Regional | Multi-region | 150+ locations |
| Price | Competitive | Affordable | Free tier | Serverless pay-as-you-go |

---

## Useful Links

- **Sliplane Docs**: https://docs.sliplane.io
- **Create Server**: https://docs.sliplane.io/servers/create-a-server
- **Volumes**: https://docs.sliplane.io/servers/volumes
- **Metrics**: https://docs.sliplane.io/servers/metrics
- **Custom Domains**: https://docs.sliplane.io/services/custom-domains
- **Cloudflare Integration**: https://docs.sliplane.io/guides/cloudflare
- **Blade Framework**: https://blade.js.org
- **Hive Database**: https://hive.dev

---

## Support

For issues:
1. Check logs: `sliplane app logs --app blade-hive-app --tail 100`
2. Run status check: `bun run setup:check`
3. See [DEPLOYMENT.md](./DEPLOYMENT.md) for general troubleshooting
4. Visit [Sliplane Docs](https://docs.sliplane.io) for platform-specific help
