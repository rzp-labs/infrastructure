# Docker Stacks

This directory contains all Docker Compose stacks for the homelab infrastructure.

## Architecture

### Root Orchestrator Pattern

The root `docker-compose.yml` uses Docker Compose's `include` feature to orchestrate multiple stacks:

- **Shared resources** (networks) are defined at the root level
- **Individual stacks** are included and can still be managed independently
- **Deployment order** is implicit based on dependency order

### Directory Structure

```
stacks/
├── docker-compose.yml              # Root orchestrator (DO NOT COMMIT .env here)
├── docker-socket-proxy/
│   └── docker-compose.yml          # Socket proxy service
└── traefik/
    ├── docker-compose.yml          # Traefik reverse proxy
    ├── traefik.yml                 # Traefik static config
    ├── .env.example                # Environment template
    └── .env                        # Your secrets (gitignored)
```

## Deployment Options

### Option 1: Deploy All Stacks (Recommended)

Deploy all stacks at once using the root orchestrator:

```bash
make deploy-all
```

This will:
1. Sync all stack files to `/opt/stacks` on the VM
2. Create shared networks
3. Deploy all services in proper order
4. Pull latest images

### Option 2: Deploy Individual Stack

Deploy a single stack independently:

```bash
make deploy stack=traefik
make deploy stack=docker-socket-proxy
```

Individual stacks reference `external: true` for shared networks, so they can be deployed independently after the network exists.

## Adding New Stacks

1. **Create stack directory**: `mkdir stacks/my-service`

2. **Create docker-compose.yml**:
```yaml
services:
  my-service:
    image: my-image:latest
    container_name: my-service
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-service.rule=Host(`service.${DOMAIN}`)"
      - "traefik.http.routers.my-service.entrypoints=https"
      - "traefik.http.routers.my-service.tls.certresolver=cloudflare"

networks:
  proxy:
    external: true  # References root-level network
```

3. **Add to root orchestrator** (`stacks/docker-compose.yml`):
```yaml
include:
  - docker-socket-proxy/docker-compose.yml
  - traefik/docker-compose.yml
  - my-service/docker-compose.yml  # Add your new stack
```

4. **Deploy**:
```bash
# Option A: Deploy just the new stack
make deploy stack=my-service

# Option B: Redeploy everything
make deploy-all
```

## Environment Variables

### Per-Stack .env Files

Each stack can have its own `.env` file for service-specific configuration:

```bash
stacks/traefik/.env       # Traefik config (CF tokens, domain)
stacks/my-service/.env    # Your service config
```

**Important**: `.env` files are gitignored. Always provide `.env.example` templates.

### Root .env File

You can optionally create `stacks/.env` for variables shared across all stacks, but this is **not recommended** as it couples services together.

## Networks

### Proxy Network

The `proxy` network is owned by the root compose and shared by all stacks:

- **Created by**: Root `docker-compose.yml`
- **Referenced by**: Individual stacks with `external: true`
- **Purpose**: Allows Traefik to route traffic to services

### Adding Custom Networks

Add networks to the root orchestrator:

```yaml
networks:
  proxy:
    name: proxy
    driver: bridge

  database:
    name: database
    driver: bridge
    internal: true  # Not accessible from outside
```

Then reference in individual stacks:

```yaml
networks:
  database:
    external: true
```

## Best Practices

1. **Keep stacks independent**: Each stack should work standalone
2. **Use external networks**: Reference shared networks with `external: true`
3. **Document dependencies**: Add comments about service dependencies
4. **Test individually**: Verify each stack works before adding to orchestrator
5. **Use .env.example**: Always commit example env files, never real secrets

## Troubleshooting

### Network not found

If deploying individual stack fails with network error:

```bash
# Create the network manually
docker network create proxy

# Or deploy the root orchestrator first
make deploy-all
```

### Stack not updating

Force recreation:

```bash
# Individual stack
ssh admin@YOUR_VM
cd /opt/stacks/my-service
docker compose up -d --force-recreate

# All stacks
make deploy-all  # Already includes pull: always
```

### View logs

```bash
# Via Ansible
uv run ansible homelab -a "docker logs traefik"
uv run ansible homelab -a "docker compose -f /opt/stacks/docker-compose.yml logs"

# Via SSH
ssh admin@YOUR_VM
docker logs traefik
docker logs -f docker-socket-proxy
```
