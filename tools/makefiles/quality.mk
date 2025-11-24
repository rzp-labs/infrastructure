#==============================================================================
# quality.mk - Code quality checks and tests
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure (e.g., MAKE_DIRS)
#
# Public variables: None
#
# Dependencies: core.mk, delegation.mk
#==============================================================================

.PHONY: check check-all test test-all smoke-test

check: ## Format, lint, and type-check parent workspace only
	@# Pure Delegation: Parent runs checks with parent's .venv
	@# Handle worktree virtual environment issues by unsetting mismatched VIRTUAL_ENV
	@if [ -n "$$VIRTUAL_ENV" ] && [ -d ".venv" ]; then \
		VENV_DIR=$$(cd "$$VIRTUAL_ENV" 2>/dev/null && pwd) || true; \
		LOCAL_VENV=$$(cd ".venv" 2>/dev/null && pwd) || true; \
		if [ "$$VENV_DIR" != "$$LOCAL_VENV" ]; then \
			echo "Detected virtual environment mismatch - using local .venv"; \
			export VIRTUAL_ENV=; \
		fi; \
	fi
	@echo "Checking parent workspace code..."
	@VIRTUAL_ENV= uv run ruff format .
	@VIRTUAL_ENV= uv run ruff check . --fix
	@VIRTUAL_ENV= uv run pyright . .claude/tools  # explicit path so Pyright ignores config exclusion
	@VIRTUAL_ENV= uv run python tools/check_stubs.py
	@echo "✓ Parent workspace checks passed!"

check-all: check ## Format, lint, and type-check parent + all submodules
	@# Pure Delegation: Delegate to each submodule's Makefile
	@echo ""
	@echo "Checking submodules recursively..."
	$(call delegate_to_submodules,check)
	@echo "✓ All checks complete!"

test: ## Run parent workspace tests with coverage
	@# Pure Delegation: Parent pytest uses pytest.ini to exclude submodules
	@echo "Running parent workspace tests with coverage..."
	@uv run pytest tests/ \
		--cov=amplifier \
		--cov=.claude/tools \
		--cov-report=term-missing \
		--cov-report=html \
		-v
	@echo ""
	@echo "✓ Parent tests passed!"
	@echo "📊 Coverage HTML report: htmlcov/index.html"

test-all: test ## Run tests in parent + all submodules
	@# Pure Delegation: Delegate to each submodule's Makefile
	@echo ""
	@echo "Running tests recursively in submodules..."
	$(call delegate_to_submodules,test)
	@echo "✓ All tests complete!"

smoke-test: ## Run quick smoke tests to verify basic functionality
	@echo "Running smoke tests..."
	@PYTHONPATH=. python -m amplifier.smoke_tests
	@echo "Smoke tests complete!"
