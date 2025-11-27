FROM oven/bun:1-alpine

WORKDIR /usr/src/app

# Copy package files
COPY package.json bun.lock* ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy application files
COPY . .

# Build the application
RUN bun run build

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001 -G nodejs && \
    chown -R nextjs:nodejs /usr/src/app
USER nextjs

# Expose port
EXPOSE 3000/tcp

# Set environment variables
ENV NODE_ENV=production
ENV BLADE_PLATFORM=container
ENV HIVE_STORAGE_TYPE=disk
ENV HIVE_DISK_PATH=.blade/state

# Create and document the volume mount point for persistent database storage
RUN mkdir -p .blade/state
VOLUME [".blade/state"]

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD bun -e "fetch('http://localhost:3000').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))" || exit 1

# Start the application
CMD ["bun", "run", "serve"]