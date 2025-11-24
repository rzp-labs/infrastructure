#==============================================================================
# delegation.mk - Recursive delegation patterns
#
# Variable Naming Convention:
# - MODULE_* : Module-private variables (not used in this module)
# - Unprefixed: Shared infrastructure (e.g., MAKE_DIRS)
#
# Public functions:
# - delegate_to_submodules: Helper for -all targets
#
# Dependencies: core.mk (uses MAKE_DIRS)
#==============================================================================

# Pattern: delegate to all submodules
# Usage: $(call delegate_to_submodules,target-name)
define delegate_to_submodules
	@for dir in $(MAKE_DIRS); do \
		echo "→ Running $(1) in $$dir..."; \
		$(MAKE) -C $$dir $(1) || true; \
	done
endef
