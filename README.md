# Docker Multi-Stage Projects

A comprehensive guide and examples for multi-stage Docker builds with Docker Compose configurations for development and production environments.

## Table of Contents
- [Overview](#overview)
- [Project Structure](#project-structure)
- [Multi-Stage Builds](#multi-stage-builds)
- [Docker Compose Setup](#docker-compose-setup)
- [Getting Started](#getting-started)
- [Development](#development)
- [Production](#production)
- [Best Practices](#best-practices)

## Overview

This project demonstrates:
- **Multi-stage Docker builds** to optimize image size and security
- **Docker Compose** for orchestrating multiple services
- **Environment-specific configurations** for development and production
- **Container best practices** including security, performance, and maintainability

## Project Structure

```
.
├── README.md
├── Dockerfile                 # Multi-stage build configuration
├── docker-compose.yml         # Base compose configuration
├── docker-compose.dev.yml     # Development overrides
├── docker-compose.prod.yml    # Production overrides
├── .dockerignore             # Files to exclude from Docker build
├── .env.example              # Environment variables template
└── src/
    ├── package.json          # Node.js dependencies
    ├── package-lock.json     # Locked dependencies
    ├── app.js                # Main application file
    └── config/
        └── database.js       # Database configuration
```

## Multi-Stage Builds

Multi-stage builds allow you to use multiple `FROM` statements in a single Dockerfile. Each stage can use a different base image and only the final stage's output is included in the final image.

### Benefits:
- **Reduced Image Size**: Build dependencies are not included in the final image
- **Improved Security**: Secrets and build tools are removed from the final image
- **Better Performance**: Smaller images = faster deployments and pulls
- **Cleaner Separation**: Build logic is separate from runtime logic

### Stages in This Project:

1. **builder** - Downloads dependencies and prepares the application
2. **dependencies** - Installs production dependencies only
3. **runtime** - Final stage with only what's needed to run the app

## Docker Compose Setup

This project uses three Compose files:

### docker-compose.yml (Base)
Defines the core services and configuration:
- Application service
- Database service
- Redis cache service
- Common volumes and networks

### docker-compose.dev.yml (Development)
Extends the base configuration for development:
- Volume mounts for live code reload
- Exposed ports for debugging
- Environment variables for development
- Services for development tools

### docker-compose.prod.yml (Production)
Optimizes for production:
- Restart policies
- Resource limits
- Health checks
- Logging configuration
- No volume mounts (immutable containers)

## Getting Started

### Prerequisites
- Docker (version 20.10+)
- Docker Compose (version 1.29+)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/sathishkumarn8/docker-multi-stage-projects.git
cd docker-multi-stage-projects

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
vim .env
```

## Development

### Running in Development Mode

```bash
# Build images
docker-compose build

# Start services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# Or using the convenience command
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### Development Features
- **Live Reload**: Changes to `src/` are reflected immediately
- **Debug Mode**: Exposed ports for debugging tools
- **Volume Mounts**: Direct access to source code
- **Logs**: Visible in console output

### Useful Commands

```bash
# View logs
docker-compose logs -f app

# Execute command in container
docker-compose exec app npm test

# Stop services
docker-compose down

# Remove all volumes
docker-compose down -v
```

## Production

### Building for Production

```bash
# Build optimized images
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

# Start services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Production Features
- **Health Checks**: Automatic container restart on failure
- **Resource Limits**: CPU and memory restrictions
- **Restart Policy**: Automatic recovery
- **Logging**: Structured logging with size limits
- **Security**: Non-root user, read-only filesystems where possible

### Deployment Considerations

```bash
# Tag images for registry
docker tag app:latest myregistry.azurecr.io/app:latest

# Push to registry
docker push myregistry.azurecr.io/app:latest

# Pull and run on production server
docker pull myregistry.azurecr.io/app:latest
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## Best Practices

### 1. Use Specific Base Image Tags
```dockerfile
# ✅ Good
FROM node:18.17.0-alpine

# ❌ Avoid
FROM node:latest
FROM node:18
```

### 2. Multi-Stage Builds
```dockerfile
# Stage 1: Builder
FROM node:18-alpine AS builder
RUN npm ci
RUN npm run build

# Stage 2: Runtime
FROM node:18-alpine
COPY --from=builder /app/dist /app/dist
CMD ["node", "dist/app.js"]
```

### 3. Use .dockerignore
Exclude unnecessary files from build context:
```
node_modules
npm-debug.log
.git
.gitignore
.env
.env.local
Coverage reports
```

### 4. Run as Non-Root User
```dockerfile
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001
USER nodejs
```

### 5. Health Checks
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node healthcheck.js
```

### 6. Minimize Layer Count
```dockerfile
# ✅ Good - Fewer layers
RUN apt-get update && \
    apt-get install -y --no-install-recommends package1 package2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ❌ Avoid - Multiple layers
RUN apt-get update
RUN apt-get install -y package1
RUN apt-get install -y package2
```

### 7. Environment Variables
```dockerfile
# Set at build time (can be overridden)
ENV NODE_ENV=production

# Or use ARG for build-time only
ARG BUILD_DATE
LABEL org.opencontainers.image.created=$BUILD_DATE
```

### 8. Networking
```yaml
# Services communicate using service names
services:
  app:
    environment:
      DATABASE_URL: postgres://db:5432/myapp
  db:
    image: postgres:15-alpine
```

### 9. Volume Management
```yaml
# ✅ Named volumes (persistent)
volumes:
  db-data:
    driver: local

# ✅ Bind mounts (development only)
volumes:
  - ./src:/app/src
```

### 10. Security
- Use secrets management (Docker Secrets, HashiCorp Vault)
- Scan images for vulnerabilities: `docker scan image-name`
- Use private registries for sensitive images
- Keep base images updated
- Don't include secrets in environment files

## Example Commands

### Development Workflow
```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f app

# Run tests
docker-compose exec app npm test

# Stop services
docker-compose down
```

### Production Workflow
```bash
# Build with optimizations
docker-compose -f docker-compose.yml -f docker-compose.prod.yml build --no-cache

# Start services
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Monitor
docker-compose ps
docker-compose logs app

# Update image
docker-compose pull
docker-compose up -d
```

## Troubleshooting

### Container exits immediately
```bash
# Check logs
docker-compose logs app

# Inspect image
docker inspect image-name
```

### Port already in use
```bash
# Find process using port
lsof -i :3000

# Kill process or change port in .env
```

### Permission denied
```bash
# Check file permissions
ls -la src/

# Fix ownership (if needed)
sudo chown -R $USER:$USER .
```

## Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Specification](https://github.com/compose-spec/compose-spec)
- [Best Practices for Writing Dockerfiles](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Multi-stage Builds Guide](https://docs.docker.com/build/building/multi-stage/)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
