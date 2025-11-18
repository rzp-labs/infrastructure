# Makefile Reference

Infrastructure Makefile with namespace-organized commands for deployment and development.

## Command Organization

Commands are organized by namespace for clarity:

- **Standard** (no namespace): Core operations (install, check, test, help)
- **docker-***: Docker stack management
- **test-***: Testing operations
- **ssh-***: SSH configuration
- **dev-***: Development tools

## Standard Commands

### make install
Install all dependencies (Python packages + Ansible collections).

```bash
make install
```

**What it does:**
- Installs Python dependencies via `uv sync`
- Installs Ansible collections from `requirements.yml`

**When to use:** First-time setup or after pulling dependency changes.

### make check
Run all linting checks (YAML, Ansible, shell scripts).

```bash
make check
```

**What it does:**
- yamllint on all YAML files
- ansible-lint on playbooks
- shellcheck on shell scripts (if available)

**When to use:** Before committing changes.

### make test
Run full test suite (linting + Molecule + quality analysis).

```bash
make test
```

**What it does:**
- Runs `make check`
- Executes Molecule tests
- Performs quality analysis

**When to use:** Before deployment to verify everything works.

### make help
Show available commands.

```bash
make help
```

## Docker Commands (docker-*)

### make docker-deploy stack=NAME
Deploy a single stack to the VM.

```bash
make docker-deploy stack=traefik
make docker-deploy stack=docker-socket-proxy
```

**Required parameter:** `stack` - Name of stack directory in `stacks/`

**What it does:**
1. Syncs stack files to VM (`/opt/stacks/<stack-name>/`)
2. Runs `docker compose up -d` on the VM

**When to use:** Deploying or updating individual services.

### make docker-deploy-all
Deploy all stacks sequentially.

```bash
make docker-deploy-all
```

**What it does:**
- Deploys all stacks defined in playbooks
- Uses proper ordering (socket-proxy first, then services)

**When to use:** Fresh deployment or updating all services.

### make docker-bootstrap
Bootstrap infrastructure with automated OAuth setup.

```bash
make docker-bootstrap
```

**What it does:**
1. Foundation stage: socket-proxy, database, Zitadel
2. OAuth setup: Creates Traefik app in Zitadel automatically
3. Proxy layer: Deploys Traefik with OAuth credentials
4. Services: Deploys remaining services

**When to use:** Fresh infrastructure deployment with automated authentication setup.

### make docker-stop-all
Stop all running containers on the VM.

```bash
make docker-stop-all
```

**What it does:**
- Runs `docker compose stop` for all stacks
- Containers remain but are stopped

**When to use:** Temporary shutdown without destroying data.

### make docker-destroy-all
Destroy all stacks (requires confirmation).

```bash
make docker-destroy-all
```

**What it does:**
- Prompts for confirmation (type "destroy" to proceed)
- Runs `docker compose down -v` to remove containers, networks, and volumes

**When to use:** Complete teardown before fresh deployment.

### make docker-install
Install Docker on the Debian VM (one-time setup).

```bash
make docker-install
```

**What it does:**
- Uses `geerlingguy.docker` role to install Docker
- Configures Docker daemon
- Adds user to docker group

**When to use:** Initial VM setup.

### make docker-health
Check infrastructure health.

```bash
make docker-health
```

**What it does:**
- Verifies all expected containers are running
- Checks Traefik connectivity
- Validates authentication flow

**When to use:** After deployment to verify everything is working.

### make docker-restart-all
Restart all stacks.

```bash
make docker-restart-all
```

**What it does:**
- Runs `docker compose restart` for all stacks

**When to use:** Apply configuration changes without full redeploy.

### make docker-doctor
Prune Docker resources (cleanup).

```bash
make docker-doctor
```

**What it does:**
- Removes unused containers, networks, images, volumes
- Frees up disk space on VM

**When to use:** Periodic maintenance or disk space recovery.

## Testing Commands (test-*)

### make test-quick
Fast tests only (<5 seconds).

```bash
make test-quick
```

**What it does:**
- Pytest unit tests
- Quick linting checks

**When to use:** Rapid feedback during development.

### make test-all
Full test suite (alias for `make test`).

```bash
make test-all
```

**What it does:**
- Same as `make test`

**When to use:** Comprehensive validation.

### make test-molecule
Molecule integration tests only.

```bash
make test-molecule
```

**What it does:**
- Runs Molecule scenarios in Docker containers
- Verifies deployment, idempotence, authentication

**When to use:** Testing playbook changes locally.

### make test-quality
IaC quality analysis.

```bash
make test-quality
```

**What it does:**
- Analyzes infrastructure code quality
- Generates quality metrics

**When to use:** Reviewing code quality standards.

### make test-coverage
Generate pytest coverage report.

```bash
make test-coverage
```

**What it does:**
- Runs pytest with coverage
- Generates HTML report

**When to use:** Verifying test coverage.

## SSH Commands (ssh-*)

### make ssh-check
Test SSH connectivity to VM.

```bash
make ssh-check
```

**What it does:**
- Runs `ansible homelab -m ping`
- Verifies SSH agent forwarding works

**When to use:**
- First connection (to accept host key)
- Troubleshooting SSH issues
- Verifying connectivity

### make ssh-setup
First-time SSH setup wizard.

```bash
make ssh-setup
```

**What it does:**
- Guides through inventory creation
- Helps configure SSH agent forwarding
- Tests connection

**When to use:** Initial project setup.

### make ssh-prime
Refresh SSH host keys.

```bash
make ssh-prime
```

**What it does:**
- Removes old host keys from `.ssh/known_hosts`
- Prompts to accept new host keys

**When to use:** After VM rebuild or IP change.

## Development Commands (dev-*)

### make dev-format
Auto-format YAML and shell scripts.

```bash
make dev-format
```

**What it does:**
- yamlfmt on YAML files
- shfmt on shell scripts

**When to use:** Before committing to ensure consistent formatting.

### make dev-clean
Remove temporary files.

```bash
make dev-clean
```

**What it does:**
- Removes `.pyc` files
- Cleans `__pycache__` directories
- Removes test artifacts

**When to use:** Cleanup during development.

### make dev-clean-all
Complete cleanup (temporary files + test resources).

```bash
make dev-clean-all
```

**What it does:**
- Runs `make dev-clean`
- Removes Molecule test containers
- Cleans all generated artifacts

**When to use:** Complete reset of development environment.

## Common Workflows

### Fresh Infrastructure Deployment

```bash
# 1. Install dependencies
make install

# 2. Configure inventory
cp inventory/hosts.yml.example inventory/hosts.yml
# Edit inventory/hosts.yml with VM details

# 3. Test connectivity
make ssh-check

# 4. Install Docker on VM
make docker-install

# 5. Bootstrap infrastructure
make docker-bootstrap

# 6. Verify health
make docker-health
```

### Deploy Single Service Update

```bash
# 1. Make changes to stack files
# Edit stacks/traefik/...

# 2. Test changes locally (optional)
make test-molecule

# 3. Deploy
make docker-deploy stack=traefik

# 4. Verify
make docker-health
```

### Complete Teardown and Rebuild

```bash
# 1. Destroy everything
make docker-destroy-all

# 2. Bootstrap fresh
make docker-bootstrap

# 3. Verify
make docker-health
```

### Development Workflow

```bash
# 1. Make changes
# Edit playbooks/...

# 2. Format code
make dev-format

# 3. Run checks
make check

# 4. Test locally
make test-molecule

# 5. Deploy
make docker-deploy stack=my-service
```

## Migration from Old Commands

### Removed Commands

These commands have been removed:

- `make ping` → Use `make ssh-check`
- `make setup` → Use `make install`
- `make lint` → Use `make check`
- `make format` → Use `make dev-format`
- `make clean` → Use `make dev-clean`
- `make check-deploy` → Integrated into `make docker-health`

### Command Changes

| Old Command | New Command | Notes |
|-------------|-------------|-------|
| `make ping` | `make ssh-check` | More descriptive name |
| `make setup` | `make install` | Standard naming |
| `make lint` | `make check` | Standard naming |
| `make format` | `make dev-format` | Development namespace |
| `make clean` | `make dev-clean` | Development namespace |
| `make docker-check-health` | `make docker-health` | Shorter name |

## Getting Help

For detailed information:

- **Architecture**: See [AGENTS.md](../AGENTS.md)
- **SSH Setup**: See [SSH_SETUP.md](SSH_SETUP.md)
- **Testing**: See [TESTING.md](TESTING.md)
- **Authentication**: See [AUTHENTICATION.md](AUTHENTICATION.md)

Run `make help` to see all available commands with brief descriptions.
