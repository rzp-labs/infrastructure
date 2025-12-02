# Infrastructure Makefile
# Pure Delegation Architecture: Provides standard targets (install, check, test)

# Molecule scenarios (directories directly under molecule/)
MOLECULE_SCENARIOS := $(shell find molecule -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

.PHONY: help install check test \
        docker-deploy docker-deploy-all docker-deploy-bootstrap docker-deploy-services \
        docker-bootstrap docker-stop-all docker-destroy-all \
        docker-install docker-health docker-check-auth docker-restart-all docker-doctor \
        zitadel-configure zitadel-reset \
        test-quick test-all test-molecule test-quality test-coverage test-ci \
        ssh-check ssh-setup ssh-test ssh-prime \
        dev-format dev-clean dev-clean-all \
        sync-molecule-deps bootstrap report destroy clean-venv

# Default target
help: ## Show this help message
	@echo "Infrastructure Management Commands"
	@echo ""
	@echo "=== Standard Targets (Pure Delegation) ==="
	@echo "  make install         Install dependencies (Ansible + collections)"
	@echo "  make check           Run linting (YAML + Ansible + shell)"
	@echo "  make test            Run full test suite"
	@echo "  make help            Show this help message"
	@echo ""
	@echo "=== Docker Stack Management (docker-*) ==="
	@echo "  make docker-deploy stack=<name>  Deploy single stack"
	@echo "  make docker-deploy-all           Deploy all stacks"
	@echo "  make docker-bootstrap            Full bootstrap (foundation + OAuth + services)"
	@echo "  make docker-deploy-bootstrap     Deploy bootstrap stage (socket proxy + Zitadel)"
	@echo "  make docker-deploy-services      Deploy services stage (Traefik + apps)"
	@echo "  make docker-stop-all             Stop all stacks"
	@echo "  make docker-destroy-all          Destroy all stacks"
	@echo "  make docker-health               Check infrastructure health"
	@echo "  make docker-doctor               Prune unused Docker artifacts"
	@echo ""
	@echo "=== Zitadel / Auth (zitadel-*) ==="
	@echo "  make zitadel-configure           Configure Zitadel OIDC applications"
	@echo "  make zitadel-reset               Reset Zitadel (delete all data)"
	@echo "  make docker-check-auth           Check Zitadel + OIDC health"
	@echo ""
	@echo "=== Testing (test-*) ==="
	@echo "  make test-quick      Fast tests (<5s)"
	@echo "  make test-all        Full test suite"
	@echo ""
	@echo "=== SSH Configuration (ssh-*) ==="
	@echo "  make ssh-setup       First-time SSH setup wizard"
	@echo "  make ssh-check       Test VM connectivity"
	@echo ""
	@echo "=== Development (dev-*) ==="
	@echo "  make dev-format      Auto-format YAML and shell scripts"
	@echo "  make dev-clean       Remove temporary files"
	@echo ""
	@echo "For complete reference, see: docs/MAKEFILE_REFERENCE.md"

##
## Standard Targets (Pure Delegation Architecture)
##

.PHONY: clean-venv
clean-venv: ## Remove broken virtual environment if detected
	@if [ -d .venv ] && [ ! -e .venv/bin/python3 ]; then \
		echo "⚠️  Removing broken virtual environment..."; \
		rm -rf .venv; \
	fi

install: clean-venv ## Install dependencies (Ansible + collections)
	@echo "Installing Python dependencies..."
	uv sync
	@echo ""
	@echo "Installing Ansible collections to venv only (from requirements.yml)..."
	ANSIBLE_COLLECTIONS_PATH=.venv/lib/python$$(uv run python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages/ansible_collections uv run ansible-galaxy collection install -r requirements.yml --force
	@echo ""
	@echo "✅ Infrastructure dependencies installed!"

check: ## Run linting (YAML + Ansible + shell scripts)
	@echo "Linting YAML files..."
	uv run yamllint .
	@echo ""
	@echo "Linting Ansible playbooks..."
	ANSIBLE_COLLECTIONS_PATH=.venv/lib/python$$(uv run python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages/ansible_collections uv run ansible-lint playbooks/
	@echo ""
	@echo "✅ All checks passed!"

test: check sync-molecule-deps test-molecule test-quality ## Run full test suite (linting + Molecule + quality)
	@echo ""
	@echo "✅ All tests passed!"
	@echo ""
	@$(MAKE) report

.PHONY: sync-molecule-deps
sync-molecule-deps: requirements.yml ## Sync root requirements into Molecule scenarios
	@if [ -z "$(MOLECULE_SCENARIOS)" ]; then \
		echo "⚠️  No Molecule scenarios found; skipping dependency sync."; \
	else \
		echo "Syncing Molecule scenario requirements..."; \
		for scenario in $(MOLECULE_SCENARIOS); do \
			dest="molecule/$$scenario/requirements.yml"; \
			cp requirements.yml "$$dest"; \
			echo "  → $$dest"; \
		done; \
		echo "✅ Molecule requirements synced."; \
	fi

##
## Docker Stack Management (docker-*)
##

docker-deploy: ## Deploy a stack (usage: make docker-deploy stack=<stack-name>)
	@if [ -z "$(stack)" ]; then \
		echo "❌ Error: stack parameter required"; \
		echo "Usage: make docker-deploy stack=<stack-name>"; \
		exit 1; \
	fi
	@echo "Deploying stack: $(stack)"
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-stack.yml -e "stack_name=$(stack)"

docker-deploy-all: ## Deploy all stacks using root orchestrator
	@echo "Deploying all stacks..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml

docker-bootstrap: ## Bootstrap infrastructure with orchestrated deployment and OAuth setup
	@echo "Bootstrapping infrastructure..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-bootstrap.yml

docker-stop-all: ## Stop all stacks without removing volumes
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml --extra-vars "stack_state=stopped"

docker-destroy-all: ## Destroy all stacks and associated data (requires confirmation)
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-destroy-all.yml

docker-install: ## Provision Docker engine and compose on homelab host
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-install.yml

docker-health: ## Check infrastructure health and report status
	@echo "Checking infrastructure health..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-check-health.yml

docker-restart-all: ## Restart all stacks via root orchestrator
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml --extra-vars "stack_state=restarted"

docker-doctor: ## Prune unused Docker artifacts on homelab host
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-doctor.yml

docker-deploy-services: ## Deploy services stage (Traefik + dependents)
	@echo "Deploying services stage..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-services.yml

docker-check-auth: ## Check Zitadel + OIDC authentication health
	@echo "Checking authentication (Zitadel + OIDC) health..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/auth-check.yml

zitadel-configure: ## Configure Zitadel OIDC applications
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/zitadel-configure-apps.yml

zitadel-reset: ## Reset Zitadel instance (deletes all data, requires re-bootstrap)
	@echo "Resetting Zitadel instance..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/zitadel-reset.yml

##
## Testing (test-*)
##

test-quick: ## Fast tests for development iteration (<5s target)
	@echo "Running quick validation..."
	@uv run pytest tests/ -m unit --no-cov -q || { code=$$?; if [ $$code -ne 5 ]; then exit $$code; else echo "⚠️  No tests matched 'unit' marker; skipping."; fi; }
	@uv run yamllint playbooks/ stacks/ inventory/ molecule/
	@ANSIBLE_COLLECTIONS_PATH=.venv/lib/python$$(uv run python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/site-packages/ansible_collections uv run ansible-lint playbooks/
	@echo "✅ Quick tests passed!"

test-all: sync-molecule-deps ## Run comprehensive test suite (<5min target)
	@echo "Running comprehensive test suite..."
	@$(MAKE) test-quick
	@uv run molecule test --all
	@echo "✅ All tests passed!"

test-molecule: sync-molecule-deps ## Run Molecule tests with idempotence checks
	@echo "Running Molecule tests..."
	@bash scripts/run_molecule.sh default test

test-quality: ## Run IaC quality analysis
	@echo "Running quality analysis..."
	@uv run python scripts/analyze_iac.py --root . --output tests/artifacts/quality_report.json

test-coverage: ## Run pytest with coverage report (enforces 73% gate)
	@echo "Running tests with coverage..."
	@uv run pytest tests/ --cov=scripts.analyze_iac --cov-report=term-missing --cov-report=html --cov-fail-under=73
	@echo "📊 Coverage report: htmlcov/index.html"

test-ci: sync-molecule-deps ## Full CI suite with quality gates (for CI/CD automation)
	@echo "Running CI test suite..."
	@$(MAKE) check
	@$(MAKE) test-coverage
	@uv run molecule test --all
	@uv run python scripts/analyze_iac.py playbooks/ || (echo "❌ IaC analysis failed quality gate (min 80)" && exit 1)
	@echo "✅ CI tests passed!"

##
## SSH Configuration (ssh-*)
##

ssh-check: ## Test SSH connectivity to VM
	@echo "Testing VM connectivity..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible homelab -m ping

.PHONY: ssh-setup
ssh-setup: ## Run first-time SSH setup wizard
	@bash scripts/ssh-setup.sh

.PHONY: ssh-test
ssh-test: ## Run SSH diagnostics
	@uv run ansible-playbook playbooks/ssh-diagnose.yml

ssh-prime: ## Refresh repo-managed SSH host fingerprints from inventory
	uv run python scripts/update_known_hosts.py

##
## Development Commands (dev-*)
##

dev-format: ## Auto-format YAML and shell scripts
	@echo "Formatting YAML files..."
	-yamlfmt -w .
	@echo ""
	@echo "Formatting shell scripts..."
	-find scripts/ -name "*.sh" -exec shfmt -w -i 2 -ci -sr {} \;
	@echo ""
	@echo "✅ Formatting complete!"

dev-clean: ## Remove temporary files
	@echo "Cleaning temporary files..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "✅ Cleanup complete!"

dev-clean-all: dev-clean destroy ## Remove all generated files and test artifacts
	@echo "Removing test artifacts..."
	@rm -rf tests/artifacts/* 2>/dev/null || true
	@rm -rf .molecule 2>/dev/null || true
	@rm -rf molecule/*/.molecule 2>/dev/null || true
	@echo "✅ All generated files removed"

##
## Testing Harness Targets
##

bootstrap: ## Bootstrap testing environment (installs Docker if needed)
	@echo "Bootstrapping testing environment..."
	@bash scripts/bootstrap.sh

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
