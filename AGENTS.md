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
make install
make docker-deploy stack=traefik
```

## Build/Test/Lint Commands

**Prerequisites**: `uv` for Python, `yamlfmt` and `shfmt` for formatting (provided by parent DevContainer)

**Pure Delegation Architecture**: Infrastructure follows workspace-wide standard Makefile targets with namespace organization.

```bash
# Standard targets (Pure Delegation pattern)
make install        # Install Python deps + Ansible collections
make check          # Run yamllint + ansible-lint
make test           # Validate Ansible playbooks and configuration
```

**Add dependencies**:
```bash
cd infrastructure  # Must be in submodule directory
uv add <package>           # Production dependency
uv add --dev <package>     # Development dependency
```

### Installation
```bash
make install        # Install Python deps + Ansible collections
```

### Code Quality
```bash
make check          # Run yamllint + ansible-lint
make dev-format     # Auto-format YAML and shell scripts
```

### Testing
```bash
make test           # Run full test suite (linting + Molecule + quality analysis)
make test-quick     # Fast tests only (<5s: pytest unit tests + linting)
make test-molecule  # Integration tests with idempotence verification
make test-quality   # IaC quality analysis (analyze_iac.py coverage)
make test-coverage  # Generate pytest coverage report
make report         # Generate quality reports (JSON + Markdown)
```

**Test Philosophy**: IaC-adapted test pyramid with 60% static analysis, 30% integration (Molecule), 10% end-to-end validation. Focus on 80% coverage for critical Python tooling (analyze_iac.py).

See [tests/README.md](tests/README.md) for comprehensive testing guide.

### Deployment
```bash
make ssh-check                             # Test SSH connectivity to VM
make docker-deploy stack=<stack-name>      # Deploy single stack
make docker-deploy-all                     # Deploy all stacks
make docker-bootstrap                      # Bootstrap infrastructure
make docker-health                         # Check infrastructure health
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

## SSH Configuration for Ansible

### SSH Agent Forwarding Architecture

The infrastructure uses **SSH agent forwarding with 1Password** for secure Ansible authentication:

```
1Password SSH Agent (macOS Host)
    ↓ SSH_AUTH_SOCK forwarded by VSCode DevContainer
DevContainer (Ansible)
    ↓ SSH connection using forwarded agent
Target Homelab Hosts
```

**Security Benefits:**
- **No private keys in containers** - Authentication via forwarded agent only
- **No private keys in repository** - Public repo safe, no secrets exposed
- **Works across multiple hosts** - Same config on office and home Macs
- **1Password native** - Keys sync across all your machines automatically

**How it works:**
1. DevContainer includes `ghcr.io/devcontainers/features/sshd:1` feature
2. VSCode automatically forwards `SSH_AUTH_SOCK` to container
3. Ansible uses forwarded agent via inventory configuration
4. 1Password provides keys without exposing private key material

### SSH Setup Process

**Prerequisites:**
1. **1Password SSH agent enabled** (Settings → Developer → Use SSH agent)
2. **SSH keys in 1Password** (automatically synced across Macs)
3. **DevContainer running** (SSH agent forwarding automatic)

**First-time setup:**
```bash
# 1. Verify SSH agent forwarding works
echo $SSH_AUTH_SOCK  # Should show /tmp/auth-agent.../listener.sock
ssh-add -l           # Lists keys from 1Password

# 2. Create inventory from template
cp inventory/hosts.yml.example inventory/hosts.yml

# 3. Edit inventory with your VM details and SSH config
# (See example configuration below)

# 4. Accept host keys on first connection
make ssh-check  # Type 'yes' when prompted
```

**Inventory configuration example:**
```yaml
---
all:
  children:
    homelab:
      hosts:
        debian-docker:
          ansible_host: 10.0.0.100
          ansible_user: admin
          ansible_python_interpreter: /usr/bin/python3
          # SSH agent forwarding with 1Password
          ansible_ssh_common_args: >-
            -o IdentityAgent={{ lookup('env', 'SSH_AUTH_SOCK') }}
            -o IdentitiesOnly=yes
            -o StrictHostKeyChecking=yes
            -o UserKnownHostsFile={{ playbook_dir }}/../.ssh/known_hosts
```

**Configuration explained:**
- `IdentityAgent=$SSH_AUTH_SOCK` - Use forwarded 1Password agent
- `IdentitiesOnly=yes` - Only try keys from agent (prevents exhaustion)
- `StrictHostKeyChecking=yes` - Verify host keys for MITM protection
- `UserKnownHostsFile=.ssh/known_hosts` - Workspace-local known hosts

### Known Hosts Management

SSH host keys are stored in `.ssh/known_hosts` (workspace-local, gitignored):

**On first connection:**
```bash
make ssh-check
# Prompts: "Are you sure you want to continue connecting (yes/no)?"
# Type: yes
# Result: Host key saved to .ssh/known_hosts
```

**Subsequent connections:**
- Automatically verify against saved host key
- Connection fails if host key changes (MITM protection)

**Regenerating known hosts:**
```bash
rm .ssh/known_hosts
make ssh-check  # Accept host keys again
```

**See:** [docs/SSH_SETUP.md](docs/SSH_SETUP.md) for complete SSH configuration guide.

### Troubleshooting SSH

**Common issues and solutions:**

**"Permission denied (publickey)":**
```bash
# Check SSH agent forwarding
echo $SSH_AUTH_SOCK  # Should be set
ssh-add -l           # Should list keys

# If empty: Enable 1Password SSH agent or restart DevContainer
```

**"Host key verification failed":**
```bash
# First connection: Run make ssh-check
make ssh-check

# Host key changed legitimately:
ssh-keygen -R 10.0.0.100
make ssh-check

# Host key changed unexpectedly: DO NOT PROCEED (possible MITM attack)
```

**"Too many authentication failures":**
```bash
# Solution: Add IdentitiesOnly=yes to inventory
# (Already in example configuration)
```

**Multi-host development:**

The same configuration works on multiple development machines (office + home):

1. **On first Mac**: Complete setup, commit inventory to git
2. **On second Mac**: Git pull, run `make ssh-check` to accept host keys
3. **Both Macs**: SSH connections work via 1Password agent

Each workspace maintains its own `.ssh/known_hosts` file (gitignored).

## Configuration Management

### Inventory

Create `inventory/hosts.yml` from template:
```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

Edit with your VM details (see SSH Configuration section above for complete example with SSH agent forwarding):
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
- **SSH authentication**: Via forwarded 1Password SSH agent

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
3. Use local virtual environment (created by `make install`)
4. Follow IaC best practices: idempotency, declarative state, version control

**Testing deployments**:
1. Test connectivity: `make ssh-check`
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
