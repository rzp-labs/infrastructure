#==============================================================================
# install.mk - Dependency installation
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure (e.g., MAKE_DIRS)
#
# Public variables: None
#
# Dependencies: core.mk, delegation.mk
#==============================================================================

.PHONY: install install-all

install: ## Install parent workspace dependencies only
	@echo "Installing parent workspace dependencies..."
	uv sync --group dev
	@echo ""
	@echo "Installing npm packages globally..."
	@command -v pnpm >/dev/null 2>&1 || { echo "  Installing pnpm..."; npm install -g pnpm; }
	@pnpm add -g @anthropic-ai/claude-code@latest || { \
		echo "❌ Failed to install global packages."; \
		echo "   This may be a permissions issue. Try:"; \
		echo "   1. Run: pnpm setup && source ~/.bashrc (or ~/.zshrc)"; \
		echo "   2. Then run: make install"; \
		exit 1; \
	}
	@echo ""
	@echo "✅ Parent dependencies installed!"
	@echo ""
	@if [ -n "$$VIRTUAL_ENV" ]; then \
		echo "✓ Virtual environment already active"; \
	elif [ -f .venv/bin/activate ]; then \
		echo "→ Run this command: source .venv/bin/activate"; \
	else \
		echo "✗ No virtual environment found. Run 'make install' first."; \
	fi

install-all: install ## Install parent + all submodule dependencies
	@# Pure Delegation: Delegate to each submodule's Makefile
	@echo ""
	@echo "📦 Installing dependencies for all projects..."
	$(call delegate_to_submodules,install)
	@echo ""
	@echo "✅ All dependencies installed!"
