# Homelab Infrastructure

Infrastructure as Code for managing containerized services on a Debian VM in Proxmox.

## Stack

- **Hypervisor**: Proxmox
- **Host**: Debian VM
- **Container Runtime**: Docker + Docker Compose (standalone)
- **Reverse Proxy**: Traefik v3 with Cloudflare DNS challenge for SSL
- **Authentication**: None by default; Traefik is internal-only behind router firewall/VPN
- **Security**: Docker Socket Proxy (restricted API access), network isolation
- **Configuration Management**: Ansible with Molecule testing

## Prerequisites

### Option 1: DevContainer (Recommended)
- **VS Code** with "Dev Containers" extension
- **Docker Desktop** running
- **1Password SSH agent** enabled (for SSH authentication)

All tools are pre-installed in the container. Just open in VS Code and select "Reopen in Container".

**SSH Authentication:** The DevContainer uses SSH agent forwarding with 1Password. No SSH keys need to be copied into the container - your 1Password SSH agent handles authentication automatically.

### Option 2: Local Setup
- **Local machine**: uv, shfmt, yamlfmt (optional)
- **Debian VM**: SSH access configured
- **1Password SSH agent**: Enabled for SSH authentication
- **Cloudflare**: Domain and API token for DNS challenges
- **Network**: Port forwarding for 80/443 to VM (if accessing externally)

## Quick Start

### 1. Setup Local Environment

```bash
make install  # Install Python deps + Ansible collections
```

### 2. Configure SSH Access

The infrastructure uses **SSH agent forwarding with 1Password** for secure authentication:

**Enable 1Password SSH agent** (one-time setup on macOS):
1. Open 1Password → Settings → Developer
2. Enable "Use the SSH agent"
3. Add SSH keys to 1Password vault (syncs across your Macs)

**Verify SSH agent works in DevContainer:**
```bash
echo $SSH_AUTH_SOCK  # Should show forwarded agent socket
ssh-add -l           # Lists keys from 1Password
```

See [docs/SSH_SETUP.md](docs/SSH_SETUP.md) for complete SSH configuration guide.

### 3. Configure Inventory

Create your inventory file from the example:

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

Edit `inventory/hosts.yml` with your VM's IP address and SSH user:

```yaml
ansible_host: 10.0.0.100  # Your VM's IP
ansible_user: admin       # Your SSH user
# SSH agent forwarding config (uses 1Password SSH agent)
ansible_ssh_common_args: >-
  -o IdentityAgent={{ lookup('env', 'SSH_AUTH_SOCK') }}
  -o IdentitiesOnly=yes
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile={{ playbook_dir }}/../.ssh/known_hosts
```

### 4. Verify SSH Connectivity

Test that you can reach the VM and accept its SSH host key:

```bash
make ssh-check
```

**First-time connection:** You'll be prompted to accept the VM's SSH fingerprint. Type `yes` to accept. The host key is saved to `.ssh/known_hosts` (gitignored) and all future connections verify against it for security.

**Troubleshooting:** See [docs/SSH_SETUP.md](docs/SSH_SETUP.md#troubleshooting) for common SSH issues.

### 5. Install Docker on VM

```bash
make docker-install
```

### 6. Deploy Docker Socket Proxy

For security, deploy the socket proxy first:

```bash
make docker-deploy stack=docker-socket-proxy
```

### 7. Configure Traefik

SSH to the VM and create `/opt/stacks/traefik/.env`:

```bash
ssh admin@YOUR_VM_IP  # Replace with your VM's IP or hostname
sudo mkdir -p /opt/stacks/traefik
sudo nano /opt/stacks/traefik/.env
```

Add:
```bash
# Cloudflare DNS Challenge
CF_DNS_API_TOKEN=your_cloudflare_dns_api_token
CF_API_EMAIL=your_email@example.com
DOMAIN=your-domain.com
TZ=America/Phoenix
```

Traefik now operates entirely inside the homelab network; no OAuth secrets are required. See [stacks/traefik/README.md](stacks/traefik/README.md) for details and [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md) for the historical Zitadel-based design.

### 8. Deploy Traefik

```bash
make docker-deploy stack=traefik
```

### 9. Configure DNS & Port Forwarding

**DNS (Cloudflare):**
- Create A record: `*.yourdomain.com` → Your public IP
- Create A record: `yourdomain.com` → Your public IP

**Port Forwarding (Router/Firewall):**
- Forward port 80 (HTTP) → YOUR_VM_IP:80
- Forward port 443 (HTTPS) → YOUR_VM_IP:443

**Access Traefik Dashboard:**
- External: `https://traefik.yourdomain.com` (requires authentication)
- Login page: `https://login.yourdomain.com`

All services are protected by authentication. See [docs/AUTHENTICATION.md](docs/AUTHENTICATION.md) for the complete authentication architecture.

## Automated Bootstrap (NEW)

For fresh deployments, use the orchestrated bootstrap instead of manual steps:

```bash
# Clean any existing deployment
make docker-destroy-all   # Type "destroy" to confirm

# Run orchestrated bootstrap (3 stages: foundation, services, health)
make docker-bootstrap

# Verify infrastructure health
make docker-health
```

**What Bootstrap Does:**
1. **Foundation Stage** - Ensure core Docker networks exist and `docker-socket-proxy` is running
2. **Services Stage** - Sync stacks and deploy Traefik plus application services
3. **Health Check Stage** - Run a generic health check playbook over containers and networks

**Bootstrap Benefits:**
- ✅ Automated OAuth application creation via Zitadel API
- ✅ Dynamic credential injection into .env files
- ✅ Proper deployment order with health checks
- ✅ Single command replaces 8-step manual process

## Manual Deployment (Legacy)

If you prefer manual control:

```bash
make docker-deploy-all
```

Then check health:

```bash
make docker-health
```

## Structure

```
infrastructure/
├── inventory/
│   ├── hosts.yml.example            # Inventory template (copy to hosts.yml)
│   └── hosts.yml                    # Your inventory (gitignored)
├── playbooks/
│   ├── docker-install.yml           # Install Docker using geerlingguy.docker
│   └── deploy-stack.yml             # Deploy compose stacks to VM
├── stacks/                          # Docker compose stacks
│   ├── docker-socket-proxy/         # Secure Docker API proxy
│   └── traefik/                     # Reverse proxy + SSL
├── scripts/                         # Utility scripts
├── .ansible-lint                    # Ansible linting config
├── .yamllint                        # YAML linting config
├── .yamlfmt                         # YAML formatting config
├── .editorconfig                    # Editor config
├── ansible.cfg                      # Ansible config
├── pyproject.toml                   # Python dependencies (uv)
├── requirements.yml                 # Ansible collections
├── Makefile                         # Task automation
└── README.md                        # This file
```

## Adding Services

Create a new directory in `stacks/`:

```bash
make docker-install
```

Create `docker-compose.yml` with Traefik labels:

```yaml
services:
  my-app:
    image: my-image:latest
    container_name: my-app
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.${DOMAIN}`)"
      - "traefik.http.routers.my-app.entrypoints=https"
      - "traefik.http.routers.my-app.tls.certresolver=cloudflare"
      - "traefik.http.services.my-app.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
```

Deploy:

```bash
make docker-deploy stack=my-service
```

## Common Commands

```bash
# Standard operations
make install       # Install dependencies
make check         # Run linting
make test          # Run full test suite

# SSH connectivity
make ssh-check     # Test VM connectivity
make ssh-setup     # First-time SSH setup wizard

# Docker operations
make docker-deploy stack=traefik       # Deploy single stack
make docker-deploy-all                 # Deploy all stacks
make docker-bootstrap                  # Bootstrap infrastructure
make docker-health                     # Check infrastructure health

# Development
make dev-format    # Auto-format YAML and shell scripts
make dev-clean     # Remove temporary files

# Run ad-hoc Ansible commands
uv run ansible homelab -a "docker ps"
uv run ansible homelab -a "df -h"
```

## Development

### Testing

The project uses a comprehensive test suite including Molecule for infrastructure testing:

```bash
make test          # Run full test suite (linting + Molecule + quality checks)
make test-quick    # Fast tests only (<5s: pytest + linting)
make test-molecule # Molecule integration tests with authentication verification
make test-quality  # IaC quality analysis on analyze_iac.py
```

**Molecule Testing**: Infrastructure changes are validated locally in Docker containers before deploying to production. Tests verify complete deployment, service health, authentication flow, and network isolation.

See [docs/TESTING.md](docs/TESTING.md) for Molecule workflow and [docs/TEST_STRATEGY.md](docs/TEST_STRATEGY.md) for overall testing strategy.

### Linting & Formatting

```bash
make check       # Check YAML, Ansible, shell scripts
make dev-format  # Auto-format YAML and shell scripts
```

### Tools Used

- **yamllint**: YAML linting
- **ansible-lint**: Ansible best practices
- **yamlfmt**: YAML formatting (install: `brew install yamlfmt`)
- **shfmt**: Shell script formatting (install: `brew install shfmt`)
- **ruff**: Python linting/formatting (dev-dependency)
- **pytest**: Python unit testing framework
- **Molecule**: Ansible integration testing with Docker

## Key Documentation

- **[docs/AUTHENTICATION.md](docs/AUTHENTICATION.md)** - Complete authentication architecture and flow
- **[docs/TESTING.md](docs/TESTING.md)** - Molecule testing workflow for local validation
- **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** - Detailed setup instructions
- **[docs/STANDARDS.md](docs/STANDARDS.md)** - Infrastructure coding standards

## Architecture Notes

- **Authentication**: None by default; access is limited to the internal homelab network (or VPN/tunnel)
- **Network Isolation**: Databases and internal services run on non-public Docker networks
- **Single Entry Point**: Traefik terminates TLS for internal clients; router ports 80/443 no longer need to be forwarded from the internet
- **Stacks Location**: Deploy to `/opt/stacks/<stack-name>/` on the VM
- **Environment Files**: `.env` files NOT synced - create on VM manually via SSH
- **Security**: Docker socket access proxied through docker-socket-proxy for restricted API access
- **Testing**: Molecule validates playbooks locally before remote deployment
