# Infrastructure Quality Metrics

This document explains how quality scores are calculated and what they mean.

## Overview

The quality analyzer evaluates Infrastructure-as-Code across four dimensions:

| Metric | Weight | Focus | Passing Score |
|--------|--------|-------|---------------|
| **Atomicity** | 25% | Task scope and independence | ≥80 |
| **Idempotence** | 30% | Safe repeated execution | ≥80 |
| **Maintainability** | 20% | Code clarity and structure | ≥80 |
| **Standards** | 25% | Project-specific rules | ≥80 |
| **Overall** | 100% | Weighted average | ≥80 |

**Overall Score Formula:**
```
Overall = (Atomicity × 0.25) + (Idempotence × 0.30) +
          (Maintainability × 0.20) + (Standards × 0.25)
```

## Metric Details

### 1. Atomicity (25%)

**Definition:** Each task should do one thing well and be independent of other tasks.

**What we check:**

✅ **Good indicators:**
- Tasks use specific Ansible modules
- Each task has a single, clear purpose
- Tasks don't have complex conditional logic
- Operations are reversible

❌ **Bad indicators:**
- Using `shell` or `command` for tasks with available modules
- Tasks performing multiple operations
- Side effects in tasks
- Tightly coupled task sequences

**Examples:**

**Score: 100/100** (Perfect atomicity)
```yaml
- name: Install Docker
  ansible.builtin.apt:
    name: docker.io
    state: present
    update_cache: true
    cache_valid_time: 3600

- name: Ensure Docker is running
  ansible.builtin.systemd:
    name: docker
    state: started
    enabled: true
```

**Score: 80/100** (Minor issues)
```yaml
- name: Install and start Docker
  ansible.builtin.apt:
    name: docker.io
    state: present
  notify: start docker
```
Issue: Tasks doing multiple things (install + configure to start)

**Score: 60/100** (Major issues)
```yaml
- name: Setup Docker
  ansible.builtin.shell: |
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
```
Issues: Shell instead of modules, multiple operations, not atomic

**Deductions:**
- Using `shell`/`command` when module exists: **-5 points per occurrence**
- Task doing multiple operations: **-3 points per task**
- Missing error handling: **-2 points per task**

### 2. Idempotence (30%)

**Definition:** Running a playbook multiple times produces the same result without unwanted changes.

**What we check:**

✅ **Good indicators:**
- All tasks use idempotent modules
- `changed_when` defined for `shell`/`command`
- `state` parameter explicitly set
- Check-before-change pattern used
- Molecule idempotence tests pass

❌ **Bad indicators:**
- `shell`/`command` without `changed_when`
- State parameters missing
- Tasks creating timestamps or unique IDs without guards
- Molecule idempotence tests fail

**Examples:**

**Score: 100/100** (Perfect idempotence)
```yaml
- name: Create configuration directory
  ansible.builtin.file:
    path: /etc/myapp
    state: directory
    mode: '0755'

- name: Deploy configuration
  ansible.builtin.template:
    src: config.yml.j2
    dest: /etc/myapp/config.yml
    mode: '0644'
```

**Score: 85/100** (Controlled shell usage)
```yaml
- name: Check if initialized
  ansible.builtin.stat:
    path: /etc/myapp/.initialized
  register: init_status

- name: Initialize application
  ansible.builtin.command: myapp init
  when: not init_status.stat.exists
  changed_when: true
```

**Score: 60/100** (Non-idempotent)
```yaml
- name: Initialize app
  ansible.builtin.shell: myapp init  # ← No changed_when

- name: Generate secret
  ansible.builtin.shell: openssl rand -base64 32 > /etc/myapp/secret
  # ← Regenerates on every run!
```

**Deductions:**
- `shell`/`command` without `changed_when`: **-10 points per occurrence**
- Missing `state` parameter: **-3 points per occurrence**
- Molecule idempotence test failure: **-20 points**
- Timestamp/unique ID without guard: **-5 points per occurrence**

### 3. Maintainability (20%)

**Definition:** Code is readable, documented, and easy to modify.

**What we check:**

✅ **Good indicators:**
- All plays have descriptive names
- All tasks have descriptive names
- Complex logic is commented
- Variables are well-organized
- Consistent formatting
- README files for stacks

❌ **Bad indicators:**
- Missing names for plays/tasks
- Cryptic variable names
- No documentation
- Inconsistent style
- Magic numbers
- Dead code

**Examples:**

**Score: 100/100** (Highly maintainable)
```yaml
---
# Deploy Traefik reverse proxy with Cloudflare DNS challenge
# Requirements: Cloudflare API token in .env
# Author: DevOps Team

- name: Deploy Traefik Stack
  hosts: homelab
  become: true
  vars:
    traefik_version: "v3.2"
    config_path: /opt/stacks/traefik

  tasks:
    - name: Create Traefik configuration directory
      ansible.builtin.file:
        path: "{{ config_path }}"
        state: directory
        mode: '0755'
      tags: [setup, traefik]

    - name: Deploy Traefik static configuration
      ansible.builtin.template:
        src: traefik.yml.j2
        dest: "{{ config_path }}/traefik.yml"
        mode: '0644'
      notify: restart traefik
      tags: [config, traefik]
```

**Score: 75/100** (Moderate issues)
```yaml
- name: Setup
  hosts: all
  tasks:
    - ansible.builtin.file:  # ← Missing task name
        path: /opt/app
        state: directory

    - name: Copy file
      ansible.builtin.copy:
        src: cfg  # ← Cryptic name
        dest: /opt/app/c
```

**Score: 50/100** (Poor maintainability)
```yaml
- hosts: all
  tasks:
    - shell: mkdir -p /opt/app && cp config /opt/app/
    - shell: chmod 755 /opt/app
    # No names, no comments, using shell
```

**Deductions:**
- Missing play name: **-5 points per play**
- Missing task name: **-5 points per task**
- No documentation header: **-3 points per file**
- Cryptic names: **-2 points per occurrence**
- YAML parsing errors: **-10 points per file**

### 4. Standards (25%)

**Definition:** Compliance with project-specific rules and security best practices.

**What we check:**

✅ **Custom Standards:**
- Network definitions only in root orchestrator
- Docker socket access via proxy only

✅ **Security Standards:**
- No privileged containers (unless documented)
- No host network mode (unless documented)
- No secrets in git
- Secure file permissions

**Examples:**

**Score: 100/100** (Perfect compliance)
```yaml
# Individual stack
services:
  traefik:
    image: traefik:v3.2
    environment:
      - DOCKER_HOST=tcp://docker-socket-proxy:2375
    networks:
      - proxy

networks:
  proxy:
    external: true
```

**Score: 50/100** (Standards violations)
```yaml
services:
  traefik:
    image: traefik:latest  # ← Unversioned
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock  # ← Direct socket
    privileged: true  # ← Privileged mode
    network_mode: host  # ← Host network

networks:
  proxy:  # ← Not root orchestrator
    driver: bridge
```

**Deductions:**
- Non-root orchestrator defining network: **-10 points per network**
- Direct Docker socket access: **-10 points per service**
- Privileged container: **-5 points per service**
- Host network mode: **-5 points per service**
- Unversioned images: **-2 points per service**

## Score Interpretation

### Overall Score Ranges

| Score | Grade | Interpretation | Action |
|-------|-------|----------------|--------|
| **90-100** | A | Excellent | Maintain quality |
| **80-89** | B | Good | Minor improvements |
| **70-79** | C | Acceptable | Address warnings |
| **60-69** | D | Needs work | Fix errors first |
| **0-59** | F | Poor | Major refactoring |

### Category-Specific Guidance

**Atomicity < 80:**
- Review tasks using shell/command
- Break down complex tasks
- Use Ansible modules

**Idempotence < 80:**
- Run Molecule idempotence tests
- Add `changed_when` to shell tasks
- Explicitly set `state` parameters
- Fix timestamp/UUID generation

**Maintainability < 80:**
- Add names to all plays and tasks
- Document complex logic
- Improve variable naming
- Add README files

**Standards < 80:**
- Review custom standards violations
- Fix security issues immediately
- Update Docker Compose configurations

## Reports

### JSON Report Structure

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "scores": {
    "atomicity": 95.0,
    "idempotence": 88.0,
    "maintainability": 92.0,
    "standards": 85.0,
    "overall": 90.0
  },
  "summary": {
    "total_issues": 12,
    "by_severity": {
      "error": 2,
      "warning": 7,
      "info": 3
    },
    "by_category": {
      "atomicity": 3,
      "idempotence": 5,
      "maintainability": 2,
      "standards": 2
    }
  },
  "files_analyzed": 15,
  "issues": [
    {
      "file": "playbooks/deploy-stack.yml",
      "line": 45,
      "severity": "warning",
      "category": "idempotence",
      "message": "shell/command should define 'changed_when'",
      "fix_suggestion": "Add 'changed_when: <condition>'"
    }
  ]
}
```

### Markdown Report

Generated from JSON report, includes:
- Executive summary
- Score breakdown
- Issues by priority
- Recommended fixes
- Historical trends (if available)

Location: `docs/quality_report.md`

## Continuous Monitoring

### Tracking Improvements

Compare scores over time:

```bash
# Save historical reports
cp tests/artifacts/quality_report.json \
   tests/artifacts/quality_report_$(date +%Y%m%d).json

# Compare
jq -r '.scores' tests/artifacts/quality_report_20240101.json
jq -r '.scores' tests/artifacts/quality_report.json
```

### CI Integration

In GitHub Actions:

```yaml
- name: Check quality threshold
  run: |
    SCORE=$(jq -r '.scores.overall' tests/artifacts/quality_report.json)
    if (( $(echo "$SCORE < 80" | bc -l) )); then
      echo "Quality score below threshold: $SCORE"
      exit 1
    fi
```

### Quality Goals

Set targets:

| Quarter | Atomicity | Idempotence | Maintainability | Standards | Overall |
|---------|-----------|-------------|-----------------|-----------|---------|
| Q1 2024 | 80 | 85 | 80 | 90 | 84 |
| Q2 2024 | 85 | 90 | 85 | 95 | 89 |
| Q3 2024 | 90 | 95 | 90 | 100 | 94 |
| Q4 2024 | 95 | 100 | 95 | 100 | 98 |

## Improving Scores

### Quick Wins

1. **Add task names** - +5-10 points maintainability
2. **Fix shell commands** - +10-15 points idempotence
3. **Use external networks** - +10 points standards
4. **Add documentation** - +5 points maintainability

### Long-term Improvements

1. Refactor shell tasks to use modules
2. Implement comprehensive Molecule scenarios
3. Create reusable Ansible roles
4. Document architectural decisions
5. Regular security audits

## FAQs

**Q: Why is idempotence weighted highest (30%)?**

A: Idempotence is fundamental to reliable automation. Non-idempotent playbooks can cause production issues and make debugging difficult.

**Q: Can I disable certain checks?**

A: Yes, but document why. Use inline comments to suppress warnings for exceptional cases.

**Q: What's a realistic goal for a new project?**

A: Aim for 80+ overall. Start with 100% standards compliance, then improve other metrics.

**Q: How often should I run quality checks?**

A: On every commit (pre-commit hook) and in CI. Run full analysis weekly.

**Q: Why did my score drop after adding code?**

A: New code is assessed. If new code has lower quality, overall score decreases. This is expected and highlights areas needing improvement.

## References

- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Docker Compose Best Practices](https://docs.docker.com/compose/production/)
- [Infrastructure as Code Patterns](https://www.oreilly.com/library/view/infrastructure-as-code/9781491924358/)
