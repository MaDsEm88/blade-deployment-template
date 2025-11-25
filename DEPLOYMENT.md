# Deployment Guide

Complete guide for deploying your Blade application with embedded Hive database to Railway, Cloudflare Workers, and Fly.io.

## Quick Start

### 1. Check Setup
```bash
bun run setup:check
```
This verifies CLI tools are installed and authenticated.

### 2. Fix Issues (if needed)
```bash
bun run setup:fix
```
Interactive wizard to install and authenticate CLI tools.

### 3. Deploy
```bash
# Choose your platform:
bun run deploy:railway      # Railway.app
bun run deploy:cloudflare   # Cloudflare Workers
flyctl deploy              # Fly.io
```

---

## Platform Setup & Authentication

### Railway.app

#### First-time Setup
1. **Create account** at https://railway.app
2. **Install CLI globally**:
   ```bash
   npm install -g @railway/cli
   ```
3. **Authenticate**:
   ```bash
   railway login
   ```
4. **Initialize project**:
   ```bash
   railway init
   railway link
   ```

#### Deploy
```bash
bun run deploy:railway
```

#### Set Environment Variables
```bash
railway variables set BLADE_AUTH_SECRET=$(openssl rand -base64 30)
railway variables set BLADE_PUBLIC_URL=https://your-app.railway.app
railway variables set RESEND_API_KEY=your-resend-key
```

#### Configuration
- **File**: `railway.json`
- **Builder**: NIXPACKS (automatic)
- **Persistent Volume**: `.blade/state` (configured in railway.json)
- **Health Checks**: Enabled on `/`
- **Auto-restart**: On failure

**Troubleshooting**:
- "Unauthorized" → Run `railway login`
- "Command not found" → Install CLI globally: `npm install -g @railway/cli`

---

### Cloudflare Workers

#### First-time Setup
1. **Create account** at https://cloudflare.com

   ```

#### Deploy
2.
```bash
bun run deploy:cloudflare

```
```
#### C
Configuration
- **File**: `wrangler.jsonc`
- **Runtime**: Edge workers
- **Assets**: Served from binding
- **Build**: `npm run build` (configured)

**Troubleshooting**:
- "Could not route to /accounts/..." → Run `bun x wrangler login`
- Account ID issues → Authentication handles this automatically

---

### Fly.io

#### First-time Setup
1. **Create account** at https://fly.io
2. **Install flyctl**:
   
   **Linux/WSL**:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```
   
   **macOS**:
   ```bash
   brew install flyctl
   ```
   
   **Windows**:
   ```powershell
   iwr https://fly.io/install.ps1 -useb | iex
   ```

3. **Authenticate**:
   ```bash
   flyctl auth login
   ```

4. **Create volume** (one-time):
   ```bash
   flyctl volumes create blade_data --size 1
   ```

5. **Set secrets**:
   ```bash
   flyctl secrets set BLADE_AUTH_SECRET=$(openssl rand -base64 30)
   flyctl secrets set BLADE_PUBLIC_URL=https://your-app.fly.dev
   flyctl secrets set RESEND_API_KEY=your-resend-key
   ```

#### Deploy
```bash
flyctl deploy
```

#### Configuration
- **File**: `fly.toml`
- **Runtime**: Docker (Dockerfile)
- **Persistent Volume**: `.blade/state` (mounted)
- **Health Checks**: HTTP checks on `/`

**Troubleshooting**:
- "Command failed" with `bun x fly` → Don't use npm package, install proper flyctl
- Volume issues → Create volume first: `flyctl volumes create blade_data --size 1`

---

## Database & Storage

### Embedded Hive Database

Your application uses an embedded Hive database stored in `.blade/state/`.

**Default Configuration**:
- Storage Type: `disk`
- Path: `.blade/state`
- Automatic initialization
- Persistent volumes on Railway/Fly.io

**Environment Variables**:
```bash
HIVE_STORAGE_TYPE=disk          # disk, s3, remote, replication
HIVE_DISK_PATH=.blade/state     # Storage path
HIVE_ENCRYPTION_KEY=optional    # For encryption
```

**Storage Types**:
- `disk` - Local file system (default)
- `s3` - AWS S3 storage
- `remote` - Remote API storage
- `replication` - Multiple backends

See [DATABASE.md](./DATABASE.md) for detailed database configuration.

---

## Docker Deployment

### Build & Run
```bash
bun run docker:build
bun run docker:run
```

### Manual Docker
```bash
docker build -t qodin .
docker run -d -p 3000:3000 \
  -v blade_data:/usr/src/app/.blade/state \
  -e BLADE_AUTH_SECRET=$BLADE_AUTH_SECRET \
  -e BLADE_PUBLIC_URL=$BLADE_PUBLIC_URL \
  qodin
```

---

## Environment Variables

### Required for All Platforms
```bash
BLADE_AUTH_SECRET=xxx        # Session encryption (use openssl rand -base64 30)
BLADE_PUBLIC_URL=xxx         # Your app's public URL
```

### Email Service
```bash
RESEND_API_KEY=xxx           # For email verification
```

### Database Configuration
```bash
NODE_ENV=production          # Production mode
BLADE_PLATFORM=container     # For Railway/Fly.io
HIVE_STORAGE_TYPE=disk       # Storage type
HIVE_DISK_PATH=.blade/state  # Database path
```

---

## Available Commands

### Setup
```bash
bun run setup:check          # Check deployment setup
bun run setup:fix            # Interactive setup wizard
bun run setup:railway        # Railway-specific setup
bun run setup:cloudflare     # Cloudflare authentication
bun run setup:fly            # Fly.io setup instructions
```

### Deployment
```bash
bun run deploy:railway       # Deploy to Railway.app
bun run deploy:cloudflare    # Deploy to Cloudflare Workers
flyctl deploy               # Deploy to Fly.io
```

### Database
```bash
bun run db:backup            # Quick backup
bun run db:backup:script     # Full backup script
bun run db:restore           # Restore from backup
blade diff                   # Check schema changes
blade apply                  # Apply migrations
```

### Docker
```bash
bun run docker:build         # Build Docker image
bun run docker:dev           # Run with Docker Compose
bun run docker:run           # Run production container
```

---

## Platform Comparison

| Feature | Railway | Cloudflare | Fly.io |
|---------|---------|------------|--------|
| Setup Difficulty | Easy | Easy | Medium |
| Persistent Storage | ✅ Volume | ⚠️ Limited | ✅ Volume |
| Global CDN | ⚠️ Regional | ✅ Edge | ✅ Multi-region |
| Auto-scaling | ✅ | ✅ | ✅ |
| Health Checks | ✅ | ✅ | ✅ |
| Free Tier | ✅ | ✅ | ✅ |
| Best For | Full apps | Static/API | Docker apps |

---

## Troubleshooting

### Common Issues

**"Unauthorized" or "Please login"**
```bash
# Run setup check
bun run setup:check

# Or use interactive fixer
bun run setup:fix
```

**Build Failures**
```bash
# Ensure dependencies installed
bun install

# Test build locally
bun run build
```

**Database/Storage Issues**
```bash
# Ensure directory exists
mkdir -p .blade/state

# Check storage status
bun run storage:status
```

**Environment Variables Missing**
- Generate auth secret: `openssl rand -base64 30`
- Set all required variables for your platform
- Check `.env.example` for reference

### Platform-Specific Issues

**Railway**:
- Install CLI globally: `npm install -g @railway/cli`
- Link to project: `railway link`
- Check logs: `railway logs`

**Cloudflare**:
- Re-authenticate: `bun x wrangler login`
- Check worker logs: `bun x wrangler tail`
- Verify build output: Check `.blade/dist/edge-worker.js`

**Fly.io**:
- Use proper flyctl (not npm package)
- Create volume before deploy
- Check app status: `flyctl status`

---

## Security Best Practices

1. **Always set strong secrets**:
   ```bash
   openssl rand -base64 30  # Generate secure random string
   ```

2. **Never commit secrets**: Use `.gitignore` and platform secret management

3. **Use HTTPS**: All platforms enforce HTTPS automatically

4. **Enable encryption**: Set `HIVE_ENCRYPTION_KEY` for sensitive data

5. **Restrict access**: Use environment-specific credentials

6. **Monitor logs**: Check for security issues regularly

---

## Performance Tips

1. **Use edge deployment**: Cloudflare Workers for lowest latency
2. **Enable caching**: Platform-specific caching features
3. **Optimize assets**: Use Blade's built-in optimization
4. **Monitor resources**: Set appropriate memory/CPU limits

---

## Support & Resources

### Platform Documentation
- Railway: https://docs.railway.app
- Cloudflare Workers: https://developers.cloudflare.com/workers
- Fly.io: https://fly.io/docs

### Project Documentation
- [README.md](./README.md) - Project overview
- [DATABASE.md](./DATABASE.md) - Database configuration
- `.env.example` - Environment variable reference

### Quick Help
```bash
bun run setup:check    # Check configuration
bun run setup:fix      # Fix issues interactively
```

---

## Next Steps

After successful deployment:

1. ✅ Test your application at the deployed URL
2. ✅ Set up custom domain (optional)
3. ✅ Configure monitoring and alerts
4. ✅ Set up database backups (see DATABASE.md)
5. ✅ Review security settings
6. ✅ Test all features in production
7. ✅ Monitor logs and performance

**Need help?** Run `bun run setup:check` to diagnose issues.
