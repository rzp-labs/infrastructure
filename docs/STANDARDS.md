# Infrastructure Standards and Best Practices

This document defines project-specific standards and conventions for the Infrastructure-as-Code project.

## Custom Standards

These are **enforced automatically** by the quality analyzer (`scripts/analyze_iac.py`).

### 1. Root Orchestrator Network Pattern

**Rule:** Only the root orchestrator may define networks without `external: true`.

**Rationale:**
- Centralized network management
- Avoid duplicate network definitions
- Enable independent stack deployment
- Persist networks across compose lifecycle

**✅ CORRECT:**

Root orchestrator (`stacks/docker-compose.yml`):
```yaml
networks:
  proxy:
    driver: bridge
    name: proxy
```

Individual stack (`stacks/traefik/docker-compose.yml`):
```yaml
services:
  traefik:
    networks:
      - proxy

networks:
  proxy:
    external: true  # ← Must be external
```

**❌ INCORRECT:**

Individual stack defining network:
```yaml
networks:
  proxy:
    driver: bridge  # ← ERROR: Only root orchestrator can define
```

**Violation severity:** ERROR (fails quality check)

**How to fix:**
1. Remove network definition from individual stack
2. Add network to root orchestrator if needed
3. Reference with `external: true` in stack

### 2. Docker Socket Proxy Pattern

**Rule:** Services must NOT access `/var/run/docker.sock` directly.

**Rationale:**
- Security: Direct socket access grants full Docker control
- Principle of least privilege
- Restricted API endpoints via proxy
- Audit and logging of Docker API calls

**✅ CORRECT:**

Service using socket proxy:
```yaml
services:
  traefik:
    environment:
      - DOCKER_HOST=tcp://docker-socket-proxy:2375
    networks:
      - proxy

  docker-socket-proxy:
    image: tecnativa/docker-socket-proxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - CONTAINERS=1
      - NETWORKS=1
      - SERVICES=1
      - TASKS=1
      - POST=0
      - BUILD=0
      - COMMIT=0
```

**❌ INCORRECT:**

Direct socket access:
```yaml
services:
  traefik:
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ← ERROR
```

**Exception:** The `docker-socket-proxy` service itself (it's the proxy).

**Violation severity:** ERROR (fails quality check)

**How to fix:**
1. Remove direct Docker socket volume mount
2. Ensure `docker-socket-proxy` stack is deployed
3. Set `DOCKER_HOST=tcp://docker-socket-proxy:2375`
4. Add service to `proxy` network

## Security Standards

### Privileged Containers

**Rule:** Avoid `privileged: true` unless absolutely necessary.

**✅ PREFERRED:**

Use specific capabilities:
```yaml
services:
  myapp:
    cap_add:
      - NET_ADMIN
      - SYS_TIME
```

**⚠️ USE WITH CAUTION:**

```yaml
services:
  myapp:
    privileged: true  # ← Triggers warning
```

**Severity:** WARNING

**When it's acceptable:**
- Docker-in-Docker scenarios
- System containers (e.g., systemd)
- Hardware access requirements

Document why privileged mode is needed.

### Host Network Mode

**Rule:** Avoid `network_mode: host`.

**✅ PREFERRED:**

Use port mappings:
```yaml
services:
  myapp:
    ports:
      - "8080:80"
    networks:
      - proxy
```

**⚠️ USE WITH CAUTION:**

```yaml
services:
  myapp:
    network_mode: host  # ← Triggers warning
```

**Severity:** WARNING

**When it's acceptable:**
- Performance-critical networking
- Legacy applications requiring host network
- Network monitoring tools

### Secrets Management

**Rule:** Never commit secrets to git.

**✅ CORRECT:**

`.env` file (gitignored):
```env
CLOUDFLARE_API_TOKEN=abc123...
POSTGRES_PASSWORD=secret123
```

`.env.example` (committed):
```env
CLOUDFLARE_API_TOKEN=your_token_here
POSTGRES_PASSWORD=changeme
```

**❌ INCORRECT:**

Hardcoded in docker-compose.yml:
```yaml
environment:
  - POSTGRES_PASSWORD=secret123  # ← Never commit!
```

**Detection:** Pre-commit hook with gitleaks

**Severity:** CRITICAL (blocks commit)

## Ansible Standards

### Task Naming

**Rule:** All tasks must have descriptive names.

**✅ CORRECT:**

```yaml
- name: Install Docker prerequisites
  ansible.builtin.apt:
    name:
      - apt-transport-https
      - ca-certificates
    state: present
```

**⚠️ INCORRECT:**

```yaml
- ansible.builtin.apt:  # ← Missing name
    name: docker.io
```

**Severity:** WARNING

### Module Selection

**Rule:** Prefer Ansible modules over shell commands.

**✅ PREFERRED:**

```yaml
- name: Install package
  ansible.builtin.apt:
    name: docker.io
    state: present
```

**⚠️ LESS PREFERRED:**

```yaml
- name: Install package
  ansible.builtin.shell: apt-get install -y docker.io  # ← Use apt module
  changed_when: false
```

**Why?**
- Modules are idempotent by default
- Better error handling
- Cross-platform compatibility
- Check mode support

**When shell is acceptable:**
- No module exists for the operation
- Complex command piping required
- Performance-critical operations

**If you must use shell:**
1. Add `changed_when` condition
2. Add error handling
3. Document why shell is needed

### Idempotence

**Rule:** All playbooks must be idempotent.

**Required for shell/command:**

```yaml
- name: Check if file exists
  ansible.builtin.stat:
    path: /etc/app/config
  register: config

- name: Initialize configuration
  ansible.builtin.command: app-init
  when: not config.stat.exists
  changed_when: true
```

Or:

```yaml
- name: Run database migration
  ansible.builtin.command: migrate-db
  register: migration
  changed_when: "'Applied' in migration.stdout"
  failed_when: migration.rc != 0
```

**Severity:** WARNING (ERROR if idempotence test fails)

### State Parameters

**Rule:** Explicitly set `state` parameter.

**✅ CORRECT:**

```yaml
- name: Ensure Docker is running
  ansible.builtin.systemd:
    name: docker
    state: started
    enabled: true
```

**⚠️ IMPLICIT (avoid):**

```yaml
- name: Docker service
  ansible.builtin.systemd:
    name: docker  # ← State not explicit
```

**Severity:** INFO

## YAML Style

### Indentation

- **2 spaces** for indentation (never tabs)
- Consistent across all files

### Line Length

- **Max 120 characters** per line
- Break long lines logically

### Key Ordering

Use consistent ordering:

1. Name/ID fields
2. Image/source
3. Dependencies
4. Configuration
5. Environment
6. Volumes
7. Networks
8. Labels

Example:
```yaml
services:
  traefik:
    # 1. Identity
    container_name: traefik
    image: traefik:v3.2

    # 2. Dependencies
    depends_on:
      - docker-socket-proxy
    restart: unless-stopped

    # 3. Configuration
    command:
      - --api.dashboard=true

    # 4. Environment
    environment:
      - CF_API_TOKEN=${CF_API_TOKEN}

    # 5. Volumes
    volumes:
      - ./traefik.yml:/traefik.yml:ro

    # 6. Networks
    networks:
      - proxy

    # 7. Labels
    labels:
      - traefik.enable=true
```

## Documentation Standards

### Playbook Documentation

Every playbook should have a header comment:

```yaml
---
# Playbook: Deploy Docker Stack
# Purpose: Sync stack files and start containers via Docker Compose
# Requirements: Docker, Docker Compose v2
# Tags: deployment, docker
# Author: Infrastructure Team
# Last updated: 2024-01-15
```

### Variable Documentation

Document complex variables:

```yaml
# Stack deployment configuration
# - stack_name: Name of the stack directory in stacks/
# - stack_path: Full path on remote host (default: /opt/stacks)
# - compose_file: Override compose filename (default: docker-compose.yml)
vars:
  stack_path: /opt/stacks
  compose_file: docker-compose.yml
```

### README for Stacks

Each stack should have a README with:

- Purpose of the stack
- Required environment variables
- Dependencies on other stacks
- Ports exposed
- Configuration notes

Example: `stacks/traefik/README.md`

## Git Workflow

### Commit Messages

Format:
```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation
- `style` - Formatting
- `refactor` - Code restructuring
- `test` - Adding tests
- `chore` - Maintenance

Examples:
```
feat(stacks): Add zitadel authentication stack

Adds Zitadel IdP with PostgreSQL backend. Integrates
with Traefik for automatic SSL certificates.

Closes #123
```

```
fix(molecule): Correct idempotence check for apt tasks

Changed apt tasks to use cache_valid_time to prevent
unnecessary updates on second run.
```

### Branch Naming

- Feature: `feature/short-description`
- Fix: `fix/issue-number-description`
- Docs: `docs/what-changed`
- Claude Code: `claude/task-description-sessionid`

## File Organization

### Directory Structure

```
infrastructure/
├── playbooks/           # Ansible playbooks
│   └── tasks/           # Reusable task files
├── roles/               # Ansible roles (if any)
├── stacks/              # Docker Compose stacks
│   ├── docker-compose.yml      # Root orchestrator
│   ├── stack-name/
│   │   ├── docker-compose.yml
│   │   ├── .env.example
│   │   └── README.md
├── molecule/            # Molecule test scenarios
│   └── default/
│       ├── molecule.yml
│       ├── converge.yml
│       └── verify.yml
├── tests/
│   └── artifacts/       # Test results and reports
├── scripts/             # Helper scripts
└── docs/                # Documentation
```

### File Naming

- **Playbooks:** `deploy-stack.yml`, `install-docker.yml`
- **Stacks:** `stack-name/docker-compose.yml`
- **Scripts:** `bootstrap.sh`, `analyze_iac.py`
- **Docs:** `GETTING_STARTED.md`, `TEST_STRATEGY.md`

Use kebab-case for files, snake_case for Python, lowercase for directories.

## Enforcement

Standards are enforced through:

1. **Pre-commit hooks** - Block commits violating rules
2. **CI checks** - Fail builds on violations
3. **Quality analyzer** - Score deduction for violations
4. **Code review** - Manual review for best practices

### Override Warnings

In exceptional cases, you can suppress warnings:

```yaml
# yamllint disable-line rule:line-length
very_long_line: "This line is intentionally long because..."

# ansible-lint: ignore[no-changed-when]
- name: Special case requiring shell
  ansible.builtin.shell: complex-command
```

Document why you're overriding.

## Continuous Improvement

Standards evolve. To propose changes:

1. Open an issue describing the problem
2. Discuss alternatives
3. Update this document
4. Update quality analyzer if needed
5. Run full test suite to validate

Standards are living documents, not unchangeable rules.
