# Infrastructure Testing Guide

Comprehensive testing documentation for the Infrastructure-as-Code project.

## Testing Philosophy

Our testing approach follows three core principles:

1. **Local-First Testing** - All tests run locally in containers, never connecting to production infrastructure
2. **Idempotence Verification** - Every playbook produces identical results when run multiple times
3. **Fail-Fast Quality Gates** - Catch issues early through automated validation

## Quick Start

```bash
# Run everything (full validation)
make test

# Fast iteration during development
make test-quick    # <5s: pytest + yamllint + ansible-lint

# Targeted testing
make test-molecule # Container-based integration tests
make test-quality  # Quality analysis on Python scripts

# Generate reports
make report        # Quality metrics (JSON + Markdown)
```

## Test Architecture

### IaC-Adapted Test Pyramid

Infrastructure code requires a different test distribution than application code:

```
         ┌─────────────────┐
         │   Deployment    │  10% - Real infrastructure validation
         │     Tests       │
         └─────────────────┘
       ┌─────────────────────┐
       │  Integration Tests  │  30% - Molecule scenarios
       │    (Molecule)       │
       └─────────────────────┘
     ┌───────────────────────────┐
     │   Static Analysis         │  60% - Linting, quality checks, unit tests
     │  (lint + pytest)          │
     └───────────────────────────┘
```

**Why this distribution?**
- Static analysis catches 60% of IaC issues (syntax, security, standards)
- Integration tests verify behavior in realistic environments (30%)
- Manual deployment tests validate end-to-end flows (10%)

## Test Layers

### Layer 1: Static Analysis (Fastest - <5s)

**What it tests:**
- YAML syntax and style (yamllint)
- Ansible best practices (ansible-lint)
- Python code quality (ruff, pyright)
- Custom IaC standards (analyze_iac.py)

**Run it:**
```bash
make test-quick
```

**What it catches:**
- Syntax errors before deployment
- Security issues (Docker socket access, privilege escalation)
- Architecture violations (network definitions outside root orchestrator)
- Idempotence issues (missing changed_when clauses)

### Layer 2: Unit Tests (Python)

**Coverage target**: 80% on analyze_iac.py (460 LOC critical tooling)

**Test modules:**
- `tests/test_analyze_iac.py` - YAML processing, IAM analysis, Docker Compose validation
- `tests/test_changed_files.py` - File change detection logic

**Run it:**
```bash
uv run pytest tests/                    # All tests
uv run pytest tests/test_analyze_iac.py # Specific module
make test-coverage                       # With coverage report
```

**Test structure:**
```python
class TestYAMLProcessing:
    """Tests for safe YAML loading and error handling."""

class TestIAMAnalysis:
    """Tests for playbook structure and idempotence checks."""

class TestDockerComposeAnalysis:
    """Tests for network rules and security validation."""

class TestReportGeneration:
    """Tests for scoring (10/5/2 deductions) and output formatting."""
```

### Layer 3: Integration Tests (Molecule)

**What is Molecule?**
Container-based testing framework for Ansible. Spins up test containers, runs playbooks, verifies idempotence, tears down cleanly.

**Test lifecycle:**
```
create → prepare → converge → idempotence → verify → destroy
```

**Scenarios:**

#### Default Scenario
**Purpose**: Basic infrastructure setup validation
**Location**: `molecule/default/`
**Tests**: Package installation, file creation, system configuration

#### Error Scenario
**Purpose**: Error handling and failure recovery
**Location**: `molecule/errors/`
**Tests**: Malformed YAML, failed tasks, rollback behavior

#### Multi-Service Scenario
**Purpose**: Complex stack deployment
**Location**: `molecule/multi-service/`
**Tests**: Traefik + socket-proxy integration, network configuration

#### Upgrade Scenario
**Purpose**: Idempotency and update safety
**Location**: `molecule/upgrade/`
**Tests**: Re-running playbooks produces no changes

**Run it:**
```bash
make test-molecule                           # All scenarios
uv run molecule test -s default              # Single scenario
uv run molecule converge && molecule login   # Debug interactively
```

**Idempotence Check:**

The most critical test - Molecule runs your playbook twice:

```bash
# First run - should make changes
ansible-playbook converge.yml
# changed=5, ok=10, failed=0

# Second run - should make NO changes
ansible-playbook converge.yml
# changed=0, ok=15, failed=0  ← MUST be 0 changes!
```

If the second run shows changes, the playbook is **not idempotent**.

### Layer 4: Quality Analysis

**What it analyzes:**

- **Atomicity** - Tasks properly scoped, one responsibility each
- **Idempotence** - `changed_when` defined, state parameters explicit
- **Maintainability** - Descriptive names, documented logic
- **Standards** - Network rules, Docker socket access, security practices

**Scoring:**
- Error (10 points): Critical issues (security, functionality)
- Warning (5 points): Best practice violations
- Info (2 points): Style and maintainability suggestions

**Run it:**
```bash
make test-quality  # Run analysis
make report        # Generate reports (JSON + Markdown)
```

**Output:**
- `tests/artifacts/quality_report.json` - Machine-readable results
- `docs/quality_report.md` - Human-readable summary

## Writing Tests

### Unit Tests (pytest)

**Example test:**
```python
def test_yaml_safe_load_malformed():
    """Verify safe_load handles malformed YAML gracefully."""
    malformed_yaml = "key: [unclosed"

    with pytest.raises(yaml.YAMLError):
        yaml.safe_load(malformed_yaml)
```

**Best practices:**
- One test per behavior
- Descriptive test names (test_verb_what_when)
- Use fixtures for common setup (conftest.py)
- Test edge cases (empty files, malformed input, missing keys)

### Molecule Tests

**Creating a new scenario:**

```bash
mkdir -p molecule/my-scenario
```

**molecule.yml:**
```yaml
---
driver:
  name: docker
platforms:
  - name: instance
    image: debian:13-slim
provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
    verify: verify.yml
```

**converge.yml** (playbook to test):
```yaml
---
- name: Test scenario
  hosts: all
  tasks:
    - name: Install package
      ansible.builtin.apt:
        name: curl
        state: present
```

**verify.yml** (assertions):
```yaml
---
- name: Verify installation
  hosts: all
  tasks:
    - name: Check curl installed
      ansible.builtin.command: which curl
      changed_when: false
      register: curl_check
      failed_when: curl_check.rc != 0
```

**Run it:**
```bash
uv run molecule test -s my-scenario
```

### Verification Best Practices

**Check files exist:**
```yaml
- name: Verify configuration file
  ansible.builtin.stat:
    path: /etc/myapp/config.yml
  register: config
  failed_when: not config.stat.exists
```

**Check services running:**
```yaml
- name: Verify service is running
  ansible.builtin.systemd:
    name: myapp
    state: started
  check_mode: true
  register: service
  failed_when: service.changed
```

**Check command output:**
```yaml
- name: Verify application version
  ansible.builtin.command: myapp --version
  register: version
  changed_when: false
  failed_when: "'1.2.3' not in version.stdout"
```

## Making Playbooks Testable

### DO:
✅ Use Ansible modules (apt, copy, template) not shell
✅ Set `changed_when` for command/shell tasks
✅ Use `check_mode: true` compatible tasks
✅ Name all plays and tasks descriptively
✅ Make tasks independent and atomic
✅ Use variables for configuration

### DON'T:
❌ Use shell for tasks with available modules
❌ Modify state without tracking changes
❌ Chain multiple operations in one task
❌ Use hard-coded values
❌ Skip error handling
❌ Access Docker socket directly

### Handling Non-Idempotent Tasks

Some tasks are inherently not idempotent (e.g., generating secrets).

**Strategy 1: Check First**
```yaml
- name: Check if secret exists
  ansible.builtin.stat:
    path: /etc/myapp/secret.key
  register: secret

- name: Generate secret
  ansible.builtin.command: generate-secret
  when: not secret.stat.exists
```

**Strategy 2: Mark Changed Only When Needed**
```yaml
- name: Run migration
  ansible.builtin.command: migrate-db
  register: migration
  changed_when: "'Applied' in migration.stdout"
  failed_when: migration.rc != 0
```

## CI Integration

### GitHub Actions Workflow

Tests run in parallel based on changed files:

```
┌─────────────┐
│   Detect    │──┐
│   Changes   │  │
└─────────────┘  │
                 ├──> Lint ──┐
┌─────────────┐  │           │
│    Setup    │──┘           ├──> Molecule ──> Quality ──> Cleanup
└─────────────┘              │
```

### Selective Execution

Not all tests run on every change:

- **YAML changed** → yamllint, ansible-lint
- **Python changed** → ruff, pyright, pytest
- **Playbooks changed** → Full Molecule suite
- **Stacks changed** → Standards checks only
- **Docs changed** → No tests (skip)

### Quality Gates

Build succeeds only if:

1. **Lint** - No errors (warnings allowed)
2. **Molecule** - All scenarios pass with idempotence
3. **Quality Score** - Overall score ≥ 80/100
4. **Standards** - No custom rule violations

Set `IAC_STRICT=true` to fail on warnings.

## Performance

### Typical Run Times

- **make test-quick** - 3-5 seconds
- **make test-molecule** (single scenario) - 2-3 minutes
- **make test-quality** - 5-10 seconds
- **make test** (full suite) - 3-5 minutes

### Optimization Tips

1. Use pre-built container images (Molecule)
2. Cache dependencies (uv, Ansible collections)
3. Run scenarios in parallel (GitHub Actions matrix)
4. Use path filters to skip unnecessary tests
5. Set `IAC_FAST=true` to skip slow integration tests

## Debugging Test Failures

### Molecule Failures

**1. Check the logs:**
```bash
cat /tmp/molecule_converge.log
```

**2. Keep container running:**
```bash
uv run molecule converge  # Don't run full test
uv run molecule login     # SSH into container
```

**3. Check residual resources:**
```bash
docker ps -a --filter "label=molecule"
make destroy  # Clean up
```

### Idempotence Failures

If second converge shows changes:

1. Look for tasks using `shell` or `command`
2. Add `changed_when` conditions
3. Use Ansible modules instead of shell
4. Check for timestamp-based conditions

**Example fix:**
```yaml
# Before (not idempotent)
- name: Create file
  ansible.builtin.shell: echo "content" > /tmp/file.txt

# After (idempotent)
- name: Create file
  ansible.builtin.copy:
    content: "content\n"
    dest: /tmp/file.txt
    mode: '0644'
```

### Quality Score Too Low

```bash
cat tests/artifacts/quality_report.json | jq '.issues'
```

Focus on errors first, then warnings, then info items.

## Test Configuration

### pytest.ini

```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v --tb=short --strict-markers
markers =
    unit: Unit tests
    integration: Integration tests
    slow: Tests that take >1s
```

### conftest.py (Shared Fixtures)

Provides common test data:
- Sample playbooks
- Docker Compose files
- Temporary directories
- Mock file structures

## Test Artifacts

Generated during test runs:

```
tests/artifacts/
├── quality_report.json      # Machine-readable quality metrics
├── coverage.xml             # pytest coverage report
└── molecule/                # Molecule logs and state
```

**Clean up:**
```bash
make clean      # Remove Python artifacts
make destroy    # Remove Molecule containers
make clean-all  # Remove everything
```

## Future Enhancements

Planned improvements:

- [ ] Additional Molecule scenarios (network failures, resource limits)
- [ ] Performance benchmarking (playbook execution time)
- [ ] Security scanning (trivy for containers, hadolint for Dockerfiles)
- [ ] Dependency vulnerability scanning
- [ ] Mutation testing (test the tests)
- [ ] Test coverage reporting for playbooks

## References

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [pytest Documentation](https://docs.pytest.org/)
- [Testing Strategies for Ansible](https://www.ansible.com/blog/testing-ansible-roles-with-molecule)
- [IaC Testing Guide](https://www.hashicorp.com/resources/testing-infrastructure-as-code)

---

**Remember**: Good tests make refactoring safe. Comprehensive testing enables confident deployments.
