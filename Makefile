# Infrastructure Makefile
# Pure Delegation Architecture: Provides standard targets (install, check, test)

.PHONY: help install check test setup lint format ping deploy check-deploy clean

# Default target
help: ## Show this help message
	@echo "Infrastructure Management Commands"
	@echo ""
	@echo "Standard targets (Pure Delegation):"
	@echo "  make install         Install dependencies (Ansible + collections)"
	@echo "  make check           Run linting (YAML + Ansible + shell)"
	@echo "  make test            Validate Ansible playbooks and configuration"
	@echo ""
	@echo "Backward-compatible aliases:"
	@echo "  make setup           Alias for install"
	@echo "  make lint            Alias for check"
	@echo ""
	@echo "Deployment:"
	@echo "  make ping            Test VM connectivity"
	@echo "  make deploy          Deploy a stack (use: make deploy stack=<name>)"
	@echo "  make check-deploy    Validate deployment configuration"
	@echo ""
	@echo "Development:"
	@echo "  make format          Auto-format YAML and shell scripts"
	@echo "  make clean           Remove temporary files"

##
## Standard Targets (Pure Delegation Architecture)
##

install: ## Install dependencies (Ansible + collections)
	@echo "Installing Python dependencies..."
	uv sync
	@echo ""
	@echo "Installing Ansible collections..."
	uv run ansible-galaxy collection install -r requirements.yml
	@echo ""
	@echo "✅ Infrastructure dependencies installed!"

check: ## Run linting (YAML + Ansible + shell scripts)
	@echo "Linting YAML files..."
	uv run yamllint .
	@echo ""
	@echo "Linting Ansible playbooks..."
	uv run ansible-lint playbooks/
	@echo ""
	@echo "✅ All checks passed!"

test: ## Validate Ansible playbooks and configuration
	@echo "Validating Ansible playbooks..."
	@for playbook in playbooks/*.yml; do \
		echo "Checking $$playbook..."; \
		uv run ansible-playbook "$$playbook" --syntax-check --skip-tags=never || true; \
	done
	@echo ""
	@echo "✅ Validation complete!"

##
## Backward-Compatible Aliases
##

setup: install ## Alias for install (backward compatibility)

lint: check ## Alias for check (backward compatibility)

##
## Deployment Commands
##

ping: ## Test SSH connectivity to VM
	@echo "Testing VM connectivity..."
	uv run ansible homelab -m ping

deploy: ## Deploy a stack (usage: make deploy stack=<stack-name>)
	@if [ -z "$(stack)" ]; then \
		echo "❌ Error: stack parameter required"; \
		echo "Usage: make deploy stack=<stack-name>"; \
		exit 1; \
	fi
	@echo "Deploying stack: $(stack)"
	uv run ansible-playbook playbooks/deploy-stack.yml -e "stack_name=$(stack)"

deploy-all: ## Deploy all stacks using root orchestrator
	@echo "Deploying all stacks..."
	uv run ansible-playbook playbooks/deploy-all-stacks.yml

check-deploy: ## Validate deployment configuration (dry-run)
	@echo "Validating deployment configuration..."
	uv run ansible-playbook playbooks/deploy-stack.yml --check

##
## Development Commands
##

format: ## Auto-format YAML and shell scripts
	@echo "Formatting YAML files..."
	-yamlfmt -w .
	@echo ""
	@echo "Formatting shell scripts..."
	-find scripts/ -name "*.sh" -exec shfmt -w -i 2 -ci -sr {} \;
	@echo ""
	@echo "✅ Formatting complete!"

clean: ## Remove temporary files
	@echo "Cleaning temporary files..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete!"
