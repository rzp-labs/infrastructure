#==============================================================================
# content-generation.mk - Content generation tools (blog, transcribe, illustrate, web-to-md)
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure
#
# Public variables: None
#
# Dependencies: core.mk
#==============================================================================

.PHONY: blog-write blog-resume blog-write-example
.PHONY: tips-synthesizer tips-synthesizer-example
.PHONY: transcribe transcribe-batch transcribe-resume transcribe-index
.PHONY: illustrate illustrate-example illustrate-prompts-only
.PHONY: web-to-md

# Blog Writing
blog-write: ## Create a blog post from your ideas. Usage: make blog-write IDEA=ideas.md WRITINGS=my_writings/ [INSTRUCTIONS="..."]
	@if [ -z "$(IDEA)" ]; then \
		echo "Error: Please provide an idea file. Usage: make blog-write IDEA=ideas.md WRITINGS=my_writings/"; \
		exit 1; \
	fi
	@if [ -z "$(WRITINGS)" ]; then \
		echo "Error: Please provide a writings directory. Usage: make blog-write IDEA=ideas.md WRITINGS=my_writings/"; \
		exit 1; \
	fi
	@echo "🚀 Starting blog post writer..."; \
	echo "  Idea: $(IDEA)"; \
	echo "  Writings: $(WRITINGS)"; \
	if [ -n "$(INSTRUCTIONS)" ]; then echo "  Instructions: $(INSTRUCTIONS)"; fi; \
	echo "  Output: Auto-generated from title in session directory"; \
	if [ -n "$(INSTRUCTIONS)" ]; then \
		uv run python -m scenarios.blog_writer \
			--idea "$(IDEA)" \
			--writings-dir "$(WRITINGS)" \
			--instructions "$(INSTRUCTIONS)"; \
	else \
		uv run python -m scenarios.blog_writer \
			--idea "$(IDEA)" \
			--writings-dir "$(WRITINGS)"; \
	fi

blog-resume: ## Resume an interrupted blog writing session
	@echo "📝 Resuming blog post writer..."
	@uv run python -m scenarios.blog_writer --resume

blog-write-example: ## Run blog writer with example data
	@echo "📝 Running blog writer with example data..."
	@uv run python -m scenarios.blog_writer \
		--idea scenarios/blog_writer/tests/sample_brain_dump.md \
		--writings-dir scenarios/blog_writer/tests/sample_writings/

# Tips Synthesis
tips-synthesizer: ## Synthesize tips from markdown files into cohesive document. Usage: make tips-synthesizer INPUT=tips_dir/ OUTPUT=guide.md [RESUME=true] [VERBOSE=true]
	@if [ -z "$(INPUT)" ]; then \
		echo "Error: Please provide an input directory. Usage: make tips-synthesizer INPUT=tips_dir/ OUTPUT=guide.md"; \
		exit 1; \
	fi
	@if [ -z "$(OUTPUT)" ]; then \
		echo "Error: Please provide an output file. Usage: make tips-synthesizer INPUT=tips_dir/ OUTPUT=guide.md"; \
		exit 1; \
	fi
	@echo "📚 Synthesizing tips from $(INPUT) to $(OUTPUT)"
	@uv run python -m scenarios.tips_synthesizer \
		--input-dir "$(INPUT)" \
		--output-file "$(OUTPUT)" \
		$(if $(RESUME),--resume) \
		$(if $(VERBOSE),--verbose)

tips-synthesizer-example: ## Run tips synthesizer with example data
	@echo "📚 Running tips synthesizer with example data..."
	@uv run python -m scenarios.tips_synthesizer \
		--input-dir scenarios/tips_synthesizer/tests/sample_tips/ \
		--output-file synthesized_tips_example.md \
		--verbose

# Transcription
transcribe: ## Transcribe audio/video files or YouTube URLs. Usage: make transcribe SOURCE="url or file" [NO_ENHANCE=true]
	@if [ -z "$(SOURCE)" ]; then \
		echo "Error: Please provide a source. Usage: make transcribe SOURCE=\"https://youtube.com/watch?v=...\""; \
		echo "   Or: make transcribe SOURCE=\"video.mp4\""; \
		exit 1; \
	fi
	@echo "🎙️ Starting transcription..."; \
	echo "  Source: $(SOURCE)"; \
	if [ "$(NO_ENHANCE)" = "true" ]; then \
		echo "  Enhancement: Disabled"; \
		uv run python -m scenarios.transcribe transcribe "$(SOURCE)" --no-enhance; \
	else \
		echo "  Enhancement: Enabled (summaries and quotes)"; \
		uv run python -m scenarios.transcribe transcribe "$(SOURCE)"; \
	fi

transcribe-batch: ## Transcribe multiple files. Usage: make transcribe-batch SOURCES="file1.mp4 file2.mp4" [NO_ENHANCE=true]
	@if [ -z "$(SOURCES)" ]; then \
		echo "Error: Please provide sources. Usage: make transcribe-batch SOURCES=\"video1.mp4 video2.mp4\""; \
		exit 1; \
	fi
	@echo "🎙️ Starting batch transcription..."; \
	echo "  Sources: $(SOURCES)"; \
	if [ "$(NO_ENHANCE)" = "true" ]; then \
		echo "  Enhancement: Disabled"; \
		uv run python -m scenarios.transcribe transcribe $(SOURCES) --no-enhance; \
	else \
		echo "  Enhancement: Enabled"; \
		uv run python -m scenarios.transcribe transcribe $(SOURCES); \
	fi

transcribe-resume: ## Resume interrupted transcription session
	@echo "🎙️ Resuming transcription..."
	@uv run python -m scenarios.transcribe transcribe --resume

transcribe-index: ## Generate index of all transcripts
	@echo "📑 Generating transcript index..."
	@uv run python -m scenarios.transcribe index

# Article Illustration
illustrate: ## Generate AI illustrations for markdown article. Usage: make illustrate INPUT=article.md [OUTPUT=path] [STYLE="..."] [APIS="..."] [RESUME=true]
	@if [ -z "$(INPUT)" ]; then \
		echo "Error: Please provide an input file. Usage: make illustrate INPUT=article.md"; \
		exit 1; \
	fi
	@echo "🎨 Generating illustrations for article..."
	@echo "  Input: $(INPUT)"
	@if [ -n "$(OUTPUT)" ]; then echo "  Output: $(OUTPUT)"; fi
	@if [ -n "$(STYLE)" ]; then echo "  Style: $(STYLE)"; fi
	@if [ -n "$(APIS)" ]; then echo "  APIs: $(APIS)"; fi
	@if [ -n "$(RESUME)" ]; then echo "  Mode: Resume"; fi
	@echo ""
	@CMD="uv run python -m scenarios.article_illustrator \"$(INPUT)\""; \
	if [ -n "$(OUTPUT)" ]; then CMD="$$CMD --output-dir \"$(OUTPUT)\""; fi; \
	if [ -n "$(STYLE)" ]; then CMD="$$CMD --style \"$(STYLE)\""; fi; \
	if [ -n "$(APIS)" ]; then \
		for api in $(APIS); do \
			CMD="$$CMD --apis $$api"; \
		done; \
	fi; \
	if [ -n "$(RESUME)" ]; then CMD="$$CMD --resume"; fi; \
	eval $$CMD

illustrate-example: ## Run article illustrator with example article
	@echo "🎨 Running article illustrator with example..."
	@uv run python -m scenarios.article_illustrator \
		scenarios/article_illustrator/tests/sample_article.md \
		--max-images 3

illustrate-prompts-only: ## Preview prompts without generating images. Usage: make illustrate-prompts-only INPUT=article.md
	@if [ -z "$(INPUT)" ]; then \
		echo "Error: Please provide an input file. Usage: make illustrate-prompts-only INPUT=article.md"; \
		exit 1; \
	fi
	@echo "🎨 Generating prompts (no images)..."
	@uv run python -m scenarios.article_illustrator "$(INPUT)" --prompts-only

# Web to Markdown
web-to-md: ## Convert web pages to markdown. Usage: make web-to-md URL=https://example.com [URL2=https://another.com] [OUTPUT=path]
	@if [ -z "$(URL)" ]; then \
		echo "Error: Please provide at least one URL. Usage: make web-to-md URL=https://example.com"; \
		exit 1; \
	fi
	@echo "🌐 Converting web page(s) to markdown..."
	@CMD="uv run python -m scenarios.web_to_md --url \"$(URL)\""; \
	if [ -n "$(URL2)" ]; then CMD="$$CMD --url \"$(URL2)\""; fi; \
	if [ -n "$(URL3)" ]; then CMD="$$CMD --url \"$(URL3)\""; fi; \
	if [ -n "$(URL4)" ]; then CMD="$$CMD --url \"$(URL4)\""; fi; \
	if [ -n "$(URL5)" ]; then CMD="$$CMD --url \"$(URL5)\""; fi; \
	if [ -n "$(OUTPUT)" ]; then CMD="$$CMD --output \"$(OUTPUT)\""; fi; \
	eval $$CMD
