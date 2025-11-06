# Infrastructure-as-Code Style Guide

This guide defines coding conventions and style preferences for Ansible playbooks and Docker Compose files.

## General Principles

1. **Clarity over cleverness** - Code should be obvious, not clever
2. **Explicit over implicit** - Make intentions clear
3. **Consistency** - Follow established patterns
4. **Documentation** - Explain "why", not just "what"

## YAML Conventions

### Indentation and Spacing

```yaml
---
# Two spaces for indentation (never tabs)
# One blank line between major sections

- name: Example Play
  hosts: all
  become: true

  vars:
    example_var: value

  tasks:
    - name: Example Task
      ansible.builtin.apt:
        name: package
        state: present
```

### Line Length

- Maximum **120 characters** per line
- Break long lines logically

```yaml
# Good
- name: Install multiple packages
  ansible.builtin.apt:
    name:
      - package-one
      - package-two
      - package-three
    state: present

# Avoid (too long)
- name: Install multiple packages
  ansible.builtin.apt:
    name: [package-one, package-two, package-three, package-four, package-five]
    state: present
```

### Boolean Values

Use `true`/`false`, not `yes`/`no` or `True`/`False`:

```yaml
# Good
become: true
check_mode: false

# Avoid
become: yes
check_mode: False
```

### Quotes

- Use quotes for strings containing special characters
- Bare words for simple values
- Consistent quote style (prefer double quotes)

```yaml
# Good
name: myapp
description: "My application: version 2.0"
path: "/opt/app"

# Avoid
name: "myapp"  # Unnecessary quotes
description: 'Single quotes'  # Inconsistent
```

### Lists

Use expanded format for readability:

```yaml
# Good
packages:
  - docker.io
  - docker-compose-plugin
  - python3-docker

# Acceptable for short lists
packages: [docker.io, python3-docker]

# Avoid for long lists
packages: [package-one, package-two, package-three, package-four, package-five]
```

## Ansible Conventions

### File Headers

Every playbook should have a descriptive header:

```yaml
---
# Playbook: <Name>
# Purpose: <Brief description>
# Requirements: <Dependencies>
# Tags: <tag1>, <tag2>
# Author: <Team or person>
# Last updated: YYYY-MM-DD
```

### Play Structure

Order sections consistently:

```yaml
- name: Descriptive Play Name
  hosts: target_group
  become: true
  gather_facts: true

  vars:
    variable_one: value
    variable_two: value

  pre_tasks:
    - name: Pre-task
      ansible.builtin.debug:
        msg: "Starting deployment"

  roles:
    - role_name

  tasks:
    - name: Main task
      ansible.builtin.command: echo "hello"

  post_tasks:
    - name: Post-task
      ansible.builtin.debug:
        msg: "Deployment complete"

  handlers:
    - name: Restart service
      ansible.builtin.systemd:
        name: myapp
        state: restarted
```

### Task Naming

Names should be:
- **Descriptive** - Explain what the task does
- **Action-oriented** - Start with a verb
- **Specific** - Include relevant details

```yaml
# Good
- name: Install Docker CE from official repository
- name: Create application configuration directory with correct permissions
- name: Deploy Traefik static configuration from template

# Avoid
- name: Install package  # Too vague
- name: Docker  # Not descriptive
- name: Step 1  # Meaningless
```

### Module Usage

#### Fully Qualified Collection Names (FQCN)

Always use FQCN for clarity:

```yaml
# Good
- name: Install package
  ansible.builtin.apt:
    name: docker.io
    state: present

# Avoid
- name: Install package
  apt:  # Missing FQCN
    name: docker.io
    state: present
```

#### Parameter Order

Consistent parameter ordering improves readability:

1. Main identifier (name, path, src, etc.)
2. State
3. Options
4. Conditionals
5. Tags

```yaml
- name: Create configuration file
  ansible.builtin.copy:
    # 1. Identifier
    dest: /etc/myapp/config.yml
    content: "{{ config_template }}"
    # 2. State
    mode: '0644'
    owner: root
    group: root
    # 3. Options
    backup: true
    validate: 'yamllint %s'
    # 4. Conditionals
  when: config_changed
  # 5. Tags
  tags: [config, myapp]
```

### Variables

#### Naming

Use descriptive, snake_case names:

```yaml
# Good
docker_version: "24.0"
traefik_config_path: /opt/stacks/traefik
enable_ssl: true

# Avoid
dv: "24.0"  # Too short
TraefikConfigPath: /opt/stacks/traefik  # Wrong case
enable-ssl: true  # Use underscore, not hyphen
```

#### Scope

Be explicit about variable scope:

```yaml
# Play variables
- name: Deploy Application
  hosts: all
  vars:
    app_version: "1.2.3"

# Group variables (inventory/group_vars/all.yml)
docker_edition: ce
docker_version: "24.0"

# Host variables (inventory/host_vars/hostname.yml)
ansible_host: 10.0.0.100
```

#### Defaults

Provide sensible defaults:

```yaml
# Role defaults (roles/myapp/defaults/main.yml)
myapp_version: "latest"
myapp_port: 8080
myapp_enable_ssl: true
```

### Conditionals

Use clear, readable conditions:

```yaml
# Good
- name: Install on Debian
  ansible.builtin.apt:
    name: package
  when: ansible_os_family == "Debian"

- name: Complex condition
  ansible.builtin.command: special-task
  when:
    - inventory_hostname in groups['web_servers']
    - enable_feature | bool
    - myapp_version is version('2.0', '>=')

# Avoid
- name: Complex inline
  ansible.builtin.command: task
  when: inventory_hostname in groups['web_servers'] and enable_feature | bool and myapp_version is version('2.0', '>=')
```

### Loops

Use `loop` with descriptive variable names:

```yaml
# Good
- name: Create user accounts
  ansible.builtin.user:
    name: "{{ user.name }}"
    groups: "{{ user.groups }}"
    state: present
  loop:
    - name: alice
      groups: admin,docker
    - name: bob
      groups: docker
  loop_control:
    loop_var: user
    label: "{{ user.name }}"

# Avoid
- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"  # Generic 'item' name
    groups: "{{ item.groups }}"
  loop: "{{ users }}"  # No loop_var or label
```

### Error Handling

Be explicit about error handling:

```yaml
# Good
- name: Attempt risky operation
  ansible.builtin.command: might-fail
  register: result
  failed_when: result.rc not in [0, 2]  # 0 or 2 are acceptable
  changed_when: result.rc == 0

- name: Operation with fallback
  block:
    - name: Try primary method
      ansible.builtin.command: primary-command
  rescue:
    - name: Fall back to secondary method
      ansible.builtin.command: fallback-command
```

### Tags

Use tags for selective execution:

```yaml
- name: Install Docker
  ansible.builtin.apt:
    name: docker.io
    state: present
  tags: [docker, install, packages]

- name: Configure Docker
  ansible.builtin.template:
    src: daemon.json.j2
    dest: /etc/docker/daemon.json
  tags: [docker, config]
  notify: restart docker
```

Common tag patterns:
- `install` - Installation tasks
- `config` - Configuration tasks
- `service` - Service management
- `never` - Skipped by default
- `always` - Always runs

## Docker Compose Conventions

### File Organization

Structure compose files consistently:

```yaml
---
# Service name (descriptive header)
# Purpose: <what this service does>
# Dependencies: <required services>
# Port: <exposed ports>

services:
  service-name:
    container_name: service-name
    image: image:tag
    restart: unless-stopped

    depends_on:
      - dependency

    environment:
      - VARIABLE=${VARIABLE}

    volumes:
      - ./config:/config:ro

    networks:
      - network-name

    labels:
      - "com.example.description=Service description"

    # Health check
    healthcheck:
      test: ["CMD", "healthcheck-command"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  network-name:
    external: true
```

### Service Names

Use kebab-case for service names:

```yaml
# Good
services:
  docker-socket-proxy:
  my-application:

# Avoid
services:
  DockerSocketProxy:  # PascalCase
  my_application:  # snake_case
```

### Image Tags

Always specify explicit versions:

```yaml
# Good
image: traefik:v3.2
image: postgres:16-alpine
image: debian:13-slim

# Avoid
image: traefik:latest
image: postgres
```

### Environment Variables

Use `.env` file for secrets and configuration:

```yaml
# docker-compose.yml
services:
  myapp:
    environment:
      - DATABASE_PASSWORD=${DATABASE_PASSWORD}
      - API_KEY=${API_KEY:-default_key}

# .env (gitignored)
DATABASE_PASSWORD=secret123
API_KEY=abc123

# .env.example (committed)
DATABASE_PASSWORD=changeme
API_KEY=your_api_key_here
```

### Volume Mounts

Be explicit about mount options:

```yaml
volumes:
  # Read-only
  - ./config.yml:/etc/app/config.yml:ro

  # Named volume
  - app-data:/var/lib/app

  # Bind mount with options
  - type: bind
    source: ./data
    target: /data
    read_only: false
```

### Networks

Use external networks for shared resources:

```yaml
# Root orchestrator only
networks:
  proxy:
    driver: bridge
    name: proxy

# Individual stacks
networks:
  proxy:
    external: true
```

### Labels

Use labels for metadata and Traefik routing:

```yaml
labels:
  # Metadata
  - "com.example.project=infrastructure"
  - "com.example.component=reverse-proxy"

  # Traefik routing
  - "traefik.enable=true"
  - "traefik.http.routers.app.rule=Host(`app.${DOMAIN}`)"
  - "traefik.http.routers.app.entrypoints=https"
  - "traefik.http.routers.app.tls.certresolver=cloudflare"
  - "traefik.http.services.app.loadbalancer.server.port=8080"
```

## Python Scripts

### Style

Follow PEP 8 with project customizations:

```python
# Line length: 120 characters
# Imports: grouped and sorted
import json
import sys
from pathlib import Path
from typing import Dict, List

# Two blank lines before functions
def analyze_project(root_path: Path) -> Dict[str, any]:
    """
    Analyze project structure.

    Args:
        root_path: Root directory of project

    Returns:
        Analysis results dictionary
    """
    results = {}
    # Implementation
    return results


# One blank line between methods
class Analyzer:
    def __init__(self):
        self.results = []

    def run(self):
        pass
```

### Type Hints

Use type hints for clarity:

```python
def process_file(
    file_path: Path,
    output_format: str = "json"
) -> Dict[str, any]:
    """Process a file and return results."""
    pass
```

### Documentation

Use docstrings:

```python
def complex_function(param1: str, param2: int) -> bool:
    """
    Brief description of function.

    Longer explanation if needed. Can include examples:
        >>> complex_function("test", 42)
        True

    Args:
        param1: Description of first parameter
        param2: Description of second parameter

    Returns:
        Description of return value

    Raises:
        ValueError: When param2 is negative
    """
    pass
```

## Shell Scripts

### Shebang and Options

```bash
#!/usr/bin/env bash
# Enable strict error handling
set -euo pipefail

# Optional: debugging
# set -x
```

### Style

```bash
# Two-space indentation
# Functions before main code

log_info() {
  echo "[INFO] $*"
}

main() {
  local variable="value"

  if [ -f "$variable" ]; then
    log_info "File exists"
  fi
}

main "$@"
```

## Comments and Documentation

### When to Comment

Comment for:
- **Why**, not **what** - Explain reasoning, not obvious actions
- **Complex logic** - Clarify non-obvious code
- **Workarounds** - Document temporary solutions
- **Security concerns** - Highlight security implications

```yaml
# Good comments
- name: Wait for service to be ready
  # GitHub API rate limiting requires this delay
  ansible.builtin.pause:
    seconds: 5

- name: Set restrictive permissions
  # Security: Prevent unauthorized access to private keys
  ansible.builtin.file:
    path: /etc/ssl/private
    mode: '0700'

# Avoid obvious comments
- name: Install Docker
  # This task installs Docker  ← Obvious from task name
  ansible.builtin.apt:
    name: docker.io
```

### TODO Comments

Format TODO comments consistently:

```yaml
# TODO(username): Description of what needs to be done
# TODO: Add error handling for network failures
# FIXME: This is a temporary workaround for issue #123
```

## Version Control

### File Organization

```
.
├── .gitignore           # Ignore patterns
├── .editorconfig        # Editor settings
├── pyproject.toml       # Python config
├── ansible.cfg          # Ansible config
├── requirements.yml     # Ansible collections
└── ...
```

### .gitignore

Ignore generated and sensitive files:

```gitignore
# Environment files
.env
*.env
!.env.example

# Python
__pycache__/
*.py[cod]
.venv/

# Ansible
*.retry

# Testing
.molecule/
tests/artifacts/

# OS
.DS_Store
Thumbs.db
```

## Formatting Tools

### Automated Formatting

Use these tools to enforce style:

```bash
# YAML formatting
yamlfmt -w .

# Shell script formatting
shfmt -w -i 2 -ci -sr scripts/*.sh

# Python formatting
uv run ruff format .

# Run all formatters
make format
```

### Pre-commit Integration

Install pre-commit hooks:

```bash
uv run pre-commit install
```

Hooks will enforce style on commit.

## Summary Checklist

Before committing code, verify:

- [ ] YAML files use 2-space indentation
- [ ] All tasks have descriptive names
- [ ] FQCN used for all Ansible modules
- [ ] Docker images have explicit version tags
- [ ] Secrets not committed to git
- [ ] Comments explain "why", not "what"
- [ ] Code passes `make check`
- [ ] Pre-commit hooks installed and passing

## References

- [Ansible Style Guide](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/)
- [YAML Style Guide](https://yaml.org/spec/1.2.2/)
- [PEP 8 - Python Style Guide](https://pep8.org/)
- [Docker Compose Specification](https://docs.docker.com/compose/compose-file/)
