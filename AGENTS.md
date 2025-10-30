# AI Assistant Guidance

This file provides guidance to AI assistants when working with code in this repository.

## Project Overview

**Infrastructure** is a homelab Infrastructure-as-Code project that manages containerized services on a Debian VM using Ansible and Docker Compose. It follows security-first design principles with a root orchestrator pattern.

**Key capabilities**:
- Ansible-based configuration management and deployment
- Docker Compose stack orchestration with root orchestrator pattern
- Traefik reverse proxy with automatic SSL via Cloudflare DNS
- Docker Socket Proxy for secure Docker API access
- Python utilities for AI context generation and transcript building

**Philosophy**: This project follows ruthless simplicity and infrastructure-as-code best practices. It's a standalone git submodule developed using the Amplifier workspace pattern.

## Important: This is a Git Submodule

Infrastructure is a **standalone project** that lives as a git submodule within the Amplifier workspace. This means:

- **Independent version control** - Has its own git repository and history
- **Own dependencies** - Has its own `pyproject.toml` managed with `uv`
- **Own virtual environment** - Uses local `.venv-container/` (NOT parent workspace's `.venv`)
- **Clean separation** - No code imports from Amplifier (only follows its patterns)

### Virtual Environment Isolation

**CRITICAL**: Always run commands from the infrastructure directory itself, not from the parent workspace:

```bash
cd infrastructure
make setup
make deploy stack=traefik
```

## Build/Test/Lint Commands

**Prerequisites**: `uv` for Python, `yamlfmt` and `shfmt` for formatting

### Setup
```bash
make setup          # Install Python deps + Ansible collections
```

### Code Quality
```bash
make lint           # Run yamllint + ansible-lint + shell/yaml linting
make format         # Auto-format YAML and shell scripts
```

### Deployment
```bash
make ping                          # Test SSH connectivity to VM
make install-docker                # Install Docker on the VM (first time)
make deploy stack=<stack-name>     # Deploy single stack
make deploy-all                    # Deploy all stacks via root orchestrator
make check-deploy                  # Validate deployment configuration
```

### Ad-hoc Commands
```bash
uv run ansible homelab -m ping                    # Ping VM
uv run ansible homelab -a "docker ps"             # List containers
uv run ansible homelab -a "docker logs traefik"   # View logs
```

## Code Style Guidelines

### YAML
- **Indentation**: 2 spaces
- **Line length**: 120 characters (yamlfmt default)
- **Quotes**: Prefer double quotes for strings
- **Linting**: yamllint + ansible-lint
- **Formatting**: yamlfmt (auto-formats on `make format`)

### Shell Scripts
- **Indentation**: 2 spaces
- **Style**: Simplified, compact, space redirects (`-i 2 -ci -sr`)
- **Formatting**: shfmt (auto-formats on `make format`)

### Python
- **Python version**: 3.12+
- **Type hints**: Not currently required (tool scripts, not library code)
- **Linting**: ruff (configured in pyproject.toml)
- **Line length**: 120 characters

### Ansible
- **Best practices**: Enforced by ansible-lint
- **Idempotency**: All playbooks must be idempotent (safe to run multiple times)
- **Task naming**: Clear, descriptive task names
- **Privilege escalation**: Configured globally in ansible.cfg

## Project Structure

```
infrastructure/
├── inventory/
│   ├── hosts.yml.example          # Template for VM configuration
│   └── hosts.yml                  # Your inventory (gitignored)
├── playbooks/
│   ├── install-docker.yml         # Install Docker on VM
│   ├── deploy-stack.yml           # Deploy single stack
│   └── deploy-all-stacks.yml      # Deploy all stacks sequentially
├── stacks/                        # Docker Compose stacks
│   ├── docker-compose.yml         # Root orchestrator (include pattern)
│   ├── docker-socket-proxy/       # Security proxy for Docker API
│   │   └── docker-compose.yml
│   ├── traefik/                   # Reverse proxy + SSL
│   │   ├── docker-compose.yml
│   │   ├── traefik.yml            # Traefik static config
│   │   └── .env.example           # Environment template
│   └── README.md                  # Stack documentation
├── tools/                         # Python utilities
│   ├── build_ai_context_files.py
│   ├── claude_transcript_builder.py
│   └── README.md
├── scripts/                       # Shell scripts
├── .claude/                       # Claude Code tools and hooks
├── .devcontainer/                 # DevContainer configuration
├── ansible.cfg                    # Ansible configuration
├── requirements.yml               # Ansible collections and roles
├── pyproject.toml                 # Python dependencies (uv)
├── Makefile                       # Task automation
├── AGENTS.md                      # This file
├── CLAUDE.md                      # Claude Code guidance
└── README.md                      # Project documentation
```

## Architecture Overview

### Technology Stack
- **Hypervisor**: Proxmox
- **Host**: Debian VM
- **Container Runtime**: Docker + Docker Compose (standalone)
- **Reverse Proxy**: Traefik v3 with Cloudflare DNS challenge
- **Security**: Docker Socket Proxy (restricted API access)
- **Configuration Management**: Ansible

### Root Orchestrator Pattern

The `stacks/docker-compose.yml` uses Docker Compose's `include` feature:

- **Shared resources** (networks) defined at root level
- **Individual stacks** included but can be deployed independently
- **Deployment flexibility**: Can deploy all at once or individually

```yaml
# Root orchestrator
include:
  - docker-socket-proxy/docker-compose.yml
  - traefik/docker-compose.yml

networks:
  proxy:
    name: proxy
    driver: bridge
```

Individual stacks reference the shared network:

```yaml
# Individual stack
services:
  my-service:
    image: my-image:latest
    networks:
      - proxy

networks:
  proxy:
    external: true  # References root-level network
```

### Security Architecture

**Docker Socket Proxy Pattern**:
- Services NEVER access Docker socket directly (`/var/run/docker.sock`)
- All Docker API requests go through `docker-socket-proxy`
- Proxy has restricted permissions (read-only for containers/networks/services)
- Dangerous operations blocked (POST=0, BUILD=0, EXEC=0, COMMIT=0)

**Traefik Integration**:
- Connects via TCP: `tcp://docker-socket-proxy:2375`
- Automatic SSL via Let's Encrypt + Cloudflare DNS challenge
- Services register via Docker labels (dynamic configuration)

### Deployment Flow

1. **Sync files**: Ansible copies `stacks/` to `/opt/stacks/` on VM using rsync
2. **Exclude secrets**: `.env` files are NOT synced (must be created manually on VM)
3. **Deploy**: Docker Compose runs on the VM to start services
4. **Pull images**: Always pulls latest (`pull: always`)

## Development Workflow

### Initial Setup

1. **Copy inventory template**:
   ```bash
   cp inventory/hosts.yml.example inventory/hosts.yml
   ```

2. **Edit inventory** with your VM's IP and SSH user:
   ```yaml
   ansible_host: 10.0.0.100  # Your VM's IP
   ansible_user: admin       # Your SSH user
   ```

3. **Install dependencies**:
   ```bash
   make setup
   ```

4. **Test connectivity**:
   ```bash
   make ping
   ```

### Adding New Services

1. **Create stack directory**:
   ```bash
   mkdir -p stacks/my-service
   ```

2. **Create `docker-compose.yml`** with Traefik labels:
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

3. **Create `.env.example`** if environment variables needed

4. **Deploy**:
   ```bash
   make deploy stack=my-service
   ```

5. **(Optional)** Add to root orchestrator for centralized deployment

### Linting and Formatting

Run before committing:

```bash
make lint      # Check code quality
make format    # Auto-fix formatting issues
```

Configured tools:
- **yamllint**: YAML syntax validation (`.yamllint`)
- **ansible-lint**: Ansible best practices (`.ansible-lint`)
- **yamlfmt**: YAML formatting (`.yamlfmt`)
- **shfmt**: Shell script formatting (via `make format`)

## Common Tasks

### Deploy Infrastructure (First Time)

```bash
# 1. Setup local environment
make setup

# 2. Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
# Edit hosts.yml with your VM's IP

# 3. Test connectivity
make ping

# 4. Install Docker on VM
make install-docker

# 5. Deploy Docker Socket Proxy (security layer)
make deploy stack=docker-socket-proxy

# 6. SSH to VM and create Traefik .env
ssh admin@YOUR_VM_IP
sudo mkdir -p /opt/stacks/traefik
sudo nano /opt/stacks/traefik/.env
# Add: CF_DNS_API_TOKEN, CF_API_EMAIL, DOMAIN, TZ

# 7. Deploy Traefik
make deploy stack=traefik

# 8. Configure DNS and port forwarding (see README.md)
```

### Deploy New Stack

```bash
# Option 1: Deploy single stack
make deploy stack=my-service

# Option 2: Deploy all stacks
make deploy-all

# Option 3: Deploy multiple specific stacks
make deploy stack="traefik my-service another-service"
```

### Troubleshooting Deployment

```bash
# Check syntax
make check-deploy

# Test connectivity
make ping

# View container logs
uv run ansible homelab -a "docker logs traefik"

# Check running containers
uv run ansible homelab -a "docker ps"

# Manually connect and inspect
ssh admin@YOUR_VM_IP
cd /opt/stacks
docker compose ps
docker compose logs
```

## Configuration Management

### Environment Variables

**LINEAR_API_KEY** is NOT used by this project (infrastructure management, not Linear integration).

**Ansible Configuration** (`ansible.cfg`):
- Inventory: `inventory/hosts.yml`
- Privilege escalation: Enabled (uses sudo)
- Python interpreter: Auto-detected
- Host key checking: Enabled for security

**Docker Stack Configuration**:
- Each stack can have its own `.env` file at `/opt/stacks/<stack-name>/.env`
- `.env` files are NOT synced from local machine (must be created on VM via SSH)
- Always provide `.env.example` templates in stack directories

### Ansible Collections

Required collections (defined in `requirements.yml`):
- `community.docker`: Docker module support
- `ansible.posix`: Synchronize module for rsync
- `geerlingguy.docker`: Docker installation role

Install with: `make setup` (or `uv run ansible-galaxy collection install -r requirements.yml`)

## DevContainer

The `.devcontainer/` provides a complete development environment:

- Python 3.12 base image
- Docker-outside-of-Docker (uses host Docker)
- SSH keys mounted read-only from `~/.ssh/`
- 1Password SSH agent support
- All tools pre-installed (uv, yamlfmt, shfmt, ansible)
- Pre-configured VS Code extensions (Ansible, YAML, Python)

The `setup.sh` post-create script runs `make setup` automatically.

## Important Behaviors

### Idempotency
- All playbooks are idempotent (safe to run multiple times)
- Docker Compose uses declarative state
- Always pulls latest images (`pull: always`)

### Security
- `.env` files are gitignored (never commit secrets)
- Docker socket access proxied through restricted API
- SSH host key verification enabled by default
- Traefik handles SSL automatically via Let's Encrypt

### File Syncing
- Ansible uses rsync to sync `stacks/` to VM
- `.env` files are explicitly excluded from sync
- Individual stack deployment syncs only that stack's files
- Full deployment syncs all stacks

## Testing Instructions

### Connectivity Testing
```bash
make ping  # Tests SSH connection and Ansible setup
```

### Deployment Validation
```bash
make check-deploy  # Syntax check + lint + dry-run
```

### Manual Testing
```bash
# After deployment, verify services are running
uv run ansible homelab -a "docker ps"

# Check Traefik dashboard
# Local: http://YOUR_VM_IP:8080/dashboard/
# External: https://traefik.yourdomain.com

# Test service accessibility
curl -I https://traefik.yourdomain.com
```

## Philosophy Alignment

### Ruthless Simplicity

- **Ansible for orchestration** - Clear, readable playbooks
- **Docker Compose for containers** - Declarative service definitions
- **Root orchestrator pattern** - Centralized coordination with individual flexibility
- **Direct API integration** - Ansible modules used as intended
- **Minimal abstractions** - No unnecessary wrapper scripts

### Infrastructure as Code

- **Version controlled** - All configuration in git
- **Idempotent** - Safe to run repeatedly
- **Documented** - Clear README and inline comments
- **Testable** - Validation commands before deployment
- **Secure by default** - Docker Socket Proxy pattern

### Modular Design

- **Independent stacks** - Each service in own directory
- **Shared resources** - Common networks at root level
- **Deployment flexibility** - Individual or all-at-once
- **Clear contracts** - Docker networks and Traefik labels define interfaces

## Related Documentation

- **[README.md](README.md)** - Project overview and setup guide
- **[CLAUDE.md](CLAUDE.md)** - Claude Code specific guidance
- **[stacks/README.md](stacks/README.md)** - Docker stack documentation
- **[tools/README.md](tools/README.md)** - Python utilities documentation

## License

MIT License - See [LICENSE](LICENSE)

---

**Parent workspace**: This project is developed using the [Amplifier](https://github.com/microsoft/amplifier) workspace pattern. See parent workspace `AGENTS.md` and `CLAUDE.md` for broader context on development philosophy and patterns.
