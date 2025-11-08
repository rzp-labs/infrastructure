# Homelab Infrastructure

Infrastructure as Code for managing containerized services on a Debian VM in Proxmox.

## Stack

- **Hypervisor**: Proxmox
- **Host**: Debian VM
- **Container Runtime**: Docker + Docker Compose (standalone)
- **Reverse Proxy**: Traefik v3 with Cloudflare DNS challenge for SSL
- **Security**: Docker Socket Proxy (restricted API access)
- **Configuration Management**: Ansible

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
make setup  # Install Python deps + Ansible collections
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
make ping
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
CF_DNS_API_TOKEN=your_cloudflare_dns_api_token
CF_API_EMAIL=your_email@example.com
DOMAIN=your-domain.com
TZ=America/Phoenix
```

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
- Local: `http://YOUR_VM_IP:8080/dashboard/`
- External: `https://traefik.yourdomain.com`

## Automated Bootstrap (NEW)

For fresh deployments, use the orchestrated bootstrap instead of manual steps:

```bash
# Clean any existing deployment
make docker-destroy-all   # Type "destroy" to confirm

# Run orchestrated bootstrap (4 stages: foundation, OAuth, proxy, services)
make docker-bootstrap

# Verify infrastructure health
make docker-check-health
```

**What Bootstrap Does:**
1. **Foundation Stage** - Deploy socket proxy, database, and Zitadel
2. **OAuth Setup** - Create Traefik OAuth app in Zitadel automatically
3. **Proxy Layer** - Deploy Traefik with valid OAuth credentials
4. **Services** - Deploy remaining services (dockge, zitadel-login)

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
make docker-check-health
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
make docker-deploy stack=traefik
make docker-deploy stack=my-service

# Lint & format
make lint
make format

# Test connectivity
make ping

# Install Docker on the VM
make docker-install

# Deploy a stack
make docker-deploy stack=traefik
make docker-deploy stack=my-service

# Run ad-hoc Ansible commands
uv run ansible homelab -a "docker ps"
uv run ansible homelab -a "df -h"
```

## Development

### Testing

The project uses a comprehensive test suite to ensure IaC quality and reliability:

```bash
make test          # Run full test suite (linting + Molecule + quality checks)
make test-quick    # Fast tests only (<5s: pytest + linting)
make test-molecule # Integration tests with idempotence verification
make test-quality  # IaC quality analysis on analyze_iac.py
```

**Test coverage**: 80% on critical Python scripts (analyze_iac.py), with a balanced test distribution optimized for IaC: 60% static analysis, 30% integration tests via Molecule, 10% end-to-end deployment validation.

See [docs/TEST_STRATEGY.md](docs/TEST_STRATEGY.md) and [tests/README.md](tests/README.md) for complete testing documentation.

### Linting & Formatting

```bash
make check   # Check YAML, Ansible, shell scripts (or use 'make lint')
make format  # Auto-format YAML and shell scripts
```

### Tools Used

- **yamllint**: YAML linting
- **ansible-lint**: Ansible best practices
- **yamlfmt**: YAML formatting (install: `brew install yamlfmt`)
- **shfmt**: Shell script formatting (install: `brew install shfmt`)
- **ruff**: Python linting/formatting (dev-dependency)
- **pytest**: Python unit testing framework
- **Molecule**: Ansible integration testing with Docker

## Notes

- Stacks deploy to `/opt/stacks/<stack-name>/` on the VM
- `.env` files are NOT synced - create them on the VM manually via SSH
- The `proxy` network is created automatically when deploying Traefik
- Use `.env.example` files to document required variables for each stack
- Docker socket access is proxied through `docker-socket-proxy` for security
- Traefik dashboard is accessible on port 8080 (local) or via domain (SSL)
