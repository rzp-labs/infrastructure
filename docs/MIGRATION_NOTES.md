# Migration Notes: Testing Harness Implementation

This document describes the changes made to integrate the Infrastructure Testing Harness.

**Date:** 2025-11-06
**Version:** 1.0.0
**Status:** Completed

## Overview

The Infrastructure project has been enhanced with a comprehensive testing harness that includes:

- **Molecule** for containerized playbook testing
- **Quality analysis** for IaC best practices
- **Custom standards** enforcement
- **CI/CD integration** with GitHub Actions
- **Automated reporting** in JSON and Markdown

## What Changed

### New Dependencies

**Python packages added to `pyproject.toml`:**
```python
dependencies = [
    # Existing
    "ansible>=9.0.0",
    "ansible-lint>=24.0.0",
    "yamllint>=1.35.0",
    # New
    "molecule>=6.0.0",
    "molecule-plugins[docker]>=23.5.0",
    "docker>=7.0.0",
    "requests>=2.31.0",
    "jinja2>=3.1.0",
    "pyyaml>=6.0.0",
]

dev = [
    "ruff>=0.8.0",
    "pyright>=1.1.0",
    "pre-commit>=3.5.0",
]
```

**After pulling latest changes, run:**
```bash
make install  # or: make setup
```

### New Directory Structure

```
infrastructure/
├── molecule/                     # NEW: Molecule test scenarios
│   └── default/
│       ├── molecule.yml
│       ├── converge.yml
│       └── verify.yml
├── tests/                        # NEW: Test infrastructure
│   ├── artifacts/                # Generated reports (gitignored)
│   └── molecule/                 # Additional scenarios (optional)
├── .github/
│   └── workflows/
│       └── ci.yml                # UPDATED: Enhanced CI workflow
├── docs/                         # NEW: Comprehensive documentation
│   ├── GETTING_STARTED.md
│   ├── TEST_STRATEGY.md
│   ├── IAC_STYLE_GUIDE.md
│   ├── QUALITY_METRICS.md
│   ├── STANDARDS.md
│   └── MIGRATION_NOTES.md        # This file
└── scripts/                      # UPDATED: New testing scripts
    ├── bootstrap.sh              # NEW: Environment setup
    ├── run_molecule.sh           # NEW: Molecule test runner
    ├── analyze_iac.py            # NEW: Quality analyzer
    └── changed_files.py          # NEW: Change detection
```

### Updated Files

#### `Makefile`

**New targets added:**
- `bootstrap` - Bootstrap testing environment
- `test-molecule` - Run Molecule tests
- `test-quality` - Run quality analysis
- `test-standards` - Run standards checks
- `report` - Generate reports
- `destroy` - Clean up test resources
- `clean-all` - Full cleanup

**Modified targets:**
- `test` - Now runs full suite (lint + molecule + quality)

**Backward compatibility maintained:**
- `make setup` still works (alias for `install`)
- `make lint` still works (alias for `check`)

#### `pyproject.toml`

**Changes:**
- Added Molecule and testing dependencies
- Added development dependencies (ruff, pyright, pre-commit)
- Existing configuration preserved

#### `.github/workflows/ci.yml`

**Enhanced with:**
- Change detection for selective execution
- Molecule testing with Docker
- Quality analysis with score thresholds
- Artifact uploads (reports, results)
- Matrix testing support
- Configurable via workflow inputs

**New environment variables:**
- `IAC_TARGETS` - Specific targets to test
- `IAC_IMAGES` - Docker images to test
- `IAC_FAST` - Fast mode flag
- `IAC_STRICT` - Strict mode flag

### New Features

#### 1. Molecule Testing

**What it does:**
- Spins up Docker containers with Debian 13
- Runs Ansible playbooks against them
- Verifies idempotence (no changes on second run)
- Validates results with assertions
- Cleans up resources automatically

**Usage:**
```bash
# Full test lifecycle
make test-molecule

# Manual control
uv run molecule create
uv run molecule converge
uv run molecule verify
uv run molecule destroy
```

#### 2. Quality Analysis

**What it evaluates:**
- **Atomicity** - Task independence and scope
- **Idempotence** - Safe repeated execution
- **Maintainability** - Code clarity and documentation
- **Standards** - Project-specific rules compliance

**Usage:**
```bash
# Run analysis
make test-quality

# Generate reports
make report

# View results
cat tests/artifacts/quality_report.json
cat docs/quality_report.md
```

#### 3. Custom Standards

**Two enforced standards:**

1. **Root Orchestrator Networks**
   - Only `stacks/docker-compose.yml` may define networks
   - Other stacks must use `external: true`

2. **Docker Socket Proxy**
   - Services must not access `/var/run/docker.sock` directly
   - Use `docker-socket-proxy` service instead

**Automatic enforcement:**
- Pre-commit hooks block violations
- CI fails on standards violations
- Quality score deduction for issues

#### 4. Pre-commit Hooks

**New file:** `.pre-commit-config.yaml`

**Hooks configured:**
- File checks (trailing whitespace, EOF, etc.)
- YAML linting (yamllint)
- Ansible linting (ansible-lint)
- Python formatting (ruff)
- Shell formatting (shfmt)
- Secrets detection (gitleaks)

**Setup:**
```bash
uv run pre-commit install
```

#### 5. Bootstrap Script

**What it does:**
- Checks dependencies (Python, Docker, uv)
- Installs Docker if missing (Debian/Ubuntu)
- Installs Python packages with uv
- Installs Ansible collections
- Pulls required Docker images
- Sets up pre-commit hooks
- Generates environment report

**Usage:**
```bash
make bootstrap
```

## Breaking Changes

### None!

All existing workflows continue to work:
- `make install` / `make setup` - Installs dependencies
- `make check` / `make lint` - Runs linting
- `make deploy stack=X` - Deploys stacks
- `make ping` - Tests connectivity

New functionality is additive.

## Migration Steps

### For Developers

1. **Pull latest changes:**
   ```bash
   git pull origin main
   cd infrastructure
   ```

2. **Bootstrap the environment:**
   ```bash
   make bootstrap
   ```

3. **Run tests to verify:**
   ```bash
   make test
   ```

4. **Review reports:**
   ```bash
   cat tests/artifacts/quality_report.json
   ```

5. **Fix any issues flagged:**
   - Check `docs/quality_report.md` for prioritized fixes
   - Follow suggestions in issue messages

### For CI/CD

**GitHub Actions users:**

The workflow is automatically updated. No changes needed.

**Custom CI systems:**

Adapt the following pattern:

```bash
# 1. Bootstrap
make bootstrap

# 2. Run tests
make test

# 3. Check results
SCORE=$(jq -r '.scores.overall' tests/artifacts/quality_report.json)
if (( $(echo "$SCORE < 80" | bc -l) )); then
  echo "Quality score below threshold: $SCORE"
  exit 1
fi

# 4. Cleanup
make destroy
```

## Troubleshooting

### Issue: Docker not found

**Solution:**
```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install docker.io docker-compose-plugin

# Or let bootstrap install it
make bootstrap
```

### Issue: Permission denied (Docker)

**Solution:**
```bash
sudo usermod -aG docker $USER
# Log out and back in, or:
newgrp docker
```

### Issue: uv command not found

**Solution:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### Issue: Pre-commit hooks fail

**Solution:**
```bash
# Update hooks
uv run pre-commit autoupdate

# Install hooks
uv run pre-commit install --install-hooks

# Run manually to see issues
uv run pre-commit run --all-files
```

### Issue: Molecule tests fail

**Check Docker daemon:**
```bash
docker ps
```

**Clean up stuck resources:**
```bash
make destroy
```

**Review logs:**
```bash
cat /tmp/molecule_converge.log
```

### Issue: Quality score too low

**View detailed report:**
```bash
cat tests/artifacts/quality_report.json | jq '.issues'
```

**Focus on errors first:**
```bash
jq '.issues[] | select(.severity=="error")' \
  tests/artifacts/quality_report.json
```

## Performance Impact

**Development:**
- `make test` now takes 3-6 minutes (was <1 minute)
- `make check` unchanged (~30 seconds)
- `make deploy` unchanged

**CI/CD:**
- Full CI run: ~5-8 minutes (was ~2 minutes)
- Selective execution reduces time for small changes
- Results cached for faster subsequent runs

**Optimization tips:**
- Use `make check` for quick validation
- Use `IAC_FAST=true` in CI for faster feedback
- Run full tests before merging only

## Known Issues

### Docker Installation on Non-Debian Systems

**Issue:** Bootstrap script only auto-installs Docker on Debian/Ubuntu.

**Workaround:** Manually install Docker for other distributions.

**Status:** Documented in `docs/GETTING_STARTED.md`

### Molecule with systemd Containers

**Issue:** Full systemd support requires privileged containers.

**Current approach:** Limited systemd functionality for security.

**Status:** Acceptable for current test coverage.

## Future Enhancements

Planned improvements:

- [ ] Additional Molecule scenarios for specific playbooks
- [ ] Integration tests for full stack deployment
- [ ] Historical trend tracking for quality scores
- [ ] Automatic issue creation for quality regressions
- [ ] Support for multiple target OS versions
- [ ] Performance benchmarking

## Documentation

New documentation available in `docs/`:

- **[GETTING_STARTED.md](GETTING_STARTED.md)** - Quick start guide
- **[TEST_STRATEGY.md](TEST_STRATEGY.md)** - Testing philosophy and approach
- **[IAC_STYLE_GUIDE.md](IAC_STYLE_GUIDE.md)** - Coding conventions
- **[QUALITY_METRICS.md](QUALITY_METRICS.md)** - Score calculation details
- **[STANDARDS.md](STANDARDS.md)** - Project-specific rules
- **[MIGRATION_NOTES.md](MIGRATION_NOTES.md)** - This document

## Questions?

- Review documentation in `docs/`
- Run `make help` for available commands
- Check existing issues on GitHub
- Contact the infrastructure team

## Rollback Procedure

If you need to temporarily revert:

```bash
# 1. Check out previous commit
git log --oneline  # Find commit before testing harness
git checkout <commit-hash>

# 2. Reinstall dependencies
make install

# 3. Run old test suite
make check
```

To restore:
```bash
git checkout main
make bootstrap
```

## Summary

The testing harness implementation:

✅ **Maintains backward compatibility** - Existing workflows unchanged
✅ **Adds comprehensive testing** - Molecule + quality analysis
✅ **Enforces standards** - Automated checks and gates
✅ **Improves quality** - Actionable reports and metrics
✅ **Integrates with CI** - GitHub Actions ready
✅ **Well documented** - Complete guides and references

**Action Required:** Run `make bootstrap` to set up your environment.

**Timeline:** Allow 5-10 minutes for initial bootstrap and first test run.

**Support:** See documentation or contact the team with questions.
