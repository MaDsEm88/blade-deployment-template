#!/bin/bash

# Create Blade Template Repository
# This script copies all necessary files to create a template repository

set -e

echo "🚀 Creating Blade Template Repository"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get target directory
read -p "Enter target directory name (default: blade-deployment-template): " TARGET_DIR
TARGET_DIR=${TARGET_DIR:-blade-deployment-template}

# Check if directory exists
if [ -d "../$TARGET_DIR" ]; then
    echo "⚠️  Directory ../$TARGET_DIR already exists"
    read -p "Delete and recreate? (yes/no): " CONFIRM
    if [ "$CONFIRM" = "yes" ]; then
        rm -rf "../$TARGET_DIR"
    else
        echo "❌ Cancelled"
        exit 1
    fi
fi

# Create target directory
echo "📁 Creating directory: ../$TARGET_DIR"
mkdir -p "../$TARGET_DIR"

# Copy configuration files
echo "📄 Copying configuration files..."
cp package.json "../$TARGET_DIR/"
cp .gitignore "../$TARGET_DIR/"
cp .env.example "../$TARGET_DIR/"

# Copy platform configs
echo "⚙️  Copying platform configurations..."
cp railway.json "../$TARGET_DIR/" 2>/dev/null || echo "  ⚠️  railway.json not found, skipping"
cp wrangler.jsonc "../$TARGET_DIR/" 2>/dev/null || echo "  ⚠️  wrangler.jsonc not found, skipping"
cp fly.toml "../$TARGET_DIR/" 2>/dev/null || echo "  ⚠️  fly.toml not found, skipping"
cp Dockerfile "../$TARGET_DIR/" 2>/dev/null || echo "  ⚠️  Dockerfile not found, skipping"
cp docker-compose.yml "../$TARGET_DIR/" 2>/dev/null || echo "  ⚠️  docker-compose.yml not found, skipping"

# Copy scripts
echo "📜 Copying deployment scripts..."
mkdir -p "../$TARGET_DIR/scripts"
cp scripts/check-deployment-setup.sh "../$TARGET_DIR/scripts/"
cp scripts/fix-deployment-issues.sh "../$TARGET_DIR/scripts/"
cp scripts/backup-db.sh "../$TARGET_DIR/scripts/" 2>/dev/null || echo "  ⚠️  backup-db.sh not found, skipping"
cp scripts/restore-db.sh "../$TARGET_DIR/scripts/" 2>/dev/null || echo "  ⚠️  restore-db.sh not found, skipping"
chmod +x "../$TARGET_DIR/scripts/"*.sh

# Copy documentation
echo "📚 Copying documentation..."
cp DEPLOYMENT.md "../$TARGET_DIR/"
cp DATABASE.md "../$TARGET_DIR/"
cp IMPLEMENT_DEPLOYMENT_SCRIPTS.md "../$TARGET_DIR/"
cp IMPLEMENT_EMBEDDED_DATABASE.md "../$TARGET_DIR/"

# Create directory structure
echo "📂 Creating directory structure..."
mkdir -p "../$TARGET_DIR/schema"
mkdir -p "../$TARGET_DIR/pages"
mkdir -p "../$TARGET_DIR/components"
mkdir -p "../$TARGET_DIR/lib"
touch "../$TARGET_DIR/components/.gitkeep"
touch "../$TARGET_DIR/lib/.gitkeep"

# Create minimal schema
echo "📝 Creating example schema..."
cat > "../$TARGET_DIR/schema/index.ts" << 'EOF'
import { field, model, slug } from 'blade';

// Example: Use built-in Account model
export const Account = model.Account.extend({
  fields: {
    handle: field.slug(),
    // Add your custom fields here
  },
});

// Example: Custom model (commented out - uncomment to use)
/*
export const Post = model({
  slug: 'post',
  fields: {
    slug: slug(),
    title: field.string(),
    content: field.string(),
    createdAt: field.date(),
  },
});
*/
EOF

# Create basic home page
echo "🏠 Creating home page..."
cat > "../$TARGET_DIR/pages/index.tsx" << 'EOF'
export default function Home() {
  return (
    <div style={{ 
      maxWidth: '800px', 
      margin: '0 auto', 
      padding: '2rem',
      fontFamily: 'system-ui, -apple-system, sans-serif'
    }}>
      <h1>🚀 Blade Deployment Template</h1>
      <p>
        A production-ready starter template with embedded Hive database and
        automated deployment to Railway, Cloudflare Workers, and Fly.io.
      </p>
      
      <h2>✨ Features</h2>
      <ul>
        <li>Embedded Hive database (no external dependencies)</li>
        <li>Multi-platform deployment automation</li>
        <li>Interactive setup tools</li>
        <li>Backup/restore scripts</li>
        <li>Docker support</li>
      </ul>

      <h2>🚀 Quick Start</h2>
      <ol>
        <li>Clone this repository</li>
        <li>Run: <code>bun install</code></li>
        <li>Run: <code>cp .env.example .env</code></li>
        <li>Run: <code>bun run dev</code></li>
        <li>Edit <code>schema/index.ts</code> to add your models</li>
        <li>Run: <code>blade diff --apply</code></li>
      </ol>

      <h2>📦 Deployment</h2>
      <pre><code>{`# Check setup
bun run setup:check

# Fix issues
bun run setup:fix

# Deploy
bun run deploy:railway      # Railway.app
bun run deploy:cloudflare   # Cloudflare Workers
flyctl deploy              # Fly.io`}</code></pre>

      <h2>📚 Documentation</h2>
      <ul>
        <li><strong>DEPLOYMENT.md</strong> - Complete deployment guide</li>
        <li><strong>DATABASE.md</strong> - Database configuration</li>
        <li><strong>IMPLEMENT_*.md</strong> - Implementation guides</li>
      </ul>

      <p style={{ marginTop: '2rem', padding: '1rem', background: '#f0f0f0', borderRadius: '8px' }}>
        <strong>Need help?</strong> Run <code>bun run setup:check</code> to verify your setup.
      </p>
    </div>
  );
}
EOF

# Create template README
echo "📖 Creating README..."
cat > "../$TARGET_DIR/README.md" << 'EOF'
# Blade Deployment Template

A production-ready Blade starter template with embedded Hive database and automated deployment to Railway, Cloudflare Workers, and Fly.io.

## Features

✅ **Embedded Hive Database** - Self-contained database with no external dependencies  
✅ **Multi-Platform Deployment** - Deploy to Railway, Cloudflare, or Fly.io  
✅ **Automated Setup** - Interactive CLI tools for deployment setup  
✅ **Backup/Restore** - Built-in database backup and restore scripts  
✅ **Docker Support** - Dockerfile and docker-compose for containerized deployment  
✅ **TypeScript** - Full type safety with TypeScript  
✅ **Production Ready** - Optimized configurations for all platforms

## Quick Start

### 1. Clone & Install

```bash
# Use this template on GitHub or clone directly
git clone https://github.com/yourusername/blade-deployment-template.git
cd blade-deployment-template
bun install
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env and set BLADE_AUTH_SECRET
```

Generate a secure auth secret:
```bash
openssl rand -base64 30
```

### 3. Start Development

```bash
bun run dev
```

Visit http://localhost:3000

### 4. Define Your Schema

Edit `schema/index.ts` to add your models:

```typescript
export const Post = model({
  slug: 'post',
  fields: {
    slug: slug(),
    title: field.string(),
    content: field.string(),
  },
});
```

### 5. Apply Schema Changes

```bash
blade diff --apply
```

## Deployment

### Quick Deploy

```bash
# 1. Check setup
bun run setup:check

# 2. Fix any issues
bun run setup:fix

# 3. Deploy
bun run deploy:railway      # Railway.app
bun run deploy:cloudflare   # Cloudflare Workers
flyctl deploy              # Fly.io
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed instructions.

## Available Commands

```bash
# Development
bun run dev              # Start dev server

# Deployment
bun run setup:check      # Check deployment setup
bun run setup:fix        # Interactive setup wizard
bun run deploy:railway   # Deploy to Railway
bun run deploy:cloudflare # Deploy to Cloudflare

# Database
blade diff               # Check schema changes
blade apply              # Apply migrations
bun run db:backup:script # Backup database
bun run db:restore       # Restore database

# Docker
bun run docker:build     # Build Docker image
bun run docker:dev       # Run with Docker Compose
```

## Documentation

- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Complete deployment guide
- **[DATABASE.md](./DATABASE.md)** - Database configuration
- **[IMPLEMENT_DEPLOYMENT_SCRIPTS.md](./IMPLEMENT_DEPLOYMENT_SCRIPTS.md)** - Add to other projects
- **[IMPLEMENT_EMBEDDED_DATABASE.md](./IMPLEMENT_EMBEDDED_DATABASE.md)** - Database implementation

## Platform Comparison

| Feature | Railway | Cloudflare | Fly.io |
|---------|---------|------------|--------|
| Setup | Easy | Easy | Medium |
| Storage | ✅ Volume | ⚠️ Limited | ✅ Volume |
| Global | Regional | Edge | Multi-region |
| Free Tier | ✅ | ✅ | ✅ |

## Project Structure

```
blade-deployment-template/
├── schema/              # Database schema
├── pages/              # Blade routes
├── components/         # React components
├── lib/                # Utilities
├── scripts/            # Deployment scripts
├── DEPLOYMENT.md       # Deployment guide
└── DATABASE.md         # Database guide
```

## Environment Variables

Required:
- `BLADE_AUTH_SECRET` - Session encryption key
- `BLADE_PUBLIC_URL` - Your app's public URL

Optional:
- `RESEND_API_KEY` - For email
- `HIVE_STORAGE_TYPE` - Storage backend
- See `.env.example` for full list

## License

MIT License - Use freely in your projects

## Support

- Issues: [GitHub Issues](https://github.com/yourusername/blade-deployment-template/issues)
- Blade Framework: https://blade.new

---

**Ready to deploy?** Run `bun run setup:check` to get started! 🚀
EOF

# Create LICENSE
echo "📜 Creating LICENSE..."
cat > "../$TARGET_DIR/LICENSE" << 'EOF'
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Initialize git
echo "🌱 Initializing git repository..."
cd "../$TARGET_DIR"
git init
git branch -M main
git add .
git commit -m "Initial commit: Blade deployment template with database and automation"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Template repository created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📁 Location: ../$TARGET_DIR"
echo ""
echo "Next steps:"
echo "1. cd ../$TARGET_DIR"
echo "2. Review and customize files (update app names in configs)"
echo "3. Create GitHub repository"
echo "4. git remote add origin https://github.com/yourusername/$TARGET_DIR.git"
echo "5. git push -u origin main"
echo ""
echo "Don't forget to:"
echo "• Enable 'Template repository' in GitHub settings"
echo "• Add topics: blade, deployment, hive-database, template"
echo "• Update README.md with your GitHub username"
echo ""
