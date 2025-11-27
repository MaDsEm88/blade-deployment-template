# Blade Deployment Template

Production-ready template for deploying Blade applications with embedded Hive (SQLite) database to Railway, Cloudflare Workers, and Fly.io.

## Features

- ✅ **Embedded Hive Database** - SQLite-based storage, no external database needed
- ✅ **Multiple Deployment Targets** - Railway, Cloudflare Workers, Fly.io, Docker
- ✅ **Flexible Storage** - Disk (local), S3 (cloud), or Replication (hybrid)
- ✅ **Automated Backups** - Built-in backup and restore scripts
- ✅ **Production Ready** - Health checks, monitoring, security best practices

## Quick Start

### 1. Clone and Install

```bash
git clone https://github.com/MaDsEm88/blade-deployment-template.git
cd blade-deployment-template
bun install
```

### 2. Run Locally

```bash
bun run dev
# App runs at http://localhost:3000
```

### 3. Deploy

Choose your platform:

```bash
bun run deploy:railway      # Railway.app
bun run deploy:cloudflare   # Cloudflare Workers
flyctl deploy              # Fly.io
```

## Platform Comparison

| Platform | Setup | Storage | Best For |
|----------|-------|---------|----------|
| **Railway** | Easy | ✅ Disk (auto) | Quick deployments |
| **Cloudflare** | Medium | ⚠️ S3 (required) | Global edge, low latency |
| **Fly.io** | Medium | ✅ Disk (manual) | Docker, multi-region |

## Storage Configuration

### Disk Storage (Default)
Best for Railway and Fly.io:
```bash
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state
```

### S3 Storage (Required for Cloudflare)
```bash
HIVE_STORAGE_TYPE=s3
HIVE_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

### Replication (Production)
Combines disk + S3 for speed and durability:
```bash
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async
# Plus disk and S3 variables above
```

## Environment Variables

Required for all platforms:
```bash
BLADE_AUTH_SECRET=$(openssl rand -base64 30)
BLADE_PUBLIC_URL=https://your-app.com
RESEND_API_KEY=your-resend-key  # For emails
```

## Database Management

```bash
bun run storage:status     # Check storage health
bun run db:backup          # Create backup
bun run db:backup:s3       # Backup to S3
bun run db:restore         # Restore from backup
bun run migrate            # Apply migrations
```

## Documentation

### Deployment & Database
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Complete deployment guide for all platforms
- **[DATABASE.md](./DATABASE.md)** - Database configuration and S3 setup
- **[SCRIPTS_USAGE.md](./SCRIPTS_USAGE.md)** - Database scripts reference

### OAuth Authentication
- **[OAUTH_IMPLEMENTATION_COMPARISON.md](./OAUTH_IMPLEMENTATION_COMPARISON.md)** - Compare OAuth approaches and choose the best for your needs
- **[CURRENT_OAUTH_WITH_USERNAME_ROUTES.md](./CURRENT_OAUTH_WITH_USERNAME_ROUTES.md)** - Enhance existing OAuth setup to route users to `/username` pages
- **[CLIENT_SIDE_OAUTH_SILENT_REDIRECT.md](./CLIENT_SIDE_OAUTH_SILENT_REDIRECT.md)** - Client-side OAuth pattern for seamless single-page experience

## Deployment Guides

### Railway (Recommended for Beginners)

1. Install CLI:
   ```bash
   npm install -g @railway/cli
   railway login
   ```

2. Initialize and deploy:
   ```bash
   railway init
   bun run deploy:railway
   ```

3. Set environment variables:
   ```bash
   railway variables set BLADE_AUTH_SECRET=$(openssl rand -base64 30)
   railway variables set BLADE_PUBLIC_URL=https://your-app.railway.app
   ```

**Storage**: Automatic persistent volume at `.blade/state`

### Cloudflare Workers (Best for Global Edge)

**⚠️ Requires AWS S3 setup** - See [DATABASE.md](./DATABASE.md) for S3 configuration.

1. Authenticate:
   ```bash
   node_modules/.bin/wrangler login
   ```

2. Configure S3 in `wrangler.jsonc`:
   ```jsonc
   "vars": {
     "HIVE_STORAGE_TYPE": "s3",
     "HIVE_S3_BUCKET": "your-bucket",
     "AWS_REGION": "us-east-1"
   }
   ```

3. Set secrets:
   ```bash
   node_modules/.bin/wrangler secret put AWS_ACCESS_KEY_ID
   node_modules/.bin/wrangler secret put AWS_SECRET_ACCESS_KEY
   node_modules/.bin/wrangler secret put BLADE_AUTH_SECRET
   ```

4. Deploy:
   ```bash
   bun run deploy:cloudflare
   ```

### Fly.io (Best for Docker Apps)

1. Install and authenticate:
   ```bash
   # macOS: brew install flyctl
   # Linux: curl -L https://fly.io/install.sh | sh
   flyctl auth login
   ```

2. Create volume (required):
   ```bash
   flyctl volumes create blade_data --size 1
   ```

3. Set secrets:
   ```bash
   flyctl secrets set BLADE_AUTH_SECRET=$(openssl rand -base64 30)
   flyctl secrets set BLADE_PUBLIC_URL=https://your-app.fly.dev
   ```

4. Deploy:
   ```bash
   flyctl deploy
   ```

**Storage**: Volume mounted at `.blade/state`

## Project Structure

```
blade-deployment-template/
├── .blade/
│   └── state/              # Hive database storage
├── scripts/
│   ├── backup-db.sh        # Local backup script
│   ├── backup-to-s3.sh     # S3 backup script
│   ├── restore-db.sh       # Restore script
│   ├── check-storage-status.js  # Storage health check
│   └── sync-remote-storage.js   # S3/remote sync
├── schema/
│   └── index.ts            # Database schema
├── wrangler.jsonc          # Cloudflare config
├── railway.json            # Railway config
├── fly.toml                # Fly.io config
├── docker-compose.yml      # Docker config
├── Dockerfile              # Docker build
└── package.json            # Scripts and dependencies
```

## Available Scripts

### Development
```bash
bun run dev                # Start development server
bun run build              # Build for production
```

### Deployment
```bash
bun run deploy:railway     # Deploy to Railway
bun run deploy:cloudflare  # Deploy to Cloudflare
flyctl deploy             # Deploy to Fly.io
```

### Database
```bash
bun run storage:status     # Check storage configuration
bun run db:backup          # Create local backup
bun run db:backup:s3       # Upload to S3
bun run db:restore         # Restore from backup
bun run db:sync:status     # Check S3 sync status
bun run db:sync:upload     # Upload to S3
bun run db:sync:download   # Download from S3
bun run migrate            # Apply migrations
bun run migrate:check      # Check pending migrations
```

### Setup
```bash
bun run setup:check        # Verify deployment setup
bun run setup:fix          # Fix deployment issues
```

## Troubleshooting

### Check Storage Status
```bash
bun run storage:status
```

### Common Issues

**"Unauthorized" errors**:
```bash
railway login
node_modules/.bin/wrangler login
flyctl auth login
```

**Database not found**:
```bash
mkdir -p .blade/state
bun run dev  # Initialize database
```

**S3 connection failed**:
```bash
aws configure  # Set AWS credentials
aws s3 ls s3://your-bucket/  # Test connection
```

**Cloudflare deployment fails**:
- Always use `node_modules/.bin/wrangler`, never `bun x wrangler`
- Ensure S3 is configured (required for Cloudflare)

## Security Best Practices

1. **Generate strong secrets**:
   ```bash
   openssl rand -base64 30
   ```

2. **Never commit secrets** - Use platform secret management

3. **Enable encryption** for production:
   ```bash
   export HIVE_ENCRYPTION_KEY=$(openssl rand -base64 32)
   ```

4. **Use HTTPS** - All platforms enforce automatically

5. **Regular backups** - Automate with cron or CI/CD

## Production Checklist

Before deploying to production:

- [ ] Set `BLADE_AUTH_SECRET` (30+ characters)
- [ ] Configure `BLADE_PUBLIC_URL` with your domain
- [ ] Set up email service (`RESEND_API_KEY`)
- [ ] Choose storage type (disk/s3/replication)
- [ ] Configure S3 if using Cloudflare or replication
- [ ] Enable encryption (`HIVE_ENCRYPTION_KEY`)
- [ ] Test backup and restore procedures
- [ ] Set up automated backups
- [ ] Configure health checks
- [ ] Review security settings

## Migration Guide

### Moving from Disk to S3

```bash
# 1. Backup current database
bun run db:backup

# 2. Set up S3 (see DATABASE.md)

# 3. Upload to S3
bun run db:sync:upload

# 4. Update environment variables
export HIVE_STORAGE_TYPE=s3
export HIVE_S3_BUCKET=your-bucket

# 5. Deploy
```

### Upgrading to Replication

```bash
# 1. Keep existing S3 configuration
# 2. Add replication settings
export HIVE_STORAGE_TYPE=replication
export HIVE_REPLICATION_MODE=async

# 3. Deploy - initial sync happens automatically
```

## Cost Estimates

### Railway
- Free tier: $5/month credit
- Typical app: ~$10-20/month

### Cloudflare Workers
- Free tier: 100k requests/day
- S3 costs: ~$0.03-0.05/month (1GB + 10k requests)

### Fly.io
- Free tier: 3 shared-cpu VMs
- Volume: ~$0.15/GB/month

## Support

- **Issues**: [GitHub Issues](https://github.com/MaDsEm88/blade-deployment-template/issues)
- **Discussions**: [GitHub Discussions](https://github.com/MaDsEm88/blade-deployment-template/discussions)
- **Documentation**: See [DEPLOYMENT.md](./DEPLOYMENT.md) and [DATABASE.md](./DATABASE.md)

## Contributing

Contributions welcome! Please read our contributing guidelines first.

## License

MIT License - see LICENSE file for details

---

**Quick Links**:
- [Deployment Guide](./DEPLOYMENT.md)
- [Database Configuration](./DATABASE.md)