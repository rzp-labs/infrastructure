# Infrastructure Makefile
# Pure Delegation Architecture: Provides standard targets (install, check, test)

STACK_DIRS := $(shell find stacks -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
DEPLOY_STACK_TARGETS := $(addprefix deploy-,$(STACK_DIRS))

.PHONY: help install check test setup lint format ping deploy check-deploy clean destroy \
        bootstrap test-molecule test-quality test-standards report clean-all $(DEPLOY_STACK_TARGETS)

# Default target
help: ## Show this help message
	@echo "Infrastructure Management Commands"
	@echo ""
	@echo "Standard targets (Pure Delegation):"
	@echo "  make install         Install dependencies (Ansible + collections)"
	@echo "  make check           Run linting (YAML + Ansible + shell)"
	@echo "  make test            Run full test suite (Molecule + quality checks)"
	@echo ""
	@echo "Backward-compatible aliases:"
	@echo "  make setup           Alias for install"
	@echo "  make lint            Alias for check"
	@echo ""
	@echo "Testing harness:"
	@echo "  make bootstrap       Bootstrap testing environment (Docker + deps)"
	@echo "  make test-molecule   Run Molecule tests with idempotence checks"
	@echo "  make test-quality    Run IaC quality analysis"
	@echo "  make test-standards  Run custom standards checks"
	@echo "  make report          Generate quality reports (JSON + Markdown)"
	@echo "  make destroy         Clean up test resources (containers, networks)"
	@echo ""
	@echo "Deployment:"
	@echo "  make ping            Test VM connectivity"
	@echo "  make deploy          Deploy a stack (use: make deploy stack=<name>)"
	@echo "  make deploy-<stack>  Deploy a stack using per-stack shortcut (e.g., deploy-traefik)"
	@echo "  make check-deploy    Validate deployment configuration"
	@echo ""
	@echo "Development:"
	@echo "  make format          Auto-format YAML and shell scripts"
	@echo "  make clean           Remove temporary files"
	@echo "  make clean-all       Remove all generated files and test artifacts"

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

test: check test-molecule test-quality ## Run full test suite (linting + Molecule + quality)
	@echo ""
	@echo "✅ All tests passed!"
	@echo ""
	@$(MAKE) report

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

$(DEPLOY_STACK_TARGETS): ## Deploy specific stack via shortcut target
	@$(MAKE) deploy stack=$(patsubst deploy-%,%,$@)

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

##
## Testing Harness Targets
##

bootstrap: ## Bootstrap testing environment (installs Docker if needed)
	@echo "Bootstrapping testing environment..."
	@bash scripts/bootstrap.sh

test-molecule: ## Run Molecule tests with idempotence checks
	@echo "Running Molecule tests..."
	@bash scripts/run_molecule.sh default test

test-quality: ## Run IaC quality analysis
	@echo "Running quality analysis..."
	@uv run python scripts/analyze_iac.py --root . --output tests/artifacts/quality_report.json

test-standards: test-quality ## Run custom standards checks (alias for test-quality)

report: ## Generate quality reports (JSON + Markdown)
	@echo "Generating quality reports..."
	@if [ -f tests/artifacts/quality_report.json ]; then \
		uv run python scripts/analyze_iac.py --root . --format markdown > docs/quality_report.md 2>/dev/null || true; \
		echo "📊 Reports available:"; \
		echo "   - tests/artifacts/quality_report.json"; \
		echo "   - docs/quality_report.md"; \
	else \
		echo "⚠️  No quality report found. Run 'make test-quality' first."; \
	fi

destroy: ## Clean up all test resources (containers, networks, volumes)
	@echo "Destroying test resources..."
	@uv run molecule destroy --all 2>/dev/null || true
	@docker ps -a --filter "label=molecule" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
	@docker network ls --filter "label=molecule" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
	@docker volume ls --filter "label=molecule" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true
	@docker network ls --filter "name=molecule" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
	@echo "✅ All test resources destroyed"

clean-all: clean destroy ## Remove all generated files and test artifacts
	@echo "Removing test artifacts..."
	@rm -rf tests/artifacts/* 2>/dev/null || true
	@rm -rf .molecule 2>/dev/null || true
	@rm -rf molecule/*/.molecule 2>/dev/null || true
	@echo "✅ All generated files removed"
