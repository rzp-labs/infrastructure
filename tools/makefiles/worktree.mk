#==============================================================================
# worktree.mk - Git worktree management
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure
#
# Note: This module delegates to Python CLI tools which manage paths internally
# via their own configuration. No Makefile variables needed for path management.
#
# Public variables: None
#
# Dependencies: core.mk
#==============================================================================

.PHONY: worktree worktree-rm worktree-rm-force worktree-list worktree-stash
.PHONY: worktree-unstash worktree-adopt worktree-list-stashed

# Git worktree management
worktree: ## Create a git worktree with .data copy. Usage: make worktree feature-name
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a branch name. Usage: make worktree feature-name"; \
		exit 1; \
	fi
	@python tools/create_worktree.py $(filter-out $@,$(MAKECMDGOALS))

worktree-rm: ## Remove a git worktree and delete branch. Usage: make worktree-rm feature-name
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a branch name. Usage: make worktree-rm feature-name"; \
		exit 1; \
	fi
	@python tools/remove_worktree.py "$(filter-out $@,$(MAKECMDGOALS))"

worktree-rm-force: ## Force remove a git worktree (even with changes). Usage: make worktree-rm-force feature-name
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a branch name. Usage: make worktree-rm-force feature-name"; \
		exit 1; \
	fi
	@python tools/remove_worktree.py "$(filter-out $@,$(MAKECMDGOALS))" --force

worktree-list: ## List all git worktrees
	@git worktree list

worktree-stash: ## Hide a worktree from git (keeps directory). Usage: make worktree-stash feature-name
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a worktree name. Usage: make worktree-stash feature-name"; \
		exit 1; \
	fi
	@python tools/worktree_manager.py stash-by-name "$(filter-out $@,$(MAKECMDGOALS))"

worktree-unstash: ## Restore a hidden worktree. Usage: make worktree-unstash feature-name
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a worktree name. Usage: make worktree-unstash feature-name"; \
		exit 1; \
	fi
	@python tools/worktree_manager.py unstash-by-name "$(filter-out $@,$(MAKECMDGOALS))"

worktree-adopt: ## Create worktree from remote branch. Usage: make worktree-adopt branch-name
	@if [ -z "$(filter-out $@,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please provide a branch name. Usage: make worktree-adopt branch-name"; \
		exit 1; \
	fi
	@python tools/worktree_manager.py adopt "$(filter-out $@,$(MAKECMDGOALS))"

worktree-list-stashed: ## List all hidden worktrees
	@python tools/worktree_manager.py list-stashed
