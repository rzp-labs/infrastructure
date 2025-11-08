# CLAUDE.md - Infrastructure

This file provides Infrastructure-as-Code specific guidance for Claude Code when working in this submodule.

This project uses a shared context file (`AGENTS.md`) for common project guidelines. Please refer to it for information on build commands, code style, and design philosophy.

This file is reserved for Claude Code-specific instructions.

# import the following files (using the `@` syntax):

- @AGENTS.md
- @../AGENTS.md
- @../CLAUDE.md
- @../DISCOVERIES.md
- @../ai_context/IMPLEMENTATION_PHILOSOPHY.md
- @../ai_context/MODULAR_DESIGN_PHILOSOPHY.md

## Project Overview

Homelab Infrastructure-as-Code using Ansible to deploy Docker Compose stacks to a Debian VM in Proxmox. Security-first architecture with Traefik reverse proxy and Docker Socket Proxy.

**Key Technologies:**
- Ansible (2.15+) for configuration management
- Docker Compose v2 (standalone)
- Python 3.12+ with `uv` package manager
- Traefik v3.2 with Cloudflare DNS challenge
- Docker Socket Proxy for secure API access

## Essential Commands

**Pure Delegation Architecture**: Infrastructure follows workspace-wide standard Makefile targets.

```bash
# Standard targets (Pure Delegation pattern)
make install        # Install Python deps + Ansible collections
make check          # Run linting (YAML + Ansible + shell scripts)
make test           # Validate Ansible playbooks and configuration

# Backward-compatible aliases
make setup          # Alias for install
make lint           # Alias for check

# Connectivity and deployment
make ping           # Test VM connectivity
make docker-deploy stack=<name>  # Deploy single stack
make check-deploy   # Validate deployment configuration

# Development
make format         # Auto-format YAML and shell scripts
make clean          # Remove temporary files
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
4. Deploy: `make docker-deploy stack=my-service`
5. Optionally add to root orchestrator's `include` list

## SSH Configuration

### SSH Agent Forwarding Architecture

The infrastructure uses **SSH agent forwarding with 1Password** for secure Ansible authentication:

```
1Password SSH Agent (macOS Host)
    ↓ SSH_AUTH_SOCK forwarded by VSCode
DevContainer (Ansible)
    ↓ SSH connection using forwarded agent
Target Homelab Hosts
```

**Key Points:**
- Private keys NEVER stored in containers or repository
- SSH agent automatically forwarded by DevContainer feature
- Works across multiple development hosts (office + home Macs)
- 1Password SSH keys sync across all your machines

### SSH Setup for Users

**Prerequisites:**
1. Enable 1Password SSH agent (Settings → Developer)
2. Add SSH keys to 1Password vault
3. Configure inventory with SSH agent settings

**Verification:**
```bash
echo $SSH_AUTH_SOCK  # Verify agent forwarding
ssh-add -l           # List keys from 1Password
make ping            # Test Ansible connectivity
```

**Complete guide:** [docs/SSH_SETUP.md](docs/SSH_SETUP.md)

### Known Hosts Management

SSH host keys are stored workspace-locally in `.ssh/known_hosts`:

- **Gitignored** - Each workspace maintains its own known hosts
- **Per-workspace** - Different workspaces can target different hosts
- **Regenerable** - Can be deleted and recreated via `make ping`
- **Security** - Provides MITM protection via StrictHostKeyChecking

### Troubleshooting SSH

**"Permission denied (publickey)":**
- Verify `SSH_AUTH_SOCK` is set: `echo $SSH_AUTH_SOCK`
- Check keys available: `ssh-add -l`
- Ensure 1Password SSH agent is enabled

**"Host key verification failed":**
- First connection: Run `make ping` to accept host key
- Host key changed: `ssh-keygen -R <host-ip>` then `make ping`

**See:** [docs/SSH_SETUP.md#troubleshooting](docs/SSH_SETUP.md#troubleshooting) for complete troubleshooting guide.

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
# SSH agent forwarding (uses 1Password SSH agent)
ansible_ssh_common_args: >-
  -o IdentityAgent={{ lookup('env', 'SSH_AUTH_SOCK') }}
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile={{ playbook_dir }}/../.ssh/known_hosts
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

Install with: `make install` (or `make setup` - backward-compatible alias)

## Linting

Configured tools:
- **yamllint** - YAML syntax validation
- **ansible-lint** - Ansible best practices
- **yamlfmt** - YAML formatting
- **shfmt** - Shell script formatting
- **EditorConfig** - Editor consistency

Run via `make check` (or `make lint` - backward-compatible alias) for linting, `make format` for auto-formatting
