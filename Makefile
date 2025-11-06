# Infrastructure Makefile
# Pure Delegation Architecture: Provides standard targets (install, check, test)

STACK_DIRS := $(shell find stacks -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
DEPLOY_STACK_TARGETS := $(addprefix deploy-,$(STACK_DIRS))
DOCKER_DEPLOY_STACK_TARGETS := $(addprefix docker-deploy-,$(STACK_DIRS))

.PHONY: help install check test setup lint format ping deploy docker-deploy check-deploy clean destroy-zitadel docker-install docker-destroy-all docker-restart-all docker-stop-all docker-start-all docker-doctor docker-deploy-all $(DEPLOY_STACK_TARGETS) $(DOCKER_DEPLOY_STACK_TARGETS)

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
	@echo "  make docker-deploy   Deploy a stack (use: make docker-deploy stack=<name>)"
	@echo "  make docker-deploy-<stack> Deploy a stack via shortcut (e.g., docker-deploy-traefik)"
	@echo "  make docker-deploy-all  Deploy all stacks via root orchestrator"
	@echo "  make docker-install  Provision Docker engine and compose on homelab host"
	@echo "  make docker-start-all  Bring up all stacks via root orchestrator"
	@echo "  make docker-stop-all   Stop all stacks without removing data"
	@echo "  make docker-restart-all Restart all stacks"
	@echo "  make docker-destroy-all Remove all stacks and data (interactive confirm)"
	@echo "  make docker-doctor    Remove unused Docker resources"
	@echo "  make destroy-zitadel Destroy Zitadel stack (interactive confirmation)"
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

docker-deploy: ## Deploy a stack (usage: make docker-deploy stack=<stack-name>)
	@if [ -z "$(stack)" ]; then \
		echo "❌ Error: stack parameter required"; \
		echo "Usage: make docker-deploy stack=<stack-name>"; \
		exit 1; \
	fi
	@echo "Deploying stack: $(stack)"
	uv run ansible-playbook playbooks/docker-deploy-stack.yml -e "stack_name=$(stack)"

deploy: ## [deprecated] Use docker-deploy instead
	@$(MAKE) docker-deploy stack=$(stack)

docker-deploy-all: ## Deploy all stacks using root orchestrator
	@echo "Deploying all stacks..."
	uv run ansible-playbook playbooks/docker-deploy-all.yml

deploy-all: ## [deprecated] Use docker-deploy-all instead
	@$(MAKE) docker-deploy-all

$(DEPLOY_STACK_TARGETS): ## Deploy specific stack via shortcut target
	@$(MAKE) docker-deploy stack=$(patsubst deploy-%,%,$@)

$(DOCKER_DEPLOY_STACK_TARGETS): ## Deploy specific stack via docker shortcut
	@$(MAKE) docker-deploy stack=$(patsubst docker-deploy-%,%,$@)

docker-install: ## Provision Docker engine and compose on homelab host
	uv run ansible-playbook playbooks/docker-install.yml

docker-start-all: ## Start all stacks via root orchestrator
	uv run ansible-playbook playbooks/docker-deploy-all.yml

docker-stop-all: ## Stop all stacks without removing volumes
	uv run ansible-playbook playbooks/docker-deploy-all.yml --extra-vars "stack_state=stopped"

docker-restart-all: ## Restart all stacks via root orchestrator
	uv run ansible-playbook playbooks/docker-deploy-all.yml --extra-vars "stack_state=restarted"

docker-destroy-all: ## Destroy all stacks and associated data (requires confirmation)
	uv run ansible-playbook playbooks/docker-destroy-all.yml

docker-doctor: ## Prune unused Docker artifacts on homelab host
	uv run ansible-playbook playbooks/docker-doctor.yml

destroy-zitadel: ## Destroy Zitadel stack (prompts for confirmation)
	@echo "Destroying Zitadel stack (you will be prompted to confirm)..."
	uv run ansible-playbook playbooks/destroy-zitadel.yml

check-deploy: ## Validate deployment configuration (dry-run)
	@echo "Validating deployment configuration..."
	uv run ansible-playbook playbooks/docker-deploy-stack.yml --check

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
