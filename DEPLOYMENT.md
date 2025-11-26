# Deployment Guide

Deploy your Blade application with embedded Hive database to Railway, Cloudflare Workers, or Fly.io.

## Quick Start

```bash
# 1. Check setup
bun run setup:check

# 2. Fix any issues
bun run setup:fix

# 3. Deploy
bun run deploy:railway      # or deploy:cloudflare
flyctl deploy              # for Fly.io
```

---

## Railway (Easiest)

### Setup
```bash
npm install -g @railway/cli
railway login
railway init
```

### Deploy
```bash
bun run deploy:railway
```

### Environment Variables
```bash
railway variables set BLADE_AUTH_SECRET=$(openssl rand -base64 30)
railway variables set BLADE_PUBLIC_URL=https://your-app.railway.app
railway variables set RESEND_API_KEY=your-resend-key
```

**Storage**: Automatic persistent volume at `.blade/state`

**Troubleshooting**:
- "Unauthorized" → `railway login`
- Check logs → `railway logs`

---

## Cloudflare Workers (Global Edge)

### ⚠️ Required: AWS S3 Setup

Cloudflare Workers need S3 storage. See [DATABASE.md](./DATABASE.md) for detailed S3 setup.

**Quick S3 Setup**:
1. Create S3 bucket in AWS Console
2. Create IAM user with S3 permissions
3. Generate access keys

### Setup

1. **Authenticate**:
   ```bash
   node_modules/.bin/wrangler login
   ```

2. **Configure `wrangler.jsonc`**:
   ```jsonc
   {
     "name": "your-app",
     "main": ".blade/dist/edge-worker.js",
     "vars": {
       "HIVE_STORAGE_TYPE": "s3",
       "HIVE_S3_BUCKET": "your-bucket-name",
       "AWS_REGION": "us-east-1"
     }
   }
   ```

3. **Set Secrets**:
   ```bash
   node_modules/.bin/wrangler secret put AWS_ACCESS_KEY_ID
   node_modules/.bin/wrangler secret put AWS_SECRET_ACCESS_KEY
   node_modules/.bin/wrangler secret put BLADE_AUTH_SECRET
   node_modules/.bin/wrangler secret put BLADE_PUBLIC_URL
   ```

### Deploy
```bash
bun run deploy:cloudflare
```

**Storage**: AWS S3 (no local disk available)

**Troubleshooting**:
- ⚠️ Always use `node_modules/.bin/wrangler` (not `bun x wrangler`)
- Check logs → `node_modules/.bin/wrangler tail`
- "TypeError: undefined is not a function" → Wrong wrangler path

---

## Fly.io (Docker & Multi-region)

### Setup

1. **Install flyctl**:
   ```bash
   # macOS
   brew install flyctl
   
   # Linux
   curl -L https://fly.io/install.sh | sh
   
   # Windows
   iwr https://fly.io/install.ps1 -useb | iex
   ```

2. **Authenticate**:
   ```bash
   flyctl auth login
   ```

3. **Create Volume** (required):
   ```bash
   flyctl volumes create blade_data --size 1
   ```

4. **Set Secrets**:
   ```bash
   flyctl secrets set BLADE_AUTH_SECRET=$(openssl rand -base64 30)
   flyctl secrets set BLADE_PUBLIC_URL=https://your-app.fly.dev
   flyctl secrets set RESEND_API_KEY=your-resend-key
   ```

### Deploy
```bash
flyctl deploy
```

**Storage**: Volume at `.blade/state` (must create first)

**Troubleshooting**:
- "Volume not found" → `flyctl volumes create blade_data --size 1`
- Check status → `flyctl status`
- View logs → `flyctl logs`

---

## Storage Configuration by Platform

| Platform | Required Storage | Setup Difficulty |
|----------|-----------------|------------------|
| Railway | Disk (automatic) | Easy |
| Cloudflare | S3 (manual) | Medium |
| Fly.io | Disk (manual volume) | Medium |

### Configuration Examples

**Disk (Railway, Fly.io)**:
```bash
HIVE_STORAGE_TYPE=disk
HIVE_DISK_PATH=.blade/state
```

**S3 (Cloudflare, or optional for others)**:
```bash
HIVE_STORAGE_TYPE=s3
HIVE_S3_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

**Replication (Production - Disk + S3)**:
```bash
HIVE_STORAGE_TYPE=replication
HIVE_REPLICATION_MODE=async
HIVE_DISK_PATH=.blade/state
# Plus all S3 variables above
```

---

## Environment Variables

### Required for All Platforms
```bash
BLADE_AUTH_SECRET=xxx        # Generate: openssl rand -base64 30
BLADE_PUBLIC_URL=xxx         # Your deployed URL
RESEND_API_KEY=xxx           # For email verification
```

### Storage Configuration
```bash
NODE_ENV=production
BLADE_PLATFORM=container
HIVE_STORAGE_TYPE=disk       # disk, s3, or replication
HIVE_DISK_PATH=.blade/state  # For disk storage
```

### AWS S3 (Cloudflare or Replication)
```bash
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
AWS_REGION=us-east-1
HIVE_S3_BUCKET=xxx
```

### Optional
```bash
HIVE_ENCRYPTION_KEY=xxx      # Generate: openssl rand -base64 32
```

---

## Docker Deployment

### Using Docker Compose
```bash
bun run docker:build
bun run docker:dev
```

### Manual Docker
```bash
docker build -t myapp .
docker run -d -p 3000:3000 \
  -v blade_data:/usr/src/app/.blade/state \
  -e BLADE_AUTH_SECRET=$BLADE_AUTH_SECRET \
  -e BLADE_PUBLIC_URL=$BLADE_PUBLIC_URL \
  myapp
```

---

## Platform Comparison

| Feature | Railway | Cloudflare | Fly.io |
|---------|---------|------------|--------|
| Setup | ⭐⭐⭐ Easy | ⭐⭐ Medium | ⭐⭐ Medium |
| Storage | Auto volume | S3 required | Manual volume |
| Global | Regional | 150+ locations | Multi-region |
| Scale to Zero | ❌ | ✅ | ✅ |
| Free Tier | $5 credit/mo | 100k req/day | 3 VMs |
| Best For | Quick deploy | Low latency | Docker apps |

---

## Common Commands

```bash
# Setup & Health
bun run setup:check          # Verify configuration
bun run setup:fix            # Fix issues
bun run storage:status       # Check storage health

# Deployment
bun run deploy:railway       # Railway
bun run deploy:cloudflare    # Cloudflare
flyctl deploy               # Fly.io

# Database
bun run db:backup            # Local backup
bun run db:backup:s3         # S3 backup
bun run db:restore           # Restore backup
bun run migrate              # Apply migrations
```

---

## Troubleshooting

### Authentication Issues
```bash
# Re-authenticate
railway login
node_modules/.bin/wrangler login
flyctl auth login
```

### Build Failures
```bash
bun install        # Install dependencies
bun run build      # Test build locally
```

### Storage Issues
```bash
mkdir -p .blade/state           # Create directory
bun run storage:status          # Check configuration
```

### Platform-Specific

**Railway**:
- Install CLI globally: `npm install -g @railway/cli`
- Link project: `railway link`

**Cloudflare**:
- Use `node_modules/.bin/wrangler` (not `bun x wrangler`)
- Ensure S3 is configured
- Check: `.blade/dist/edge-worker.js` exists after build

**Fly.io**:
- Create volume first: `flyctl volumes create blade_data --size 1`
- Volume must be in same region as app

---

## Security Checklist

- [ ] Generate strong auth secret: `openssl rand -base64 30`
- [ ] Never commit `.env` files
- [ ] Use platform secret management
- [ ] Enable HTTPS (automatic on all platforms)
- [ ] Set `HIVE_ENCRYPTION_KEY` for production
- [ ] Use least-privilege IAM for S3
- [ ] Regular backups configured

---

## Production Checklist

- [ ] Environment variables set
- [ ] Storage configured (volume or S3)
- [ ] Backups automated
- [ ] Health checks enabled
- [ ] Monitoring configured
- [ ] Domain configured (optional)
- [ ] Test restore procedure

---

## Next Steps

1. ✅ Choose platform (Railway for easy, Cloudflare for global, Fly.io for Docker)
2. ✅ Configure storage (disk or S3)
3. ✅ Set environment variables
4. ✅ Deploy
5. ✅ Test application
6. ✅ Set up backups
7. ✅ Configure monitoring

**Need Help?** 
- Run `bun run setup:check`
- See [DATABASE.md](./DATABASE.md) for S3 setup
- Check platform logs for errors
