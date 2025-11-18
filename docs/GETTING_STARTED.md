# Getting Started with Infrastructure Testing Harness

This guide will help you set up and use the Infrastructure-as-Code testing harness.

## Prerequisites

- **Python 3.12+**
- **uv** package manager ([installation](https://github.com/astral-sh/uv#installation))
- **Docker** (will be installed automatically if missing on Debian/Ubuntu)
- **Git**

## Quick Start

### 1. Bootstrap the Testing Environment

The bootstrap script will:
- Check for required dependencies
- Install Docker if needed (Debian/Ubuntu only)
- Install Python dependencies with uv
- Install Ansible collections
- Pull required Docker images
- Set up pre-commit hooks

```bash
make bootstrap
```

### 2. Run the Full Test Suite

```bash
make test
```

This will:
1. Run all linting checks (YAML, Ansible, Python)
2. Execute Molecule tests with idempotence verification
3. Perform quality analysis
4. Generate reports

### 3. View Reports

After running tests, check the generated reports:

```bash
# JSON report
cat tests/artifacts/quality_report.json

# Markdown report
cat docs/quality_report.md
```

### 4. Clean Up

Remove all test resources (containers, networks, volumes):

```bash
make destroy
```

Remove all generated files and artifacts:

```bash
make clean-all
```

## Common Commands

### Testing

```bash
# Run specific test types
make test-molecule     # Molecule tests only
make test-quality      # Quality analysis only
make test-standards    # Standards checks only

# Generate reports without running tests
make report
```

### Linting and Formatting

```bash
# Run all linting checks
make check

# Auto-format code
make dev-format

# Run pre-commit hooks manually
uv run pre-commit run --all-files
```

### Development

```bash
# Install/update dependencies
make install

# Clean temporary files
make dev-clean

# Full cleanup (including test artifacts)
make dev-clean-all
```

## Molecule Scenarios

### Default Scenario

The `default` scenario tests basic infrastructure setup on a Debian 13 container.

Location: `molecule/default/`

Files:
- `molecule.yml` - Scenario configuration
- `converge.yml` - Main playbook to test
- `verify.yml` - Verification tests

### Running Molecule Manually

```bash
# Full test lifecycle
uv run molecule test

# Individual phases
uv run molecule create
uv run molecule converge
uv run molecule verify
uv run molecule destroy

# Test specific scenario
uv run molecule test --scenario-name default
```

## Troubleshooting

### Docker Not Found

If Docker is not installed:

**Debian/Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose-plugin
sudo systemctl start docker
sudo usermod -aG docker $USER
```

Then log out and back in for group changes to take effect.

**Other distributions:** See [Docker installation docs](https://docs.docker.com/engine/install/)

### Permission Denied (Docker)

If you get "permission denied" errors when running Docker:

```bash
sudo usermod -aG docker $USER
# Log out and back in, or run:
newgrp docker
```

### uv Command Not Found

Install uv:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Molecule Tests Fail

Check Docker daemon status:

```bash
docker ps
```

Verify test containers:

```bash
docker ps -a --filter "label=molecule"
```

Clean up stuck resources:

```bash
make destroy
```

### Pre-commit Hooks Fail

Update hooks:

```bash
uv run pre-commit autoupdate
uv run pre-commit install --install-hooks
```

## CI/CD Integration

The testing harness integrates with GitHub Actions. See `.github/workflows/ci.yml` for the complete workflow.

### Environment Variables

Control CI behavior with environment variables:

- `IAC_TARGETS` - Specific targets to test (default: `all`)
- `IAC_IMAGES` - Docker images to test (default: `debian:13-slim`)
- `IAC_FAST` - Skip slow tests (default: `false`)
- `IAC_STRICT` - Fail on warnings (default: `false`)

### Manual Workflow Trigger

You can trigger the CI workflow manually from GitHub with custom parameters:

1. Go to Actions tab
2. Select "Infrastructure CI" workflow
3. Click "Run workflow"
4. Set parameters as needed

## Quality Metrics

The testing harness evaluates four key metrics:

- **Atomicity** (25%) - Task scope and independence
- **Idempotence** (30%) - Safe repeated execution
- **Maintainability** (20%) - Code structure and documentation
- **Standards** (25%) - Project-specific rules compliance

Overall score: weighted average of the four metrics.

**Passing threshold:** 80/100

See [QUALITY_METRICS.md](QUALITY_METRICS.md) for details on how scores are calculated.

## Custom Standards

This project enforces two custom standards:

1. **Root Orchestrator Networks** - Only the root orchestrator (`stacks/docker-compose.yml`) may define networks. Other stacks must use `external: true`.

2. **Docker Socket Proxy** - Services must not access `/var/run/docker.sock` directly. Use the `docker-socket-proxy` service instead.

See [STANDARDS.md](STANDARDS.md) for full details.

## Next Steps

- Review [TEST_STRATEGY.md](TEST_STRATEGY.md) for testing philosophy
- Check [IAC_STYLE_GUIDE.md](IAC_STYLE_GUIDE.md) for coding standards
- Read [QUALITY_METRICS.md](QUALITY_METRICS.md) to understand scoring

## Getting Help

- Check existing [Issues](https://github.com/your-org/infrastructure/issues)
- Review documentation in `docs/`
- Run `make help` for available commands
