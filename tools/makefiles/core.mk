#==============================================================================
# core.mk - Foundation variables and utilities
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure (e.g., PYTHON, UV, MAKE_DIRS)
#
# Public variables:
# - MAKE_DIRS: List of submodule directories for recursive targets
#
# Dependencies: None (must be first)
#==============================================================================

# Define submodule directories for recursive targets
# Pure Delegation: Explicit list instead of recursive.mk auto-discovery
MAKE_DIRS :=

# Helper function to list discovered projects
define list_projects
	@echo "Projects discovered: $(words $(MAKE_DIRS))"
	@for dir in $(MAKE_DIRS); do echo "  - $$dir"; done
	@echo ""
endef

.PHONY: list-projects

list-projects: ## List all discovered submodule projects
	$(call list_projects)
