#!/usr/bin/env python3
"""
Claude Code hook for Stop/SubagentStop events - minimal state cleanup only.
Memory extraction is too resource-intensive for hooks and causes crashes.
Reads JSON from stdin, removes state flag, writes JSON to stdout.
"""

import json
import os
import sys
from pathlib import Path

# Import logger from the same directory
sys.path.insert(0, str(Path(__file__).parent))
from hook_logger import HookLogger

logger = HookLogger("stop_hook")


def remove_agent_state_flag() -> None:
    """Remove state flag when agent stops (re-enables boundary enforcement)."""
    try:
        project_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", Path.cwd()))
        flag_file = project_root / ".claude" / "state" / "agent_active"

        if flag_file.exists():
            flag_file.unlink()
            logger.info("Removed agent state flag - boundary enforcement re-enabled")
        else:
            logger.info("No agent state flag found - already clean")
    except Exception as e:
        logger.error(f"Failed to remove agent state flag: {e}")


def main():
    """Minimal hook: just remove state flag and return quickly"""
    try:
        logger.info("SubagentStop hook starting")

        # Read input (required by hook protocol, even if unused)
        _ = sys.stdin.read()

        # Remove agent state flag (re-enable boundary enforcement)
        remove_agent_state_flag()

        # Return empty metadata (no memory extraction in hooks - too slow)
        output = {"metadata": {"stateCleanup": "complete"}}

        logger.info(f"Returning output: {json.dumps(output)}")
        json.dump(output, sys.stdout)
        sys.stdout.flush()  # Ensure output is written immediately

    except Exception as e:
        logger.exception("SubagentStop hook failed")
        # Return valid JSON even on error to prevent Claude Code crash
        output = {"metadata": {"stateCleanup": "error", "error": str(e)}}
        json.dump(output, sys.stdout)
        sys.stdout.flush()


if __name__ == "__main__":
    main()
