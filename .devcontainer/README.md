# DevContainer Configuration

This directory contains the configuration for a repeatable development environment using VS Code DevContainers.

## What's Included

### Base Environment
- **Python 3.12** - Latest Python runtime
- **Docker outside of Docker** - Access to host Docker daemon
- **Git** - Version control
- **SSH daemon** - Remote SSH access

### System Tools (installed in container)
- **uv** - Fast Python package manager
- **Go** - For Go-based tools
- **yamlfmt** - YAML formatting (Go binary)
- **shfmt** - Shell script formatting (Go binary)

### Project Dependencies (installed via `make setup`)
- **ansible** - Configuration management
- **ansible-lint** - Ansible linting
- **yamllint** - YAML linting
- **ruff** - Python linting/formatting (dev-dependency)
- **Ansible collections** - community.docker, ansible.posix

### VS Code Extensions
- Ansible (redhat.ansible)
- YAML (redhat.vscode-yaml)
- Python + Pylance
- Ruff
- EditorConfig
- ShellCheck
- Shell Format

### Configuration
- YAML schemas for Ansible playbooks and Docker Compose
- Ansible vault tag support
- SSH keys mounted from host (`~/.ssh`)
- 2-space indent for YAML
- Proper file associations

## Usage

### First Time Setup

1. Install VS Code and the "Dev Containers" extension
2. Open this repository in VS Code
3. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
4. Select "Dev Containers: Reopen in Container"
5. Wait for the container to build and setup to complete

### Working in the Container

All development tools are pre-configured:

```bash
# Lint your code
make lint

# Format your code
make format

# Test connectivity to VMs
make ping

# Install Docker on VM
make install-docker

# Deploy a stack
make deploy stack=traefik
```

### SSH Access

Your host SSH keys are mounted read-only at `~/.ssh/` so you can access your VMs without copying keys into the container.

### Updating Dependencies

When you update `pyproject.toml` or `requirements.yml`, run the same command used everywhere:

```bash
make setup
```

This syncs Python dependencies and installs Ansible collections. Works in DevContainer or local environments.

### How Setup Works

1. **DevContainer build** (`.devcontainer/setup.sh`):
   - Installs system tools: uv, Go, yamlfmt, shfmt
   - Calls `make setup` to install project dependencies

2. **Manual updates** (`make setup`):
   - Runs `uv sync` to install Python packages
   - Runs `ansible-galaxy collection install` to install Ansible collections

This way `make setup` is the single source of truth for project dependencies.

## Customization

### Adding VS Code Extensions

Edit `.devcontainer/devcontainer.json` and add to the `extensions` array:

```json
"customizations": {
  "vscode": {
    "extensions": [
      "your.extension-id"
    ]
  }
}
```

### Installing Additional Tools

Edit `.devcontainer/setup.sh` and add your installation commands.

### Changing Python Version

Edit `.devcontainer/devcontainer.json` and change the base image:

```json
"image": "mcr.microsoft.com/devcontainers/python:3.13"
```

## Troubleshooting

### SSH Keys Not Working

Ensure your SSH keys have correct permissions on the host:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
```

### Ansible Can't Find Collections

Rebuild the container or run:

```bash
uv run ansible-galaxy collection install -r requirements.yml
```

### Go Tools Not Found

The Go bin directory should be in PATH. If not:

```bash
export PATH="$HOME/go/bin:$PATH"
```

### Container Won't Build

Try rebuilding from scratch:

1. `Cmd+Shift+P` → "Dev Containers: Rebuild Container"
2. Or delete `.devcontainer/.cache/` and try again
