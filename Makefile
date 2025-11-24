# Infrastructure Makefile
# Pure Delegation Architecture: Provides standard targets (install, check, test)

# Molecule scenarios (directories directly under molecule/)
MOLECULE_SCENARIOS := $(shell find molecule -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)

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

STACK_DIRS := $(shell find stacks -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
# Exclude staged orchestrator pseudo-stacks from generic per-stack deploy targets.
# These are managed via dedicated staged playbooks and targets instead.
STACK_DIRS_NO_STAGED := $(filter-out bootstrap services,$(STACK_DIRS))
DEPLOY_STACK_TARGETS := $(addprefix deploy-,$(STACK_DIRS_NO_STAGED))
DOCKER_DEPLOY_STACK_TARGETS := $(addprefix docker-deploy-,$(STACK_DIRS_NO_STAGED))

.PHONY: help install check test setup lint format ping deploy docker-deploy\
 				 check-deploy clean destroy-zitadel docker-install docker-destroy-all\
				 docker-restart-all docker-stop-all docker-start-all docker-doctor\
		 docker-deploy-all docker-bootstrap docker-check-health ssh-prime ssh-setup ssh-test\
				 $(DEPLOY_STACK_TARGETS) $(DOCKER_DEPLOY_STACK_TARGETS) check-deploy clean destroy\
				 bootstrap test-molecule test-quality test-standards test-quick test-all\
				 test-coverage test-ci report clean-all $(DEPLOY_STACK_TARGETS)

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
	@echo "  make sync-molecule-deps  Sync requirements.yml to Molecule scenarios"
	@echo "  make test-quick      Fast tests (unit + linting) - <5s target"
	@echo "  make test-all        Full test suite (quick + Molecule + quality) - <5min"
	@echo "  make test-coverage   Run tests with coverage reporting (80% gate)"
	@echo "  make test-ci         Complete CI suite with all quality gates"
	@echo "  make bootstrap       Bootstrap testing environment (Docker + deps)"
	@echo "  make test-molecule   Run Molecule tests with idempotence checks"
	@echo "  make test-quality    Run IaC quality analysis"
	@echo "  make test-standards  Run custom standards checks"
	@echo "  make report          Generate quality reports (JSON + Markdown)"
	@echo "  make destroy         Clean up test resources (containers, networks)"
	@echo ""
	@echo "Deployment:"
	@echo "  make ping            Test VM connectivity"
	@echo "  make docker-deploy   Deploy a stack (use: make docker-deploy stack=<name>)"
	@echo "  make docker-deploy-<stack> Deploy a stack via shortcut (e.g., docker-deploy-traefik)"
	@echo "  make docker-deploy-all   Deploy all stacks via root orchestrator"
	@echo "  make docker-bootstrap    Bootstrap infrastructure with OAuth setup"
	@echo "  make docker-check-health Check infrastructure health and report status"
	@echo "  make docker-check-auth Check Zitadel + OIDC auth health (hard fail on issues)"
	@echo "  make docker-install      Provision Docker engine and compose on homelab host"
	@echo "  make docker-start-all    Bring up all stacks via root orchestrator"
	@echo "  make docker-stop-all     Stop all stacks without removing data"
	@echo "  make docker-restart-all  Restart all stacks"
	@echo "  make docker-destroy-all  Remove all stacks and data (interactive confirm)"
	@echo "  make docker-doctor       Remove unused Docker resources"
	@echo "  make ssh-prime           Refresh repo-managed SSH host fingerprints"
	@echo "  make destroy-zitadel     Destroy Zitadel stack (interactive confirmation)"
	@echo "  make check-deploy        Validate deployment configuration"
	@echo ""
	@echo "Development:"
	@echo "  make format          Auto-format YAML and shell scripts"
	@echo "  make clean           Remove temporary files"
	@echo "  make clean-all       Remove all generated files and test artifacts"

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

# Test targets for comprehensive IaC validation
# - test-quick: Fast iteration during development (<5s) - unit tests + linting
# - test-all: Full test suite (unit + Molecule + quality) - <5min target
# - test-coverage: pytest with coverage reporting (enforces 80% gate)
# - test-ci: Full CI suite (all checks + quality gates for automation)

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
## Backward-Compatible Aliases
##

setup: install ## Alias for install (backward compatibility)

lint: check ## Alias for check (backward compatibility)

##
## Deployment Commands
##

ping: ## Test SSH connectivity to VM
	@echo "Testing VM connectivity..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible homelab -m ping

.PHONY: ssh-setup
ssh-setup: ## Run first-time SSH setup wizard
	@bash scripts/ssh-setup.sh

.PHONY: ssh-test
ssh-test: ## Run SSH diagnostics
	@$(UV_RUN) ansible-playbook playbooks/ssh-diagnose.yml

docker-deploy: ## Deploy a stack (usage: make docker-deploy stack=<stack-name>)
	@if [ -z "$(stack)" ]; then \
		echo "❌ Error: stack parameter required"; \
		echo "Usage: make docker-deploy stack=<stack-name>"; \
		exit 1; \
	fi
	@echo "Deploying stack: $(stack)"
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-stack.yml -e "stack_name=$(stack)"

deploy: ## [deprecated] Use docker-deploy instead
	@$(MAKE) docker-deploy stack=$(stack)

docker-deploy-all: ## Deploy all stacks using root orchestrator
	@echo "Deploying all stacks..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml

docker-deploy-bootstrap: ## Deploy bootstrap stage (socket proxy + Zitadel)
	@echo "Deploying bootstrap stage..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-bootstrap.yml

docker-deploy-services: ## Deploy services stage (Traefik + dependents)
	@echo "Deploying services stage..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-services.yml

docker-bootstrap: ## Bootstrap infrastructure with orchestrated deployment and OAuth setup
	@echo "Bootstrapping infrastructure..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-bootstrap.yml

docker-check-health: ## Check infrastructure health and report status
	@echo "Checking infrastructure health..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-check-health.yml

docker-check-auth: ## Check Zitadel + OIDC authentication health
	@echo "Checking authentication (Zitadel + OIDC) health..."
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/auth-check.yml

auth-check: ## [deprecated] Alias for docker-check-auth
	@$(MAKE) docker-check-auth

zitadel-configure:
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/zitadel-configure-apps.yml

deploy-all: ## [deprecated] Use docker-deploy-all instead
	@$(MAKE) docker-deploy-all

$(DEPLOY_STACK_TARGETS): ## Deploy specific stack via shortcut target
	@$(MAKE) docker-deploy stack=$(patsubst deploy-%,%,$@)

$(DOCKER_DEPLOY_STACK_TARGETS): ## Deploy specific stack via docker shortcut
	@$(MAKE) docker-deploy stack=$(patsubst docker-deploy-%,%,$@)

docker-install: ## Provision Docker engine and compose on homelab host
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-install.yml

docker-start-all: ## Start all stacks via root orchestrator
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml

docker-stop-all: ## Stop all stacks without removing volumes
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml --extra-vars "stack_state=stopped"

docker-restart-all: ## Restart all stacks via root orchestrator
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-deploy-all.yml --extra-vars "stack_state=restarted"

docker-destroy-all: ## Destroy all stacks and associated data (requires confirmation)
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-destroy-all.yml

docker-doctor: ## Prune unused Docker artifacts on homelab host
	uv run python scripts/update_known_hosts.py
	scripts/ansible_exec.sh ansible-playbook playbooks/docker-doctor.yml

ssh-prime: ## Refresh repo-managed SSH host fingerprints from inventory
	uv run python scripts/update_known_hosts.py

destroy-zitadel: ## Destroy Zitadel stack (prompts for confirmation)
	@echo "Destroying Zitadel stack (you will be prompted to confirm)..."
	scripts/ansible_exec.sh ansible-playbook playbooks/destroy-zitadel.yml

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

##
## Testing Harness Targets
##

bootstrap: ## Bootstrap testing environment (installs Docker if needed)
	@echo "Bootstrapping testing environment..."
	@bash scripts/bootstrap.sh

test-molecule: sync-molecule-deps ## Run Molecule tests with idempotence checks
	@echo "Running Molecule tests for all scenarios..."
	@for scenario in $(MOLECULE_SCENARIOS); do \
			echo "==> Running scenario: $$scenario"; \
			bash scripts/run_molecule.sh $$scenario test || exit $$?; \
		done

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
