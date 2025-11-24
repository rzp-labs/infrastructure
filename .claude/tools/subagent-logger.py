#!/usr/bin/env python3

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from typing import NoReturn

# Try to import centralized path config, fall back to .data if not available
try:
    from amplifier.config.paths import paths
except ImportError:
    paths = None  # type: ignore

# File for debugging hook execution
DEBUG_LOG = Path("/workspaces/rzp-amplifier/.claude/logs/subagent-logger-debug.log")


def debug_log(message: str) -> None:
    """Write debug message to both stderr and file."""
    timestamp = datetime.now().isoformat()
    msg = f"[{timestamp}] {message}\n"
    # Write to stderr
    print(message, file=sys.stderr)
    # Also write to file for persistent debugging
    try:
        with open(DEBUG_LOG, "a") as f:
            f.write(msg)
    except Exception:
        pass  # Don't fail if we can't write debug log


def ensure_log_directory() -> Path:
    """Ensure the log directory exists and return its path."""
    # Use .claude/logs directory for consistency with other Claude Code hooks
    project_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
    log_dir = project_root / ".claude" / "logs" / "subagent-logs"

    log_dir.mkdir(parents=True, exist_ok=True)
    return log_dir


def create_log_entry(data: dict[str, Any]) -> dict[str, Any]:
    """Create a structured log entry from the hook data."""
    tool_input = data.get("tool_input", {})

    return {
        "timestamp": datetime.now().isoformat(),
        "session_id": data.get("session_id"),
        "cwd": data.get("cwd"),
        "subagent_type": tool_input.get("subagent_type"),
        "description": tool_input.get("description"),
        "prompt_length": len(tool_input.get("prompt", "")),
        "prompt": tool_input.get("prompt", ""),  # Store full prompt for debugging
    }


def log_subagent_usage(data: dict[str, Any]) -> None:
    """Log subagent usage to a daily log file."""
    log_dir = ensure_log_directory()

    # Create daily log file
    today = datetime.now().strftime("%Y-%m-%d")
    log_file = log_dir / f"subagent-usage-{today}.jsonl"

    # Create log entry
    log_entry = create_log_entry(data)

    # Append to log file (using JSONL format for easy parsing)
    with open(log_file, "a") as f:
        f.write(json.dumps(log_entry) + "\n")

    # Also create/update a summary file
    update_summary(log_dir, log_entry)


def update_summary(log_dir: Path, log_entry: dict[str, Any]) -> None:
    """Update the summary file with aggregated statistics."""
    summary_file = log_dir / "summary.json"

    # Load existing summary or create new one
    if summary_file.exists():
        with open(summary_file) as f:
            summary = json.load(f)
    else:
        summary = {
            "total_invocations": 0,
            "subagent_counts": {},
            "first_invocation": None,
            "last_invocation": None,
            "sessions": set(),
        }

    # Convert sessions to set if loading from JSON (where it's a list)
    if isinstance(summary.get("sessions"), list):
        summary["sessions"] = set(summary["sessions"])

    # Update summary
    summary["total_invocations"] += 1

    subagent_type = log_entry["subagent_type"]
    if subagent_type:
        summary["subagent_counts"][subagent_type] = summary["subagent_counts"].get(subagent_type, 0) + 1

    if not summary["first_invocation"]:
        summary["first_invocation"] = log_entry["timestamp"]
    summary["last_invocation"] = log_entry["timestamp"]

    if log_entry["session_id"]:
        summary["sessions"].add(log_entry["session_id"])

    # Convert sessions set to list for JSON serialization
    summary_to_save = summary.copy()
    summary_to_save["sessions"] = list(summary["sessions"])
    summary_to_save["unique_sessions"] = len(summary["sessions"])

    # Save updated summary
    with open(summary_file, "w") as f:
        json.dump(summary_to_save, f, indent=2)


def main() -> NoReturn:
    debug_log("=" * 80)
    debug_log("DEBUG: Hook starting")
    try:
        data = json.load(sys.stdin)
        debug_log(f"DEBUG: Parsed JSON input. tool_name={data.get('tool_name')}")
    except json.JSONDecodeError as e:
        # On JSON error, still return valid hook output
        debug_log(f"Warning: Could not parse JSON input: {e}")
        output = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}
        print(json.dumps(output))
        sys.exit(0)

    # Only process if this is a Task tool for subagents
    if data.get("hook_event_name") == "PreToolUse" and data.get("tool_name") == "Task":
        debug_log("DEBUG: Task tool detected, processing...")
        try:
            # Log the subagent usage
            log_subagent_usage(data)
            debug_log("DEBUG: Logged subagent usage")
        except Exception as e:
            # Log error but don't block Claude's operation
            debug_log(f"ERROR: Failed to log subagent usage: {e}")
            import traceback

            debug_log(traceback.format_exc())
    else:
        debug_log(f"DEBUG: Not a Task tool (event={data.get('hook_event_name')}, tool={data.get('tool_name')})")

    # CRITICAL: PreToolUse hooks MUST return JSON output
    output = {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}
    print(json.dumps(output))
    debug_log("DEBUG: Hook complete")
    sys.exit(0)


if __name__ == "__main__":
    main()
