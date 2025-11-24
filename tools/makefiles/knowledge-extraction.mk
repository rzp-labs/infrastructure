#==============================================================================
# knowledge-extraction.mk - Document processing and entity extraction
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure
#
# Note: This module delegates to Python CLI tools which manage paths internally
# via amplifier.config.paths. No Makefile variables needed for path management.
#
# Public variables: None (paths handled by amplifier.config.paths)
#
# Dependencies: core.mk
#==============================================================================

.PHONY: knowledge-sync knowledge-sync-batch knowledge-search knowledge-stats knowledge-export
.PHONY: knowledge-mine knowledge-extract knowledge-events knowledge-events-tail knowledge-events-summary

# Knowledge Extraction Commands
knowledge-sync: ## Extract knowledge from all content files [NOTIFY=true]
	@notify_flag=""; \
	if [ "$$NOTIFY" = "true" ]; then notify_flag="--notify"; fi; \
	echo "Syncing and extracting knowledge from content files..."; \
	uv run python -m amplifier.knowledge_synthesis.cli sync $$notify_flag

knowledge-sync-batch: ## Extract knowledge from next N articles. Usage: make knowledge-sync-batch N=5 [NOTIFY=true]
	@n="$${N:-5}"; \
	notify_flag=""; \
	if [ "$$NOTIFY" = "true" ]; then notify_flag="--notify"; fi; \
	echo "Processing next $$n articles..."; \
	uv run python -m amplifier.knowledge_synthesis.cli sync --max-items $$n $$notify_flag

knowledge-search: ## Search extracted knowledge. Usage: make knowledge-search Q="AI agents"
	@if [ -z "$(Q)" ]; then \
		echo "Error: Please provide a query. Usage: make knowledge-search Q=\"your search\""; \
		exit 1; \
	fi
	@echo "Searching for: $(Q)"
	uv run python -m amplifier.knowledge_synthesis.cli search "$(Q)"

knowledge-stats: ## Show knowledge extraction statistics
	@echo "Knowledge Base Statistics:"
	uv run python -m amplifier.knowledge_synthesis.cli stats

knowledge-export: ## Export all knowledge as JSON or text. Usage: make knowledge-export [FORMAT=json|text]
	@format="$${FORMAT:-text}"; \
	echo "Exporting knowledge as $$format..."; \
	uv run python -m amplifier.knowledge_synthesis.cli export --format $$format

# Legacy command aliases (for backward compatibility)
knowledge-mine: knowledge-sync  ## DEPRECATED: Use knowledge-sync instead
knowledge-extract: knowledge-sync  ## DEPRECATED: Use knowledge-sync instead

# Pipeline Events
knowledge-events: ## Show recent pipeline events. Usage: make knowledge-events [N=50]
	@n="$${N:-50}"; \
	uv run python -m amplifier.knowledge_synthesis.cli events --n $$n

knowledge-events-tail: ## Follow pipeline events (like tail -f). Usage: make knowledge-events-tail [N=20]
	@n="$${N:-20}"; \
	uv run python -m amplifier.knowledge_synthesis.cli events --n $$n --follow

knowledge-events-summary: ## Summarize pipeline events. Usage: make knowledge-events-summary [SCOPE=last|all]
	@scope="$${SCOPE:-last}"; \
	uv run python -m amplifier.knowledge_synthesis.cli events-summary --scope $$scope
