# Molecule Testing Guide

This document describes the Molecule testing framework used to validate Ansible playbooks before deploying to production infrastructure.

## Overview

The infrastructure uses **Molecule** to test Ansible playbooks in isolated Docker containers before running them on remote servers. This prevents production breakage and validates deployment automation.

**Key Benefits**:
- Test playbooks locally before remote deployment
- Verify idempotence (can run multiple times safely)
- Catch configuration errors early
- Document expected behavior as code

## Architecture

### Molecule Test Structure

```
infrastructure/
├── molecule/
│   ├── default/           # Full deployment test
│   │   ├── converge.yml   # Run deployment playbooks
│   │   ├── molecule.yml   # Test configuration
│   │   ├── verify.yml     # Validate deployment
│   │   └── requirements.yml # Ansible dependencies
│   └── bootstrap/         # Clean bootstrap test (future)
├── playbooks/             # Playbooks under test
└── Makefile              # Test commands
```

### Test Scenarios

#### `default` Scenario

**Purpose**: Comprehensive deployment and authentication verification

**What it tests**:
1. Complete stack deployment (docker-bootstrap playbook)
2. Service health checks (all containers running)
3. Authentication flow (oauth2-proxy + Zitadel integration)
4. Network isolation (Zitadel not externally accessible)
5. SSL certificate acquisition

**When to run**: Before any deployment to verify changes work

#### `bootstrap` Scenario (Future)

**Purpose**: Clean deployment from scratch

**What it tests**:
1. Fresh system without Docker
2. Complete bootstrap process
3. All services start correctly
4. Configuration properly templated

**When to run**: When testing installation on new servers

## Running Tests

### Quick Start

```bash
# Run all tests
make molecule-test

# Run specific scenario
make molecule-test-default

# Cleanup test containers
make molecule-destroy
```

### Detailed Commands

```bash
# Full test lifecycle
molecule test

# Step-by-step (for debugging)
molecule create     # Create test container
molecule converge   # Run playbooks
molecule verify     # Run verification tests
molecule destroy    # Cleanup

# Specific scenario
molecule test -s default
molecule test -s bootstrap
```

### Development Workflow

When developing playbooks:

```bash
# 1. Create test container (once)
molecule create

# 2. Make changes to playbooks

# 3. Test changes (fast - container already exists)
molecule converge
molecule verify

# 4. Iterate until tests pass

# 5. Full test from scratch
molecule destroy
molecule test
```

## Test Configuration

### molecule.yml

**`molecule/default/molecule.yml`**:

```yaml
---
dependency:
  name: galaxy
  options:
    requirements-file: requirements.yml

driver:
  name: docker

platforms:
  - name: infrastructure-test
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    command: ""
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
    cgroupns_mode: host
    privileged: true
    pre_build_image: true
    networks:
      - name: traefik
      - name: zitadel
      - name: socket-proxy

provisioner:
  name: ansible
  inventory:
    host_vars:
      infrastructure-test:
        ansible_python_interpreter: /usr/bin/python3
        ansible_connection: docker
        stacks_root: /opt/stacks
        admin_email: test@example.com
        cloudflare_api_token: test-token-not-used
        cloudflare_zone_id: test-zone-not-used

verifier:
  name: ansible
```

**Key Settings**:
- **Image**: Ubuntu 22.04 with Ansible pre-installed
- **Privileged**: Required for Docker-in-Docker
- **Networks**: Pre-create Docker networks for testing
- **Inventory**: Define variables for test environment

### converge.yml

**What it does**: Runs deployment playbooks against test container

```yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  become: true

  tasks:
    - name: Include docker-bootstrap playbook
      ansible.builtin.import_playbook: ../../playbooks/docker-bootstrap.yml

    - name: Include docker-check-health playbook
      ansible.builtin.import_playbook: ../../playbooks/docker-check-health.yml
```

**Flow**:
1. Bootstrap Docker environment
2. Deploy all required stacks
3. Run health checks
4. Report deployment status

### verify.yml

**What it does**: Validates deployment meets requirements

```yaml
---
- name: Verify
  hosts: all
  gather_facts: false
  become: true

  tasks:
    # Service Health Checks
    - name: Verify docker-socket-proxy is running
      ansible.builtin.command: docker ps -q -f name=docker-socket-proxy
      register: socket_proxy_status
      changed_when: false
      failed_when: socket_proxy_status.stdout == ""

    - name: Verify Zitadel is running
      ansible.builtin.command: docker ps -q -f name=zitadel
      register: zitadel_status
      changed_when: false
      failed_when: zitadel_status.stdout == ""

    - name: Verify oauth2-proxy is running
      ansible.builtin.command: docker ps -q -f name=traefik-oauth2-proxy
      register: oauth2_status
      changed_when: false
      failed_when: oauth2_status.stdout == ""

    - name: Verify Traefik is running
      ansible.builtin.command: docker ps -q -f name=traefik
      register: traefik_status
      changed_when: false
      failed_when: traefik_status.stdout == ""

    # Authentication Flow Tests
    - name: Verify oauth2-proxy health endpoint
      ansible.builtin.uri:
        url: "http://localhost:4180/ping"
        status_code: 200
      register: oauth2_health

    - name: Verify Zitadel health endpoint (internal)
      ansible.builtin.uri:
        url: "http://localhost:8080/healthz"
        status_code: 200
      register: zitadel_health

    # Network Isolation Tests
    - name: Verify Zitadel NOT accessible on public port
      ansible.builtin.wait_for:
        port: 8080
        host: 0.0.0.0
        state: stopped
        timeout: 5
      ignore_errors: true
      register: zitadel_external

    - name: Assert Zitadel is internal only
      ansible.builtin.assert:
        that:
          - zitadel_external is failed
        fail_msg: "Zitadel should NOT be accessible externally"

    # SSL Certificate Verification
    - name: Check Traefik ACME storage exists
      ansible.builtin.stat:
        path: "{{ stacks_root }}/traefik/acme.json"
      register: acme_file

    - name: Verify ACME file has correct permissions
      ansible.builtin.assert:
        that:
          - acme_file.stat.exists
          - acme_file.stat.mode == "0600"
        fail_msg: "ACME file missing or wrong permissions"
```

**What it verifies**:
- All required containers running
- Health endpoints responding
- Network isolation enforced
- SSL certificate storage configured
- Authentication components accessible internally

## Writing Tests

### Test Principles

**1. Test behavior, not implementation**
```yaml
# ❌ Bad: Tests internal implementation
- name: Check config file has specific line
  ansible.builtin.lineinfile:
    path: /etc/config
    line: "setting=value"
    state: present

# ✅ Good: Tests observable behavior
- name: Verify service responds correctly
  ansible.builtin.uri:
    url: http://localhost:8080/healthz
    status_code: 200
```

**2. Test idempotence**
```yaml
# Molecule runs converge twice automatically
# Second run should report 0 changes
```

**3. Make failures obvious**
```yaml
# Use assert with clear messages
- name: Verify critical requirement
  ansible.builtin.assert:
    that:
      - condition
    fail_msg: "Clear explanation of what went wrong"
    success_msg: "What succeeded"
```

### Common Test Patterns

**Service Running**:
```yaml
- name: Verify service container running
  ansible.builtin.command: docker ps -q -f name={{ service_name }}
  register: result
  changed_when: false
  failed_when: result.stdout == ""
```

**HTTP Endpoint**:
```yaml
- name: Verify HTTP endpoint responds
  ansible.builtin.uri:
    url: "http://{{ host }}:{{ port }}{{ path }}"
    status_code: 200
    timeout: 10
  retries: 3
  delay: 2
```

**Port Accessibility**:
```yaml
# Should be accessible
- name: Verify port is open
  ansible.builtin.wait_for:
    port: 443
    host: localhost
    state: started
    timeout: 10

# Should NOT be accessible
- name: Verify port is closed
  ansible.builtin.wait_for:
    port: 8080
    host: 0.0.0.0
    state: stopped
    timeout: 5
  ignore_errors: true
  register: result
  failed_when: result is succeeded
```

**File Permissions**:
```yaml
- name: Check file permissions
  ansible.builtin.stat:
    path: /path/to/file
  register: file_stat

- name: Verify permissions
  ansible.builtin.assert:
    that:
      - file_stat.stat.exists
      - file_stat.stat.mode == "0600"
```

**Docker Network**:
```yaml
- name: Verify Docker network exists
  ansible.builtin.command: docker network inspect {{ network_name }}
  changed_when: false
  failed_when: false
  register: network_check

- name: Assert network exists
  ansible.builtin.assert:
    that:
      - network_check.rc == 0
```

## Debugging Failed Tests

### Get Test Logs

```bash
# Show detailed output
molecule test --debug

# Keep container after failure for inspection
molecule converge
# (don't run destroy if it fails)

# Shell into test container
molecule login

# View service logs
docker exec -it infrastructure-test docker logs service-name
```

### Common Issues

**Docker-in-Docker Fails**:
```
Error: Cannot connect to the Docker daemon
```

**Fix**: Ensure molecule.yml has `privileged: true`

**Network Already Exists**:
```
Error: network traefik already exists
```

**Fix**: Cleanup existing networks
```bash
molecule destroy
docker network prune -f
molecule test
```

**Service Not Starting**:
```
Error: Container exited with code 1
```

**Debug**:
```bash
molecule login
docker logs container-name
# Check for missing environment variables or config errors
```

**Idempotence Check Fails**:
```
ERROR: Playbook run is not idempotent
```

**Fix**: Check tasks for:
- Missing `changed_when: false` on read-only commands
- Tasks that should use `creates:` parameter
- Tasks that need `state: present` (not always recreating)

## Integration with CI/CD

### GitHub Actions

**`.github/workflows/ci.yml`**:

```yaml
name: Infrastructure Tests

on:
  pull_request:
    paths:
      - 'infrastructure/**'
      - '.github/workflows/ci.yml'
  push:
    branches:
      - main
      - develop

jobs:
  molecule:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          cd infrastructure
          pip install -r requirements.txt
          ansible-galaxy install -r requirements.yml

      - name: Run Molecule tests
        run: |
          cd infrastructure
          molecule test

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: molecule-logs
          path: infrastructure/molecule/**/log/
```

### Pre-deployment Validation

Always run tests before deploying to production:

```bash
#!/bin/bash
# deploy.sh

set -e

echo "Running Molecule tests..."
make molecule-test

echo "Tests passed! Deploying to production..."
ansible-playbook -i inventory/production playbooks/docker-deploy-all.yml
```

## Best Practices

### Test Organization

- **One scenario per major workflow** (bootstrap, upgrade, etc.)
- **Keep verify.yml focused** (test outcomes, not steps)
- **Use meaningful names** for tasks and assertions
- **Document complex tests** with comments

### Test Speed

Molecule tests can be slow. Optimize:

```yaml
# Use pre-built images (don't build from Dockerfile)
platforms:
  - name: test-instance
    pre_build_image: true

# Skip linting during development
molecule converge --skip-ansible-lint

# Reuse containers during development
molecule converge  # Run repeatedly without create/destroy
```

### Test Coverage

**What to test**:
- ✅ Service health (containers running)
- ✅ Network connectivity (services can communicate)
- ✅ Configuration correctness (env vars, files)
- ✅ Security (network isolation, permissions)
- ✅ Integration points (authentication flow)

**What NOT to test**:
- ❌ External service functionality (Zitadel's login page works)
- ❌ Implementation details (specific file contents)
- ❌ Docker image internals (assume images work)

## References

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Docker Scenario](https://molecule.readthedocs.io/en/latest/configuration.html#docker)
- [Test-Driven Infrastructure](https://www.ansible.com/blog/developing-and-testing-ansible-roles-with-molecule-and-podman-part-1)
