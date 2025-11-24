#==============================================================================
# knowledge-synthesis.mk - Knowledge pipeline and visualization
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
# Dependencies: core.mk, knowledge-extraction.mk (for full pipeline)
#==============================================================================

.PHONY: knowledge-update knowledge-synthesize knowledge-query
.PHONY: knowledge-graph-build knowledge-graph-update knowledge-graph-stats
.PHONY: knowledge-graph-search knowledge-graph-path knowledge-graph-neighbors
.PHONY: knowledge-graph-tensions knowledge-graph-viz knowledge-graph-export
.PHONY: knowledge-graph-top-predicates

# Knowledge Pipeline Commands
knowledge-update: ## Full pipeline: extract knowledge + synthesize patterns [NOTIFY=true]
	@notify_flag=""; \
	if [ "$$NOTIFY" = "true" ]; then notify_flag="--notify"; fi; \
	echo "🚀 Running full knowledge pipeline..."; \
	echo "Step 1: Extracting knowledge..."; \
	uv run python -m amplifier.knowledge_synthesis.cli sync $$notify_flag; \
	echo ""; \
	echo "Step 2: Synthesizing patterns..."; \
	uv run python -m amplifier.knowledge_synthesis.run_synthesis $$notify_flag; \
	echo ""; \
	echo "✅ Knowledge pipeline complete!"

knowledge-synthesize: ## Find patterns across all extracted knowledge [NOTIFY=true]
	@notify_flag=""; \
	if [ "$$NOTIFY" = "true" ]; then notify_flag="--notify"; fi; \
	echo "🔍 Synthesizing patterns from knowledge base..."; \
	uv run python -m amplifier.knowledge_synthesis.run_synthesis $$notify_flag; \
	echo "✅ Synthesis complete! Results saved to knowledge base"

knowledge-query: ## Query the knowledge base. Usage: make knowledge-query Q="your question"
	@if [ -z "$(Q)" ]; then \
		echo "Error: Please provide a query. Usage: make knowledge-query Q=\"your question\""; \
		exit 1; \
	fi
	@echo "🔍 Querying knowledge base: $(Q)"
	@uv run python -m amplifier.knowledge_synthesis.query "$(Q)"

# Knowledge Graph Commands
## Graph Core Commands
knowledge-graph-build: ## Build/rebuild graph from extractions
	@echo "🔨 Building knowledge graph from extractions..."
	@DATA_DIR=$$(python -c "from amplifier.config.paths import paths; print(paths.data_dir)"); \
	uv run python -m amplifier.knowledge.graph_builder --export-gexf "$$DATA_DIR/knowledge/graph.gexf"
	@echo "✅ Knowledge graph built successfully!"

knowledge-graph-update: ## Incremental update with new extractions
	@echo "🔄 Updating knowledge graph with new extractions..."
	@uv run python -m amplifier.knowledge.graph_updater
	@echo "✅ Knowledge graph updated successfully!"

knowledge-graph-stats: ## Show graph statistics
	@echo "📊 Knowledge Graph Statistics:"
	@uv run python -m amplifier.knowledge.graph_builder --summary --top-concepts 20

## Graph Query Commands
knowledge-graph-search: ## Semantic search in graph. Usage: make knowledge-graph-search Q="AI agents"
	@if [ -z "$(Q)" ]; then \
		echo "Error: Please provide a query. Usage: make knowledge-graph-search Q=\"your search\""; \
		exit 1; \
	fi
	@echo "🔍 Searching knowledge graph for: $(Q)"
	@uv run python -m amplifier.knowledge.graph_search "$(Q)"

knowledge-graph-path: ## Find path between concepts. Usage: make knowledge-graph-path FROM="concept1" TO="concept2"
	@if [ -z "$(FROM)" ] || [ -z "$(TO)" ]; then \
		echo "Error: Please provide FROM and TO concepts. Usage: make knowledge-graph-path FROM=\"concept1\" TO=\"concept2\""; \
		exit 1; \
	fi
	@echo "🛤️ Finding path from '$(FROM)' to '$(TO)'..."
	@uv run python -m amplifier.knowledge.graph_search path "$(FROM)" "$(TO)"

knowledge-graph-neighbors: ## Explore concept neighborhood. Usage: make knowledge-graph-neighbors CONCEPT="AI" [HOPS=2]
	@if [ -z "$(CONCEPT)" ]; then \
		echo "Error: Please provide a concept. Usage: make knowledge-graph-neighbors CONCEPT=\"your concept\""; \
		exit 1; \
	fi
	@hops="$${HOPS:-2}"; \
	echo "🔗 Exploring $$hops-hop neighborhood of '$(CONCEPT)'..."; \
	uv run python -m amplifier.knowledge.graph_search neighbors "$(CONCEPT)" --hops $$hops

## Graph Analysis Commands
knowledge-graph-tensions: ## Find productive contradictions. Usage: make knowledge-graph-tensions [TOP=10]
	@top="$${TOP:-10}"; \
	echo "⚡ Finding top $$top productive tensions..."; \
	uv run python -m amplifier.knowledge.tension_detector --top $$top

knowledge-graph-viz: ## Create interactive visualization. Usage: make knowledge-graph-viz [NODES=50]
	@nodes="$${NODES:-50}"; \
	DATA_DIR=$$(python -c "from amplifier.config.paths import paths; print(paths.data_dir)"); \
	echo "🎨 Creating interactive visualization with $$nodes nodes..."; \
	uv run python -m amplifier.knowledge.graph_visualizer --max-nodes $$nodes --output "$$DATA_DIR/knowledge/graph.html"
	@DATA_DIR=$$(python -c "from amplifier.config.paths import paths; print(paths.data_dir)"); \
	echo "✅ Visualization saved to $$DATA_DIR/knowledge/graph.html"

knowledge-graph-export: ## Export for external tools. Usage: make knowledge-graph-export [FORMAT=gexf]
	@format="$${FORMAT:-gexf}"; \
	DATA_DIR=$$(python -c "from amplifier.config.paths import paths; print(paths.data_dir)"); \
	echo "💾 Exporting knowledge graph as $$format..."; \
	FLAGS=""; \
	if [ -n "$$CLEAN" ]; then \
		FLAGS="$$FLAGS --only-predicate-edges --drop-untype-nodes"; \
	fi; \
	if [ -n "$$ALLOWED_PREDICATES" ]; then \
		FLAGS="$$FLAGS --allowed-predicates \"$$ALLOWED_PREDICATES\""; \
	fi; \
	if [ "$$format" = "gexf" ]; then \
		uv run python -m amplifier.knowledge.graph_builder $$FLAGS --export-gexf "$$DATA_DIR/knowledge/graph.gexf"; \
	elif [ "$$format" = "graphml" ]; then \
		uv run python -m amplifier.knowledge.graph_builder $$FLAGS --export-graphml "$$DATA_DIR/knowledge/graph.graphml"; \
	else \
		echo "Error: Unsupported format $$format. Use gexf or graphml."; \
		exit 1; \
	fi
	@format="$${FORMAT:-gexf}"; \
	DATA_DIR=$$(python -c "from amplifier.config.paths import paths; print(paths.data_dir)"); \
	echo "✅ Graph exported to $$DATA_DIR/knowledge/graph.$$format"

knowledge-graph-top-predicates: ## Show top predicates in the graph
	@n="$${N:-15}"; \
	uv run python -m amplifier.knowledge.graph_builder --top-predicates $$n --top-concepts 0
