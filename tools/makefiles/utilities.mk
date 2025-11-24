#==============================================================================
# utilities.mk - Cleanup and miscellaneous utilities
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure
#
# Public variables: None
#
# Dependencies: core.mk (uses list_projects)
#==============================================================================

.PHONY: content-scan content-search content-status
.PHONY: synthesize triage
.PHONY: transcript-list transcript-load transcript-search transcript-restore transcript-export
.PHONY: ai-context-files clean-wsl-files workspace-info dot-to-mermaid

# Content Management
content-scan: ## Scan configured content directories for files
	@echo "Scanning content directories..."
	uv run python -m amplifier.content_loader scan

content-search: ## Search content. Usage: make content-search q="your query"
	@if [ -z "$(q)" ]; then \
		echo "Error: Please provide a query. Usage: make content-search q=\"your search query\""; \
		exit 1; \
	fi
	@echo "Searching: $(q)"
	uv run python -m amplifier.content_loader search "$(q)"

content-status: ## Show content statistics
	@echo "Content status:"
	uv run python -m amplifier.content_loader status

# Synthesis Pipeline
synthesize: ## Run the synthesis pipeline. Usage: make synthesize query="..." files="..." [args="..."]
	@if [ -z "$(query)" ] || [ -z "$(files)" ]; then \
		echo "Error: Please provide 'query' and 'files'. Usage: make synthesize query=\"…\" files=\"…\""; \
		exit 1; \
	fi
	uv run python -m amplifier.synthesis.main --query "$(query)" --files "$(files)" $(args)

triage: ## Run only the triage step of the pipeline. Usage: make triage query="..." files="..."
	@if [ -z "$(query)" ] || [ -z "$(files)" ]; then \
		echo "Error: Please provide 'query' and 'files'. Usage: make triage query=\"…\" files=\"…\""; \
		exit 1; \
	fi
	uv run python -m amplifier.synthesis.main --query "$(query)" --files "$(files)" --use-triage

# Transcript Management
transcript-list: ## List available conversation transcripts. Usage: make transcript-list [LAST=10]
	@last="$${LAST:-10}"; \
	python tools/transcript_manager.py list --last $$last

transcript-load: ## Load a specific transcript. Usage: make transcript-load SESSION=id
	@if [ -z "$(SESSION)" ]; then \
		echo "Error: Please provide a session ID. Usage: make transcript-load SESSION=abc123"; \
		exit 1; \
	fi
	@python tools/transcript_manager.py load $(SESSION)

transcript-search: ## Search transcripts for a term. Usage: make transcript-search TERM="your search"
	@if [ -z "$(TERM)" ]; then \
		echo "Error: Please provide a search term. Usage: make transcript-search TERM=\"API\""; \
		exit 1; \
	fi
	@python tools/transcript_manager.py search "$(TERM)"

transcript-restore: ## Restore entire conversation lineage. Usage: make transcript-restore
	@python tools/transcript_manager.py restore

transcript-export: ## Export transcript to file. Usage: make transcript-export SESSION=id [FORMAT=text]
	@if [ -z "$(SESSION)" ]; then \
		echo "Error: Please provide a session ID. Usage: make transcript-export SESSION=abc123"; \
		exit 1; \
	fi
	@format="$${FORMAT:-text}"; \
	python tools/transcript_manager.py export --session-id $(SESSION) --format $$format

# AI Context
ai-context-files: ## Build AI context files
	@echo "Building AI context files..."
	uv run python tools/build_ai_context_files.py
	uv run python tools/build_git_collector_files.py
	@echo "AI context files generated"

# Cleanup
clean-wsl-files: ## Clean up WSL-related files (Zone.Identifier, sec.endpointdlp)
	@echo "Cleaning WSL-related files..."
	@uv run python tools/clean_wsl_files.py

# Workspace info
workspace-info: ## Show workspace information
	@echo ""
	@echo "Workspace"
	@echo "==============="
	@echo ""
	$(call list_projects)
	@echo ""

# DOT to Mermaid Converter
dot-to-mermaid: ## Convert DOT files to Mermaid format. Usage: make dot-to-mermaid INPUT="path/to/dot/files"
	@if [ -z "$(INPUT)" ]; then \
		echo "Error: Please provide an input path. Usage: make dot-to-mermaid INPUT=\"path/to/dot/files\""; \
		exit 1; \
	fi
	@DATA_DIR=$$(python -c "from amplifier.config.paths import paths; print(paths.data_dir)"); \
	SESSION_DIR="$$DATA_DIR/dot_to_mermaid"; \
	mkdir -p "$$SESSION_DIR"; \
	echo "Converting DOT files to Mermaid format..."; \
	uv run python -m ai_working.dot_to_mermaid.cli "$(INPUT)" --session-file "$$SESSION_DIR/session.json"
