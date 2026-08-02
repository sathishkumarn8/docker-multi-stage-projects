# Multi-stage Docker build for optimized image size and security
# Stage 1: Builder - Download and prepare dependencies
# Stage 2: Dependencies - Install production-only dependencies
# Stage 3: Runtime - Final image with only what's needed

# ============================================================================
# Stage 1: Builder
# ============================================================================
# This stage downloads and prepares the application code and all dependencies
FROM node:18.17.0-alpine AS builder

# Set working directory
WORKDIR /app

# Install build dependencies (if needed for native modules)
RUN apk add --no-cache --virtual .build-deps \
    python3 \
    make \
    g++

# Copy package files
COPY package.json package-lock.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci --prefer-offline --no-audit

# Copy application source code
COPY src/ ./src/

# Build the application (if needed)
RUN npm run build 2>/dev/null || echo "No build script"

# ============================================================================
# Stage 2: Dependencies
# ============================================================================
# This stage installs only production dependencies
FROM node:18.17.0-alpine AS dependencies

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install only production dependencies
RUN npm ci --only=production --prefer-offline --no-audit && \
    npm cache clean --force

# ============================================================================
# Stage 3: Runtime
# ============================================================================
# This is the final image - only includes what's needed to run the app
FROM node:18.17.0-alpine

# Add metadata labels
LABEL maintainer="your-email@example.com"
LABEL description="Multi-stage Node.js application"
LABEL version="1.0.0"

# Set working directory
WORKDIR /app

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy production dependencies from dependencies stage
COPY --from=dependencies --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy built application from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/src ./src

# Copy package.json for reference
COPY --chown=nodejs:nodejs package.json .

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {if (r.statusCode !== 200) throw new Error(r.statusCode)})" || exit 1

# Switch to non-root user
USER nodejs

# Start application
CMD ["node", "src/app.js"]
