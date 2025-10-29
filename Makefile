.PHONY: setup lint format install-docker deploy deploy-all check-deploy ping clean verify-galaxy

SHELL := /bin/bash
GO_BIN := $(HOME)/go/bin
UV := uv run

YAML_DIRS := inventory/ playbooks/ stacks/
SCRIPT_DIR := scripts/
BACKUP_DIR := /opt/stack_backups

# 🎯 Default target
default: lint

# --------------------------------------------------------------------------- #
# 📦 Setup
# --------------------------------------------------------------------------- #

setup:
	@echo "📚 Installing project dependencies..."
	uv sync --all-extras
	@echo "📦 Installing Ansible Galaxy collections (including pre-releases)..."
	$(UV) ansible-galaxy collection install -r requirements.yml --force --pre
	@echo "✓ Project dependencies installed successfully."

verify-galaxy:
	@echo "🔎 Verifying installed Ansible Galaxy collections..."
	$(UV) ansible-galaxy collection list
	@echo "✓ Verified available collections."

# --------------------------------------------------------------------------- #
# 🧹 Code Quality
# --------------------------------------------------------------------------- #

lint:
	@echo "🔍 Running lint checks..."
	$(UV) yamllint $(YAML_DIRS)
	$(UV) ansible-lint playbooks/
	@$(MAKE) _lint_shell
	@$(MAKE) _lint_yaml

_lint_shell:
	@echo "🔍 Linting shell scripts..."
	@if [ -x "$(GO_BIN)/shfmt" ]; then \
		"$(GO_BIN)/shfmt" -d -i 2 -ci -sr $(SCRIPT_DIR) || true; \
	elif command -v shfmt >/dev/null 2>&1; then \
		shfmt -d -i 2 -ci -sr $(SCRIPT_DIR) || true; \
	else \
		echo "⚠️  shfmt not installed - skipping shell lint"; \
	fi

_lint_yaml:
	@echo "🔍 Linting YAML format..."
	@if [ -x "$(GO_BIN)/yamlfmt" ]; then \
		"$(GO_BIN)/yamlfmt" -lint $(YAML_DIRS); \
	elif command -v yamlfmt >/dev/null 2>&1; then \
		yamlfmt -lint $(YAML_DIRS); \
	else \
		echo "⚠️  yamlfmt not installed - skipping YAML lint"; \
	fi

# --------------------------------------------------------------------------- #
# 🪄 Formatting
# --------------------------------------------------------------------------- #

format:
	@echo "🧽 Formatting shell and YAML files..."
	@$(MAKE) _format_shell
	@$(MAKE) _format_yaml
	@echo "✓ Formatting complete."

_format_shell:
	@if [ -x "$(GO_BIN)/shfmt" ]; then \
		"$(GO_BIN)/shfmt" -w -i 2 -ci -sr $(SCRIPT_DIR); \
	elif command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 2 -ci -sr $(SCRIPT_DIR); \
	else \
		echo "⚠️  shfmt not installed - install with: brew install shfmt"; \
	fi
	@echo "✓ Shell scripts formatted"

_format_yaml:
	@if [ -x "$(GO_BIN)/yamlfmt" ]; then \
		"$(GO_BIN)/yamlfmt" $(YAML_DIRS); \
	elif command -v yamlfmt >/dev/null 2>&1; then \
		yamlfmt $(YAML_DIRS); \
	else \
		echo "⚠️  yamlfmt not installed - install with: brew install yamlfmt"; \
	fi
	@echo "✓ YAML files formatted"

# --------------------------------------------------------------------------- #
# 🐳 Docker + Ansible
# --------------------------------------------------------------------------- #

install-docker:
	$(UV) ansible-playbook playbooks/install-docker.yml

deploy:
	@if [ -z "$(stack)" ]; then \
		echo "Usage: make deploy stack=<stack-name> (supports multiple stacks)"; \
		exit 1; \
	fi
	@for s in $(stack); do \
		echo "🚀 Deploying $$s..."; \
		$(UV) ansible-playbook playbooks/deploy-stack.yml -e stack=$$s || { \
			echo "❌ Deployment of $$s failed"; exit 1; }; \
	done
	@echo "✅ All stacks deployed successfully."

deploy-all:
	@echo "🚀 Deploying all stacks..."
	$(UV) ansible-playbook playbooks/deploy-all-stacks.yml

check-deploy:
	@echo "🔍 Syntax check..."
	$(UV) ansible-playbook playbooks/deploy-all-stacks.yml --syntax-check
	@echo "✓ Syntax valid"
	@echo ""
	@echo "🔍 Linting..."
	$(UV) ansible-lint playbooks/deploy-all-stacks.yml
	@echo ""
	@echo "🔍 Dry-run (check mode)..."
	$(UV) ansible-playbook playbooks/deploy-all-stacks.yml --check

ping:
	@echo "📡 Pinging all hosts in 'homelab' inventory group..."
	$(UV) ansible homelab -m ping

# --------------------------------------------------------------------------- #
# 🧼 Maintenance
# --------------------------------------------------------------------------- #

clean:
	@echo "🧹 Cleaning project environment..."
	@if [ -d ".venv-container" ]; then \
		echo "🗑️  Removing Python virtual environment..."; \
		rm -rf .venv-container; \
	fi
	@if docker ps -a --format '{{.Names}}' | grep -q 'dev_container'; then \
		echo "🧩 Removing old DevContainer containers..."; \
		docker rm -f $$(docker ps -a -q --filter name=dev_container) 2>/dev/null || true; \
	fi
	@if [ -d "$(BACKUP_DIR)" ]; then \
		echo "🧯 Cleaning up old stack backups..."; \
		find $(BACKUP_DIR) -type f -name '*.bak' -mtime +7 -delete; \
	fi
	@echo "✅ Clean complete."
