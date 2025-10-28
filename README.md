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
- **SSH keys** configured at `~/.ssh/`

All tools are pre-installed in the container. Just open in VS Code and select "Reopen in Container".

### Option 2: Local Setup
- **Local machine**: uv, shfmt, yamlfmt (optional)
- **Debian VM**: SSH access configured
- **Cloudflare**: Domain and API token for DNS challenges
- **Network**: Port forwarding for 80/443 to VM (if accessing externally)

## Quick Start

### 1. Setup Local Environment

```bash
make setup  # Install Python deps + Ansible collections
```

### 2. Configure Inventory

Create your inventory file from the example:

```bash
cp inventory/hosts.yml.example inventory/hosts.yml
```

Edit `inventory/hosts.yml` with your VM's IP address and SSH user:

```yaml
ansible_host: 10.0.0.100  # Your VM's IP
ansible_user: admin       # Your SSH user
```

**Note for 1Password users**: If using 1Password SSH agent with multiple keys, uncomment and configure the `ansible_ssh_common_args` line to specify your identity file.

### 3. Install Docker on VM

```bash
make install-docker
```

### 4. Deploy Docker Socket Proxy

For security, deploy the socket proxy first:

```bash
make deploy stack=docker-socket-proxy
```

### 5. Configure Traefik

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

### 6. Deploy Traefik

```bash
make deploy stack=traefik
```

### 7. Configure DNS & Port Forwarding

**DNS (Cloudflare):**
- Create A record: `*.yourdomain.com` → Your public IP
- Create A record: `yourdomain.com` → Your public IP

**Port Forwarding (Router/Firewall):**
- Forward port 80 (HTTP) → YOUR_VM_IP:80
- Forward port 443 (HTTPS) → YOUR_VM_IP:443

**Access Traefik Dashboard:**
- Local: `http://YOUR_VM_IP:8080/dashboard/`
- External: `https://traefik.yourdomain.com`

## Structure

```
infrastructure/
├── inventory/
│   ├── hosts.yml.example            # Inventory template (copy to hosts.yml)
│   └── hosts.yml                    # Your inventory (gitignored)
├── playbooks/
│   ├── install-docker.yml           # Install Docker using geerlingguy.docker
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
mkdir -p stacks/my-service
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
make deploy stack=my-service
```

## Common Commands

```bash
# Setup (first time)
make setup

# Lint & format
make lint
make format

# Test connectivity
make ping

# Install Docker on the VM
make install-docker

# Deploy a stack
make deploy stack=traefik
make deploy stack=my-service

# Run ad-hoc Ansible commands
uv run ansible homelab -a "docker ps"
uv run ansible homelab -a "df -h"
```

## Development

### Linting & Formatting

```bash
make lint    # Check YAML, Ansible, shell scripts
make format  # Auto-format YAML and shell scripts
```

### Tools Used

- **yamllint**: YAML linting
- **ansible-lint**: Ansible best practices
- **yamlfmt**: YAML formatting (install: `brew install yamlfmt`)
- **shfmt**: Shell script formatting (install: `brew install shfmt`)
- **ruff**: Python linting/formatting (dev-dependency)

## Notes

- Stacks deploy to `/opt/stacks/<stack-name>/` on the VM
- `.env` files are NOT synced - create them on the VM manually via SSH
- The `proxy` network is created automatically when deploying Traefik
- Use `.env.example` files to document required variables for each stack
- Docker socket access is proxied through `docker-socket-proxy` for security
- Traefik dashboard is accessible on port 8080 (local) or via domain (SSL)
