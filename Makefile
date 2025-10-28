.PHONY: setup lint format install-docker deploy deploy-all

setup:
	uv sync
	uv run ansible-galaxy collection install -r requirements.yml

lint:
	uv run yamllint inventory/ playbooks/ stacks/
	uv run ansible-lint playbooks/
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -d -i 2 -ci -sr scripts/ 2>/dev/null || true; \
	else \
		echo "shfmt not installed - skipping shell formatting check"; \
	fi
	@if command -v yamlfmt >/dev/null 2>&1; then \
		yamlfmt -lint inventory/ playbooks/ stacks/; \
	else \
		echo "yamlfmt not installed - skipping YAML formatting check"; \
	fi

format:
	@echo "Formatting shell scripts..."
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -w -i 2 -ci -sr scripts/ 2>/dev/null || true; \
		echo "✓ Shell scripts formatted"; \
	else \
		echo "shfmt not installed - install with: brew install shfmt"; \
	fi
	@echo "Formatting YAML files..."
	@if command -v yamlfmt >/dev/null 2>&1; then \
		yamlfmt inventory/ playbooks/ stacks/; \
		echo "✓ YAML files formatted"; \
	else \
		echo "yamlfmt not installed - install with: brew install yamlfmt"; \
	fi

install-docker:
	uv run ansible-playbook playbooks/install-docker.yml

deploy:
	@if [ -z "$(stack)" ]; then \
		echo "Usage: make deploy stack=<stack-name>"; \
		exit 1; \
	fi
	uv run ansible-playbook playbooks/deploy-stack.yml -e stack=$(stack)

deploy-all:
	uv run ansible-playbook playbooks/deploy-all-stacks.yml

ping:
	uv run ansible homelab -m ping
