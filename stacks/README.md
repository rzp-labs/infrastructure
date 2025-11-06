# Docker Stacks

This directory contains all Docker Compose stacks for the homelab infrastructure that Ansible deploys to the homelab VM.

## Architecture

### Root Orchestrator Pattern

The root `docker-compose.yml` uses Docker Compose's `include` feature to orchestrate multiple stacks:

- **Shared resources** are defined once and reused (networks, socket proxy)
- **Individual stacks** remain self-contained and can be deployed independently
- **Current includes**: `docker-socket-proxy`, `traefik`, and `zitadel`

### Directory Structure

```
stacks/
├── docker-compose.yml              # Root orchestrator (DO NOT COMMIT .env here)
├── docker-socket-proxy/
│   └── docker-compose.yml          # Docker socket proxy (tcp://socket-proxy:2375)
├── traefik/
│   ├── docker-compose.yml          # Traefik reverse proxy + oauth2-proxy
│   ├── traefik.yml                 # Traefik static configuration
│   ├── config/                     # Dynamic configuration snippets (synced)
│   ├── acme.json                   # ACME certificate storage (created remotely)
│   ├── .env.example                # Environment template (Cloudflare, domain, OAuth)
│   └── .env                        # Actual secrets (gitignored)
└── zitadel/
    ├── docker-compose.yml          # Zitadel identity provider stack
    ├── .env.example                # Bootstrap + domain configuration template
    ├── .env                        # Actual secrets (gitignored)
    └── config/                     # Shared runtime artifacts (e.g., PAT files)
```

## Deployment Options

### Option 1: Deploy All Stacks (Recommended)

Deploy all stacks at once using the root orchestrator playbook:

```bash
make docker-deploy-all
```

This will:
1. Sync all stack files to `/opt/stacks` on the VM
2. Ensure shared networks (`traefik`, `socket-proxy`) exist
3. Deploy the socket proxy, Traefik, and Zitadel stacks in order
4. Pull the latest images for each service

### Option 2: Deploy Individual Stack

Deploy a single stack independently:

```bash
make docker-deploy stack=traefik
make docker-deploy stack=docker-socket-proxy
make docker-deploy stack=zitadel
```

Per-stack shortcuts are also available (`make docker-deploy-traefik`, etc.). Individual stacks reference `external: true` networks, so ensure the shared networks exist before deploying a new stack (see **Networks** below).

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
      - traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-service.rule=Host(`service.${DOMAIN}`)"
      - "traefik.http.routers.my-service.entrypoints=https"
      - "traefik.http.routers.my-service.tls.certresolver=cloudflare"

networks:
  traefik:
    external: true  # References shared Traefik network
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
make docker-deploy stack=my-service

# Option B: Redeploy everything
make docker-deploy-all
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

You can optionally create `stacks/.env` for variables shared across all stacks, but this is **not recommended** because it couples otherwise independent services.

## Networks

### Shared Networks

- **traefik**: Public reverse-proxy network. Any service that should be routable through Traefik must attach to this network.
- **socket-proxy**: Internal network that exposes the Docker API via the docker-socket-proxy service. Only components that must talk to the Docker API (e.g., Traefik) should join this network.

`make docker-deploy-all` ensures both networks exist. When deploying stacks individually, create them manually if they are missing:

```bash
make docker-deploy-all
docker network create --internal socket-proxy
```

> **Legacy note:** Older documentation referenced a `proxy` network. The current stacks no longer use it, but `docker-deploy-all` still ensures dependencies are satisfied for backward compatibility. It is safe to delete if unused.

### Adding Custom Networks

Add networks to the root orchestrator:

```yaml
networks:
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
make docker-deploy-all  # Already includes pull: always
docker network create traefik
docker network create --internal socket-proxy

# Or deploy the root orchestrator first
make docker-deploy-all
```

### Stack not updating

Force recreation:

```bash
# Individual stack
ssh admin@YOUR_VM
cd /opt/stacks/my-service
docker compose up -d --force-recreate

# All stacks
make docker-deploy-all  # Already includes pull: always
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
