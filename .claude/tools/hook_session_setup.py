#!/usr/bin/env python3
"""
SessionStart hook to ensure repository setup before a Claude Code session."""

from __future__ import annotations

import importlib
import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent.parent
TOOLS_DIR = Path(__file__).parent

# Ensure local modules are importable before logging
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(TOOLS_DIR))

HookLogger = importlib.import_module("hook_logger").HookLogger

logger = HookLogger("session_setup")


def _run_repo_command(command: list[str], description: str) -> tuple[bool, str]:
    """Run a repository command and log output."""

    logger.info(f"{description}: {' '.join(command)}")

    try:
        result = subprocess.run(
            command,
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        logger.error(f"{description} failed - command not found: {command[0]}")
        return False, ""

    if result.returncode != 0:
        stderr = result.stderr.strip()
        logger.error(f"{description} failed (exit {result.returncode}): {stderr}")
        return False, result.stdout + result.stderr

    stdout = result.stdout.strip()
    if stdout:
        logger.debug(f"{description} output: {stdout}")
    else:
        logger.debug(f"{description} completed with no output")

    return True, result.stdout


def ensure_submodules(status_messages: list[str]) -> None:
    """Ensure git submodules are initialized and up to date."""

    try:
        status_result = subprocess.run(
            ["git", "submodule", "status", "--recursive"],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        logger.warning("Git executable not found; skipping submodule check")
        return

    if status_result.returncode != 0:
        logger.warning("git submodule status command failed; attempting initialization")
        success, _ = _run_repo_command(
            ["git", "submodule", "update", "--init", "--recursive"],
            "Initialize git submodules",
        )
        if success:
            status_messages.append("Initialized git submodules")
        return

    needs_update = False
    for line in status_result.stdout.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        if stripped[0] in {"-", "+"}:
            needs_update = True
        parts = stripped.split()
        if len(parts) >= 2:
            path = parts[1]
            if not (REPO_ROOT / path).exists():
                needs_update = True

    if needs_update:
        success, _ = _run_repo_command(
            ["git", "submodule", "update", "--init", "--recursive"],
            "Update git submodules",
        )
        if success:
            status_messages.append("Updated git submodules")
    else:
        logger.info("All git submodules are initialized")


def _venv_python_path() -> Path:
    if sys.platform.startswith("win"):
        return REPO_ROOT / ".venv" / "Scripts" / "python.exe"
    return REPO_ROOT / ".venv" / "bin" / "python"


def ensure_environment(status_messages: list[str]) -> None:
    """Ensure the local virtual environment exists."""

    venv_python = _venv_python_path()
    if venv_python.exists():
        logger.info(f"Local virtual environment detected at {venv_python}")
        return

    logger.warning("Virtual environment missing; running 'make install-all'")
    success, _ = _run_repo_command(["make", "install-all"], "Install project dependencies")
    if success:
        status_messages.append("Ran `make install-all` to set up dependencies")


def main() -> None:
    try:
        setup_notes: list[str] = []

        # Consume hook input even if unused (hook protocol requirement)
        raw_input = sys.stdin.read()
        if raw_input:
            try:
                payload = json.loads(raw_input)
                logger.debug(f"Session setup payload keys: {list(payload.keys())}")
            except json.JSONDecodeError:
                logger.warning("Session setup hook received non-JSON input; ignoring")

        ensure_submodules(setup_notes)
        ensure_environment(setup_notes)

        context_sections = []
        if setup_notes:
            context_sections.append("## Environment Setup")
            context_sections.extend(f"- {note}" for note in setup_notes)

        output: dict[str, object] = {}
        if context_sections:
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": "\n".join(context_sections),
                }
            }

        json.dump(output, sys.stdout)

    except Exception as exc:  # noqa: BLE001 - hooks must not crash
        logger.exception("Session setup hook failed", exc)
        json.dump({}, sys.stdout)


if __name__ == "__main__":
    main()
