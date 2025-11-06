# Infrastructure Testing Strategy

This document describes the testing philosophy and strategies for the Infrastructure-as-Code project.

## Testing Philosophy

Our testing approach is guided by three principles:

1. **Local-First Testing** - All tests run locally in containers, never connecting to production hosts
2. **Idempotence Verification** - Every playbook must produce the same result when run multiple times
3. **Fail-Fast Quality Gates** - Catch issues early through automated checks

## Test Pyramid

```
         ┌─────────────────┐
         │   Deployment    │  ← Real infrastructure (manual testing)
         │     Tests       │
         └─────────────────┘
       ┌─────────────────────┐
       │  Integration Tests  │  ← Molecule scenarios
       │    (Molecule)       │
       └─────────────────────┘
     ┌───────────────────────────┐
     │   Unit/Static Checks      │  ← Linting, quality analysis
     │  (lint, quality analysis) │
     └───────────────────────────┘
```

## Test Levels

### 1. Static Analysis (Fastest)

**Tools:**
- yamllint - YAML syntax and style
- ansible-lint - Ansible best practices
- ruff - Python code quality
- pyright - Python type checking (optional)
- Custom standards checker - Project-specific rules

**When it runs:**
- On every commit (pre-commit hook)
- On every CI run
- Before Molecule tests

**What it catches:**
- Syntax errors
- Style violations
- Security issues (e.g., direct Docker socket access)
- Architecture violations (e.g., network definitions outside root orchestrator)

### 2. Molecule Tests (Container-Based)

**What is Molecule?**

Molecule is a testing framework for Ansible that:
- Spins up test containers
- Runs your playbooks against them
- Verifies the results
- Tears down cleanly

**Test Lifecycle:**

```
dependency → create → prepare → converge → idempotence → verify → destroy
```

1. **dependency** - Install Ansible collections/roles
2. **create** - Spin up test container(s)
3. **prepare** - Pre-configure the test environment (optional)
4. **converge** - Run the playbook under test
5. **idempotence** - Run playbook again, verify no changes
6. **verify** - Run assertions to validate state
7. **destroy** - Clean up containers and resources

**Idempotence Check:**

The most critical test. Molecule runs your playbook twice:

```bash
# First run - should make changes
ansible-playbook converge.yml
# changed=5, ok=10, failed=0

# Second run - should make NO changes
ansible-playbook converge.yml
# changed=0, ok=15, failed=0  ← Must be 0 changes!
```

If the second run shows changes, the playbook is NOT idempotent.

**Why Idempotence Matters:**

- **Safety** - You can re-run playbooks without fear of breaking things
- **Convergence** - System naturally reaches desired state
- **Automation** - Enables continuous deployment
- **Debugging** - Easier to reason about state

### 3. Quality Analysis (Static + Dynamic)

Our custom quality analyzer examines:

**Atomicity** - Are tasks properly scoped?
- Each task does one thing
- Tasks are independent
- Prefer Ansible modules over shell commands

**Idempotence** - Can playbooks run repeatedly?
- `changed_when` defined for shell/command tasks
- `state` parameter explicitly set
- No destructive operations without guards

**Maintainability** - Is code readable and documented?
- All plays have descriptive names
- All tasks have descriptive names
- Complex logic is commented
- Variables follow naming conventions

**Standards Compliance** - Project-specific rules
- Network definitions only in root orchestrator
- Docker socket access via proxy only
- Security best practices followed

### 4. Manual Deployment Tests (Slowest, Most Complete)

For changes that pass all automated tests, manual verification on real infrastructure:

1. Deploy to test/staging environment
2. Verify functionality
3. Check logs for errors
4. Validate with monitoring
5. Deploy to production

## Test Scenarios

### Current Scenarios

#### Default Scenario

**Purpose:** Validate basic infrastructure setup

**Target OS:** Debian 13 (Trixie)

**What it tests:**
- Package installation
- File creation
- Basic system configuration
- Idempotence of operations

**Location:** `molecule/default/`

### Adding New Scenarios

To test a new playbook or role:

1. Create scenario directory:
   ```bash
   mkdir -p molecule/my-scenario
   ```

2. Create `molecule.yml`:
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

3. Create `converge.yml` (your playbook to test)

4. Create `verify.yml` (assertions)

5. Run: `uv run molecule test --scenario-name my-scenario`

## Best Practices

### Writing Testable Playbooks

**DO:**
- ✅ Use Ansible modules (apt, copy, template) not shell
- ✅ Set `changed_when` for command/shell tasks
- ✅ Use `check_mode: true` compatible tasks
- ✅ Name all plays and tasks descriptively
- ✅ Make tasks independent and atomic
- ✅ Use variables for configuration

**DON'T:**
- ❌ Use shell for tasks with available modules
- ❌ Modify state without tracking changes
- ❌ Chain multiple operations in one task
- ❌ Use hard-coded values
- ❌ Skip error handling
- ❌ Access Docker socket directly

### Writing Verification Tests

Good verification tests check:

1. **Files exist and have correct content**
   ```yaml
   - name: Verify configuration file
     ansible.builtin.stat:
       path: /etc/myapp/config.yml
     register: config
     failed_when: not config.stat.exists
   ```

2. **Services are running**
   ```yaml
   - name: Verify service is running
     ansible.builtin.systemd:
       name: myapp
       state: started
     check_mode: true
     register: service
     failed_when: service.changed
   ```

3. **Commands produce expected output**
   ```yaml
   - name: Verify application version
     ansible.builtin.command: myapp --version
     register: version
     changed_when: false
     failed_when: "'1.2.3' not in version.stdout"
   ```

### Handling Non-Idempotent Tasks

Some tasks are inherently not idempotent (e.g., generating secrets, creating unique IDs).

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

**Strategy 2: Mark as Changed Only When Needed**
```yaml
- name: Run migration
  ansible.builtin.command: migrate-db
  register: migration
  changed_when: "'Applied' in migration.stdout"
  failed_when: migration.rc != 0
```

## Continuous Integration

### GitHub Actions Workflow

Our CI pipeline runs in parallel:

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
- **Python changed** → ruff, pyright
- **Playbooks changed** → Full Molecule suite
- **Stacks changed** → Standards checks only
- **Docs changed** → No tests (skip)

This is handled by `scripts/changed_files.py`.

### Quality Gates

Tests must pass these gates:

1. **Lint** - No errors, warnings allowed
2. **Molecule** - All scenarios pass, idempotence verified
3. **Quality Score** - Overall score ≥ 80/100
4. **Standards** - No violations of custom rules

In strict mode (`IAC_STRICT=true`), warnings also fail the build.

## Performance Considerations

### Test Speed

Typical run times:

- **Lint** - 10-30 seconds
- **Molecule (single scenario)** - 2-5 minutes
- **Quality analysis** - 5-15 seconds
- **Full suite** - 3-6 minutes

### Optimization Tips

1. **Use pre-built images** - Don't build containers from scratch
2. **Cache dependencies** - uv cache, Ansible collections
3. **Run in parallel** - Multiple scenarios as matrix jobs
4. **Skip on docs changes** - Use path filters
5. **Fast mode** - Set `IAC_FAST=true` to skip slow tests

## Debugging Test Failures

### Molecule Test Failures

1. **Check the logs:**
   ```bash
   cat /tmp/molecule_converge.log
   ```

2. **Keep container running:**
   ```bash
   uv run molecule converge  # Don't run full test
   uv run molecule login     # SSH into container
   ```

3. **Check for residual resources:**
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

Example fix:
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

Check the report:
```bash
cat tests/artifacts/quality_report.json | jq '.issues'
```

Focus on errors first, then warnings, then info items.

## Future Enhancements

Planned improvements:

- [ ] Additional scenarios for Docker installation
- [ ] Integration tests for full stack deployment
- [ ] Performance benchmarking
- [ ] Security scanning (trivy, hadolint)
- [ ] Dependency vulnerability scanning
- [ ] Test coverage reporting

## References

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Testing Strategies for Ansible](https://www.ansible.com/blog/testing-ansible-roles-with-molecule)
