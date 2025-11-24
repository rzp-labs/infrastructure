# Modular Makefile System

**Documentation for the workspace's modular build system**

## Overview

This directory contains a modular Makefile system that replaced a 707-line monolithic Makefile. The system is split into 9 focused modules, each handling a specific domain of functionality.

## Module Structure

```
tools/makefiles/
  ├── README.md (this file)
  ├── core.mk                    # Foundation variables and utilities
  ├── delegation.mk              # Recursive delegation patterns
  ├── install.mk                 # Dependency installation
  ├── quality.mk                 # Check/test targets
  ├── knowledge-extraction.mk    # Document processing
  ├── knowledge-synthesis.mk     # Pipeline & visualization
  ├── worktree.mk                # Git worktree utilities
  ├── content-generation.mk      # Blog/transcribe/illustrate/web-to-md
  └── utilities.mk               # Cleanup, misc utilities
```

## Module Dependencies

```
main Makefile
    ├─ core.mk (MUST BE FIRST)
    ├─ delegation.mk (MUST BE SECOND - depends on core)
    └─ All others (any order - all depend on core)
        ├─ install.mk
        ├─ quality.mk
        ├─ knowledge-extraction.mk
        ├─ knowledge-synthesis.mk (depends on knowledge-extraction)
        ├─ worktree.mk
        ├─ content-generation.mk
        └─ utilities.mk
```

## Variable Naming Convention

**CRITICAL**: All modules follow a strict naming convention to prevent collisions:

- **`MODULE_*`**: Module-private variables (e.g., `KNOWLEDGE_DATA_DIR`, `WORKTREE_STASH_DIR`)
- **Unprefixed**: Shared infrastructure (e.g., `PYTHON`, `UV`, `MAKE_DIRS`)

### Example

```makefile
# Good - module-private variable
KNOWLEDGE_DATA_DIR := .data/knowledge/docs

# Good - shared infrastructure
PYTHON := uv run python

# Bad - unprefixed module-specific variable
DATA_DIR := .data/knowledge/docs  # Collision risk!
```

## Include Order Requirements

**CRITICAL**: The include order in the main Makefile must be preserved:

1. **`core.mk`** - MUST be first (defines foundation)
2. **`delegation.mk`** - MUST be second (depends on `MAKE_DIRS` from core)
3. **All others** - Can be in any order (all depend on core)

### Why This Matters

- `core.mk` defines `MAKE_DIRS` used by delegation patterns
- `delegation.mk` provides helper functions used by other modules
- Changing order can break recursive targets or cause undefined variable errors

## Module Descriptions

### core.mk (28 lines)
**Purpose**: Foundation variables and utilities
**Dependencies**: None (must be first)
**Public Variables**: `MAKE_DIRS` (list of submodules)
**Key Functionality**: Project discovery, shared configuration

### delegation.mk (21 lines)
**Purpose**: Recursive delegation patterns
**Dependencies**: `core.mk` (uses `MAKE_DIRS`)
**Public Functions**: `delegate_to_submodules`
**Key Functionality**: Helper for `-all` targets

### install.mk (45 lines)
**Purpose**: Dependency installation
**Dependencies**: `core.mk`, `delegation.mk`
**Key Targets**: `install`, `install-all`, `lock-upgrade`

### quality.mk (56 lines)
**Purpose**: Code quality checks and tests
**Dependencies**: `core.mk`, `delegation.mk`
**Key Targets**: `check`, `check-all`, `test`, `test-all`, `smoke-test`

### knowledge-extraction.mk (63 lines)
**Purpose**: Document processing and entity extraction
**Dependencies**: `core.mk`
**Public Variables**: None (paths managed by `amplifier.config.paths`)
**Key Targets**: `knowledge-sync`, `knowledge-search`, `knowledge-stats`

### knowledge-synthesis.mk (130 lines)
**Purpose**: Knowledge pipeline and visualization
**Dependencies**: `core.mk`, `knowledge-extraction.mk`
**Public Variables**: None (paths managed by `amplifier.config.paths`)
**Key Targets**: `knowledge-update`, `knowledge-synthesize`, `knowledge-graph-build`

### worktree.mk (64 lines)
**Purpose**: Git worktree management
**Dependencies**: `core.mk`
**Public Variables**: None (paths managed by Python tools)
**Key Targets**: `worktree`, `worktree-list`, `worktree-rm`, `worktree-stash`

### content-generation.mk (170 lines)
**Purpose**: Content generation (blog, transcription, illustration, web scraping)
**Dependencies**: `core.mk`
**Key Targets**: `blog-write`, `transcribe`, `illustrate`, `web-to-md`

### utilities.mk (111 lines)
**Purpose**: Cleanup and miscellaneous utilities
**Dependencies**: `core.mk`
**Key Targets**: `clean`, `workspace-info`, `ai-context-files`, `transcript`

## Adding New Modules

To add a new module:

1. **Create file** in `tools/makefiles/` with proper header:

```makefile
#==============================================================================
# module-name.mk - Brief description
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (e.g., MYMODULE_VAR)
# - Unprefixed: Shared infrastructure (e.g., PYTHON, UV)
#
# Public variables:
# - MYMODULE_PUBLIC_VAR: Description
#
# Dependencies: core.mk [, other dependencies]
#==============================================================================

.PHONY: my-target

my-target: ## Description
	@echo "Running my target"
```

2. **Add include** to main Makefile (after `delegation.mk`):

```makefile
include tools/makefiles/module-name.mk
```

3. **Test in isolation**:

```bash
make -f tools/makefiles/module-name.mk my-target
```

4. **Update this README** with module description

## Regeneration Pattern

Modules are designed to be regeneratable:

1. Each module is self-contained with clear boundaries
2. Module headers document dependencies and public interface
3. Variables follow strict naming convention
4. Testing can be done in isolation before integration

To regenerate a module:
1. Document current public interface (variables, targets)
2. Rewrite implementation maintaining interface
3. Test in isolation
4. Test integration with other modules
5. Verify no backward compatibility breaks

## Migration History

**2025-01-02**: Modular system created from 707-line monolithic Makefile
- Split into 9 focused modules
- Established variable naming convention
- Documented include order requirements
- Added `verify-modules` target for validation

## Verification Commands

### Verify All Modules Loaded
```bash
make verify-modules
```

### Test Specific Functionality
```bash
make -n install        # Dry run parent install
make -n install-all    # Dry run recursive install
make -n check          # Dry run parent checks
make -n check-all      # Dry run recursive checks
make -n knowledge-update  # Dry run knowledge pipeline
```

### Test Module in Isolation
```bash
make -f tools/makefiles/module-name.mk target
```

## Rollback Procedures

If issues occur, rollback to monolithic Makefile:

### Method 1: From Backup (Immediate)
```bash
cp Makefile.monolithic.backup Makefile
rm -rf tools/makefiles/
```

### Method 2: Git Revert (If Committed)
```bash
git checkout HEAD -- Makefile tools/makefiles/
```

### After Rollback
- Document what failed
- File issue if systemic problem
- Test fix in isolation before re-integration

## Troubleshooting

### "Undefined variable" errors
- Check include order in main Makefile
- Verify variable defined in expected module
- Check for typos in variable names

### Targets not found
- Verify module included in main Makefile
- Check `.PHONY` declaration exists
- Test module in isolation

### Recursive targets failing
- Verify `core.mk` included first
- Verify `delegation.mk` included second
- Check `MAKE_DIRS` defined correctly

### Variable collisions
- Review naming convention (MODULE_* prefix)
- Search for duplicate definitions: `grep "VAR_NAME :=" tools/makefiles/*.mk`
- Rename to follow convention

## Best Practices

1. **Always test in isolation** before integrating
2. **Document all public variables** in module headers
3. **Follow naming convention** strictly
4. **Keep modules focused** - one domain per module
5. **Maintain backward compatibility** - existing commands must work
6. **Update this README** when adding/modifying modules

## Resources

- **Main Makefile**: `/workspaces/rzp-amplifier/Makefile`
- **Monolithic Backup**: `/workspaces/rzp-amplifier/Makefile.monolithic.backup`
- **Module Directory**: `/workspaces/rzp-amplifier/tools/makefiles/`

## Questions?

Run `make help` to see all available targets across all modules.
