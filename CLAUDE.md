# CLAUDE.md - Infrastructure

This file provides Infrastructure-as-Code specific guidance for Claude Code when working in this submodule.

**For general project guidance, see the parent repository's CLAUDE.md and AGENTS.md files.**

## Project Overview

Homelab Infrastructure-as-Code using Ansible to deploy Docker Compose stacks to a Debian VM in Proxmox. Security-first architecture with Traefik reverse proxy and Docker Socket Proxy.

**Key Technologies:**
- Ansible (2.15+) for configuration management
- Docker Compose v2 (standalone)
- Python 3.12+ with `uv` package manager
- Traefik v3.2 with Cloudflare DNS challenge
- Docker Socket Proxy for secure API access

## Essential Commands

```bash
# Initial setup
make setup          # Install Python deps + Ansible collections
make ping           # Test VM connectivity

# Linting
make lint           # Check YAML, Ansible, shell scripts
make format         # Auto-format YAML and shell scripts

# Deployment
make install-docker # First-time Docker installation on VM
make deploy stack=<name>  # Deploy single stack
make deploy-all     # Deploy all stacks via root orchestrator
```

## Architecture Patterns

### Root Orchestrator Pattern

`stacks/docker-compose.yml` uses Docker Compose v2's `include` feature:
- Individual stacks remain independent
- Shared resources (networks) defined at root level
- Stacks reference shared networks using `external: true`

### Deployment Flow

1. Ansible syncs `stacks/` to `/opt/stacks/` on VM (`.env` files excluded)
2. Docker Compose runs on remote VM
3. Images always pulled (`pull: always`)

**Important:** Deployment happens ON the VM, Ansible is just the orchestrator.

### Security Architecture

**Docker Socket Proxy Pattern:**
- Services NEVER access Docker socket directly
- All Docker API requests go through socket proxy
- Restricted permissions (read-only for containers/networks/services/tasks)
- Dangerous operations blocked (POST=0, BUILD=0, EXEC=0, etc.)

**Traefik:** Connects via `tcp://docker-socket-proxy:2375` not `unix:///var/run/docker.sock`

### Network Architecture

**Shared Proxy Network:**
```bash
docker network create proxy  # Created by root orchestrator
```
- Referenced by stacks: `networks: proxy: external: true`
- All Traefik-routed services join this network
- Persists even if root orchestrator is down

## Adding New Services

1. Create `stacks/my-service/docker-compose.yml`
2. Join proxy network and add Traefik labels:
   ```yaml
   networks:
     - proxy
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.my-service.rule=Host(`service.${DOMAIN}`)"
     - "traefik.http.routers.my-service.entrypoints=https"
     - "traefik.http.routers.my-service.tls.certresolver=cloudflare"
   ```
3. Create `.env.example` template
4. Deploy: `make deploy stack=my-service`
5. Optionally add to root orchestrator's `include` list

## Configuration

### Inventory

Create `inventory/hosts.yml` from template:
```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

Edit with your VM details:
```yaml
ansible_host: 10.0.0.100
ansible_user: admin
```

### Environment Variables

- `.env` files NEVER synced to VM
- Must be created manually on VM at `/opt/stacks/<stack-name>/.env`
- Always provide `.env.example` templates

## File Organization

```
infrastructure/
├── inventory/          # Ansible inventory (gitignored)
├── playbooks/          # Ansible playbooks
├── stacks/             # Docker Compose stacks
├── scripts/            # Helper scripts (if any)
├── ansible.cfg         # Ansible configuration
├── pyproject.toml      # Python dependencies
├── requirements.yml    # Ansible collections
└── Makefile            # Task automation
```

## Development

This submodule uses the parent repository's DevContainer. All tools (Python, Ansible, Docker, linting) are available in the parent's development environment.

**Python commands** (run with uv):
```bash
uv run ansible homelab -m ping
uv run ansible-playbook playbooks/deploy-stack.yml
```

**Ansible Collections:**
- `community.docker` - Docker module support
- `ansible.posix` - Synchronize module for rsync
- `geerlingguy.docker` - Docker installation role

Install with: `make setup`

## Linting

Configured tools:
- **yamllint** - YAML syntax validation
- **ansible-lint** - Ansible best practices
- **yamlfmt** - YAML formatting
- **shfmt** - Shell script formatting
- **EditorConfig** - Editor consistency

Run via `make lint` or `make format`
