# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Infrastructure-as-Code repository for managing a homelab environment. It uses Ansible to deploy Docker Compose stacks to a single Debian VM running in Proxmox. The architecture follows a root orchestrator pattern with security-first design principles.

**Key Technologies:**
- Ansible (2.15+) for configuration management and deployment
- Docker Compose v2 with standalone installation (not Docker Desktop)
- Python 3.12+ with `uv` package manager
- Traefik v3.2 as reverse proxy with automatic SSL via Cloudflare DNS challenge
- Docker Socket Proxy for secure Docker API access

## Essential Commands

### Setup and Development

```bash
# Initial setup (install Python deps + Ansible collections)
make setup

# Test connectivity to VM
make ping

# Lint YAML, Ansible playbooks, and shell scripts
make lint

# Auto-format YAML and shell scripts
make format

# Validate deployment configuration
make check-deploy
```

### Deployment

```bash
# Install Docker on the VM (first time only)
make install-docker

# Deploy a single stack
make deploy stack=docker-socket-proxy
make deploy stack=traefik
make deploy stack=<stack-name>

# Deploy all stacks using root orchestrator
make deploy-all
```

### Ad-hoc Commands

```bash
# Run arbitrary commands on the VM
uv run ansible homelab -a "docker ps"
uv run ansible homelab -a "docker compose -f /opt/stacks/docker-compose.yml ps"
uv run ansible homelab -a "df -h"

# View logs
uv run ansible homelab -a "docker logs traefik"
uv run ansible homelab -a "docker logs docker-socket-proxy"
```

## Architecture Patterns

### Root Orchestrator Pattern

The [stacks/docker-compose.yml](stacks/docker-compose.yml) file uses Docker Compose v2's `include` feature to orchestrate multiple stacks:

- Individual stacks remain independent (can be deployed separately)
- Shared resources (networks) are defined at root level
- Stacks reference shared networks using `external: true`

This pattern allows both centralized deployment (`make deploy-all`) and individual stack deployment (`make deploy stack=name`).

### Deployment Flow

All deployments follow this flow via Ansible:

1. Files are synced from local `stacks/` directory to `/opt/stacks/` on the VM using rsync
2. `.env` files are EXCLUDED from sync (must be created manually on the VM)
3. Docker Compose runs on the remote VM to deploy services
4. Images are always pulled (`pull: always`) to ensure latest versions

**Important:** The deployment happens ON the VM, not locally. Ansible is just the orchestrator.

### Security Architecture

**Docker Socket Proxy Pattern:**
- Traefik (and other services) NEVER access Docker socket directly
- All Docker API requests go through [stacks/docker-socket-proxy/docker-compose.yml](stacks/docker-socket-proxy/docker-compose.yml)
- Socket proxy has restricted permissions (read-only for containers/networks/services/tasks)
- Dangerous operations blocked (POST=0, BUILD=0, EXEC=0, COMMIT=0, etc.)

**Traefik connects via:** `tcp://docker-socket-proxy:2375` instead of `unix:///var/run/docker.sock`

### Traefik Configuration

Traefik is configured via:
- Static config: [stacks/traefik/traefik.yml](stacks/traefik/traefik.yml)
- Dynamic config: Docker labels on service containers
- Environment variables: `stacks/traefik/.env` (gitignored)

**Service Registration Pattern:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`app.${DOMAIN}`)"
  - "traefik.http.routers.app.entrypoints=https"
  - "traefik.http.routers.app.tls.certresolver=cloudflare"
  - "traefik.http.services.app.loadbalancer.server.port=80"
```

SSL certificates are automatically obtained via Let's Encrypt using Cloudflare DNS challenge (supports wildcard certs).

### Network Architecture

**Shared Proxy Network:**
- Created by root orchestrator: `docker network create proxy`
- Referenced by individual stacks: `networks: proxy: external: true`
- All Traefik-routed services must join this network
- The network persists even if the root orchestrator is down

## Adding New Services

1. Create directory: `mkdir -p stacks/my-service`
2. Create `stacks/my-service/docker-compose.yml`:
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
       external: true
   ```
3. Create `.env.example` if environment variables are needed
4. Deploy: `make deploy stack=my-service`
5. (Optional) Add to root orchestrator's `include` list for centralized deployment

## Inventory Configuration

The Ansible inventory is at [inventory/hosts.yml](inventory/hosts.yml) (gitignored). Create from template:

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

Key fields:
- `ansible_host`: VM's IP address (e.g., 10.0.0.100)
- `ansible_user`: SSH user on the VM
- `ansible_ssh_common_args`: (Optional) Specify SSH identity file for 1Password users with multiple keys

The inventory defines the `homelab` host group used by all playbooks.

## Python Environment

This project uses `uv` for Python dependency management:
- Dependencies defined in [pyproject.toml](pyproject.toml)
- Virtual environment: `.venv-container/` (when using DevContainer)
- Main dependencies: ansible, ansible-lint, yamllint
- Dev dependencies: ruff (Python linting)

**Always prefix commands with `uv run`:**
```bash
uv run ansible-playbook playbooks/deploy-stack.yml
uv run ansible homelab -m ping
```

## Ansible Collections

Required collections (defined in [requirements.yml](requirements.yml)):
- `community.docker`: Docker module support
- `ansible.posix`: Synchronize module for rsync
- `geerlingguy.docker`: Docker installation role

Install with: `make setup` (or `uv run ansible-galaxy collection install -r requirements.yml`)

## DevContainer

The [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json) provides a complete development environment:

- Python 3.12 base image
- Docker-outside-of-Docker (uses host Docker)
- SSH keys mounted read-only from `~/.ssh/`
- 1Password SSH agent support
- Java 21 for SonarLint
- Pre-configured VS Code extensions (Ansible, YAML, Python, linting tools)
- YAML schemas for Ansible playbooks and Docker Compose files

The [.devcontainer/setup.sh](.devcontainer/setup.sh) post-create script runs `make setup` automatically.

## File Organization

```
/workspaces/new-infra/
├── inventory/
│   └── hosts.yml              # Ansible inventory (gitignored, create from .example)
├── playbooks/
│   ├── install-docker.yml     # Install Docker on VM (uses geerlingguy.docker role)
│   ├── deploy-stack.yml       # Deploy single stack (requires -e stack=name)
│   └── deploy-all-stacks.yml  # Deploy all stacks sequentially
├── stacks/
│   ├── docker-compose.yml     # Root orchestrator (uses 'include' pattern)
│   ├── docker-socket-proxy/   # Security proxy for Docker API
│   └── traefik/               # Reverse proxy + SSL
├── ansible.cfg                # Ansible configuration (inventory path, privilege escalation)
├── pyproject.toml             # Python dependencies (managed by uv)
├── requirements.yml           # Ansible collections and roles
└── Makefile                   # Task automation
```

## Important Behaviors

**Environment Variables:**
- `.env` files are NEVER synced to the VM (excluded in rsync)
- Must be created manually on the VM at `/opt/stacks/<stack-name>/.env`
- Always provide `.env.example` templates in stacks
- Deployment warns if required `.env` files are missing

**Ansible Configuration ([ansible.cfg](ansible.cfg)):**
- Inventory: `inventory/hosts.yml`
- Privilege escalation: Automatically uses sudo
- Python interpreter: Auto-detected (`auto_silent`)
- Host key checking: Enabled (default) for security against MITM attacks
  - For initial setup of new hosts, use: `ANSIBLE_HOST_KEY_CHECKING=False make deploy stack=...`
  - After first connection, host key will be in `~/.ssh/known_hosts` and subsequent connections are verified

**Deployment Idempotency:**
- Playbooks can be run multiple times safely
- Docker Compose uses declarative state (`state: present`)
- Always pulls latest images (`pull: always`)

**Traefik Specifics:**
- `acme.json` automatically created with mode `0600` (required by Let's Encrypt)
- Dashboard accessible at `http://VM_IP:8080/dashboard/` or `https://traefik.domain.com`
- Requires Cloudflare API token in `.env` for DNS challenge

## Linting and Formatting

Configured tools:
- **yamllint** ([.yamllint](.yamllint)): YAML syntax validation
- **ansible-lint** ([.ansible-lint](.ansible-lint)): Ansible best practices
- **yamlfmt** ([.yamlfmt](.yamlfmt)): YAML formatting (requires separate install)
- **shfmt**: Shell script formatting (requires separate install)
- **EditorConfig** ([.editorconfig](.editorconfig)): Editor consistency

Run via `make lint` (check) or `make format` (fix).

## Git Configuration

The repository has a clean status with recent commits focusing on:
- DevContainer PATH configuration fixes
- Deployment orchestration validation tools
- Root orchestrator pattern implementation
- SonarLint Java 21 configuration

Main branch is `main` (also the default for PRs).
