# AI Assistant Guidance

This file provides guidance to AI assistants when working with code in this repository.

**For general Amplifier workspace guidance, see `@../AGENTS.md` and `@../CLAUDE.md`.**

## Project Overview

**Infrastructure** is a homelab Infrastructure-as-Code project that manages containerized services on a Debian VM using Ansible and Docker Compose. It follows security-first design principles with a root orchestrator pattern.

**Key capabilities**:
- Ansible-based configuration management and deployment
- Docker Compose stack orchestration with root orchestrator pattern
- Traefik reverse proxy with automatic SSL via Cloudflare DNS
- Docker Socket Proxy for secure Docker API access

**Philosophy**: This project follows ruthless simplicity and infrastructure-as-code best practices. It's a standalone git submodule developed using the Amplifier workspace pattern.

## Important: This is a Git Submodule

Infrastructure is a **standalone project** that lives as a git submodule within the Amplifier workspace. This means:

- **Independent version control** - Has its own git repository and history
- **Own dependencies** - Has its own `pyproject.toml` managed with `uv`
- **Own virtual environment** - Uses local `.venv/` (NOT parent workspace's `.venv`)
- **Clean separation** - No code imports from Amplifier (only follows its patterns)
- **Development environment** - Uses parent workspace's DevContainer configuration

### Virtual Environment Isolation

**CRITICAL**: Always run commands from the infrastructure directory itself, not from the parent workspace.

```bash
cd infrastructure
make setup
make docker-deploy stack=traefik
```

## Build/Test/Lint Commands

**Prerequisites**: `uv` for Python, `yamlfmt` and `shfmt` for formatting (provided by parent DevContainer)

**Pure Delegation Architecture**: Infrastructure follows workspace-wide standard Makefile targets (install, check, test) with backward-compatible aliases (setup, lint).

```bash
# Standard targets (Pure Delegation pattern)
make install        # Install Python deps + Ansible collections
make check          # Run yamllint + ansible-lint
make test           # Validate Ansible playbooks and configuration

# Backward-compatible aliases
make setup          # Alias for install
make lint           # Alias for check
```

**Add dependencies**:
```bash
cd infrastructure  # Must be in submodule directory
uv add <package>           # Production dependency
uv add --dev <package>     # Development dependency
```

### Installation
```bash
make install        # Install Python deps + Ansible collections (or use 'make setup')
```

### Code Quality
```bash
make check          # Run yamllint + ansible-lint (or use 'make lint')
make format         # Auto-format YAML and shell scripts
```

### Testing
```bash
make test           # Validate Ansible playbooks and configuration
```

### Deployment
```bash
make ping                          # Test SSH connectivity to VM
make docker-deploy stack=<stack-name>     # Deploy single stack
make check-deploy                  # Validate deployment configuration
```

### Ad-hoc Commands
```bash
uv run ansible homelab -m ping                    # Ping VM
uv run ansible homelab -a "docker ps"             # List containers
uv run ansible homelab -a "docker logs traefik"   # View logs
```

## Code Style Guidelines

- **Line length**: 120 characters (configured across all tools)
- **Python version**: 3.12+ required
- **Type hints**: Not currently required (tool scripts, not library code)
- **Idempotency**: All Ansible playbooks must be idempotent (safe to run multiple times)
- **Task naming**: Clear, descriptive task names for Ansible playbooks
- **Error handling**: Comprehensive logging for debugging deployment issues

## Formatting Guidelines

- **Tool**: Multiple formatters for different file types
- **YAML**: yamlfmt (2-space indentation, 120-char lines)
- **Shell scripts**: shfmt (2-space indentation, `-i 2 -ci -sr` style)
- **Ansible**: ansible-lint (best practices enforcement)
- **Line endings**: LF (Unix style)
- **EOF**: All files must end with newline

## Configuration Files

**pyproject.toml** - Single source of truth for:
- Python dependencies (managed by `uv`)
- Ruff configuration
- Project metadata

**ansible.cfg** - Ansible configuration:
- Inventory location
- Privilege escalation settings
- Python interpreter discovery
- Host key checking

**requirements.yml** - Ansible collections and roles:
- community.docker
- ansible.posix
- geerlingguy.docker

**Makefile** - Standard commands that reference configuration files

**Never duplicate configuration** - Read from authoritative files when needed.

## File Structure

```
infrastructure/
├── inventory/
│   ├── hosts.yml.example          # Template for VM configuration
│   └── hosts.yml                  # Your inventory (gitignored)
├── playbooks/
│   ├── docker-install.yml         # Install Docker on VM
│   ├── deploy-stack.yml           # Deploy single stack
│   └── docker-deploy-all.yml      # Deploy all stacks sequentially
├── stacks/                        # Docker Compose stacks
│   ├── docker-compose.yml         # Root orchestrator (include pattern)
│   ├── docker-socket-proxy/       # Security proxy for Docker API
│   │   └── docker-compose.yml
│   ├── traefik/                   # Reverse proxy + SSL
│   │   ├── docker-compose.yml
│   │   ├── traefik.yml            # Traefik static config
│   │   └── .env.example           # Environment template
│   └── README.md                  # Stack documentation
├── scripts/                       # Shell scripts (if any)
├── ansible.cfg                    # Ansible configuration
├── requirements.yml               # Ansible collections and roles
├── pyproject.toml                 # Python dependencies (uv)
├── uv.lock                        # Dependency lock file
├── Makefile                       # Task automation
├── AGENTS.md                      # This file (project-specific guidance)
├── CLAUDE.md                      # Claude Code guidance (references parent)
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
    external: false
```

### Deployment Flow

1. **Rsync files** from local `stacks/` to `/opt/stacks/` on VM (`.env` excluded)
2. **Docker Compose** runs on remote VM to deploy services
3. **Images pulled** (`pull: always`) to ensure latest versions

**Important**: Deployment happens ON the VM, Ansible orchestrates.

### Security Architecture

**Docker Socket Proxy Pattern**:
- Services NEVER access Docker socket directly
- All Docker API requests go through socket proxy
- Restricted permissions (read-only for containers/networks/services/tasks)
- Dangerous operations blocked (POST=0, BUILD=0, EXEC=0, COMMIT=0)

**Traefik**: Connects via `tcp://docker-socket-proxy:2375` not `unix:///var/run/docker.sock`

### Network Architecture

**Shared Proxy Network**:
```bash
docker network create proxy  # Created by root orchestrator
```

- Referenced by stacks: `networks: proxy: external: true`
- All Traefik-routed services join this network
- Persists even if root orchestrator is down

### Traefik Configuration

- **Static config**: `stacks/traefik/traefik.yml`
- **Dynamic config**: Docker labels on service containers
- **Environment variables**: `stacks/traefik/.env` (gitignored)

**Service Registration Pattern**:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`app.${DOMAIN}`)"
  - "traefik.http.routers.app.entrypoints=https"
  - "traefik.http.routers.app.tls.certresolver=cloudflare"
```

SSL certificates automatically obtained via Let's Encrypt using Cloudflare DNS challenge.

## Adding New Services

1. Create `stacks/my-service/docker-compose.yml`
2. Join proxy network and add Traefik labels
3. Create `.env.example` template
4. Deploy: `make docker-deploy stack=my-service`
5. Optionally add to root orchestrator's `include` list

## Configuration Management

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

### Ansible Configuration

- **Inventory**: `inventory/hosts.yml`
- **Privilege escalation**: Automatically uses sudo
- **Python interpreter**: Auto-detected (`auto_silent`)
- **Host key checking**: Enabled (for security against MITM attacks)

## Important Behaviors

**Idempotency**:
- Playbooks can be run multiple times safely
- Docker Compose uses declarative state (`state: present`)
- Always pulls latest images (`pull: always`)

**Traefik Specifics**:
- `acme.json` automatically created with mode `0600` (required by Let's Encrypt)
- Dashboard accessible at `http://VM_IP:8080/dashboard/` or `https://traefik.domain.com`
- Requires Cloudflare API token in `.env` for DNS challenge

## Development Workflow

**Working in this project**:
1. Ensure you're in the infrastructure directory
2. Reference parent guidance with `@../AGENTS.md` and `@../CLAUDE.md`
3. Use local virtual environment (created by `make setup`)
4. Follow IaC best practices: idempotency, declarative state, version control

**Testing deployments**:
1. Test connectivity: `make ping`
2. Deploy to staging/test environment first
3. Validate with `make check-deploy`
4. Monitor logs after deployment

## Git Workflow

Since this is a submodule:
- **Commits stay in this directory** - Independent git history
- **Parent workspace tracks submodule version** - Via git submodule pointer
- **Update parent after infrastructure changes**: `cd .. && git add infrastructure && git commit -m "Update infrastructure submodule"`

See the parent workspace's `docs/WORKSPACE_PATTERN.md` for complete guidance on working with submodules in the Amplifier workspace pattern.

## Philosophy Alignment

### Ruthless Simplicity

- **Declarative over imperative** - Use Ansible's declarative state management
- **Idempotent playbooks** - Safe to run repeatedly without side effects
- **Minimal dependencies** - Only essential Ansible collections
- **Direct integration** - Ansible modules used as intended
- **Security-first** - Docker Socket Proxy prevents direct socket access

### Infrastructure as Code Best Practices

- **Version control everything** - All configurations tracked in git
- **Immutable deployments** - Always pull latest images (`pull: always`)
- **Configuration separation** - `.env` files never committed
- **Root orchestrator pattern** - Shared resources, independent stacks
- **Clear documentation** - Architecture patterns explicitly documented

## Related Documentation

- **[README.md](README.md)** - Project overview and quick start
- **[CLAUDE.md](CLAUDE.md)** - Claude Code specific guidance
- **[stacks/README.md](stacks/README.md)** - Stack documentation and patterns
- **Parent workspace**: This project is developed using the [Amplifier](https://github.com/microsoft/amplifier) workspace pattern. See parent workspace `AGENTS.md` and `CLAUDE.md` for broader context on development philosophy and patterns.
