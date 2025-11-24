#!/bin/bash
# Claude Code Post-Tool-Use Hook
# Pure Delegation Architecture: Path-Based Project Detection
#
# This hook detects which project files were modified and triggers
# appropriate checks using the project's isolated virtual environment.
#
# Architecture: Parent delegates to submodules without importing their code.
# Each project (parent, orchestrator, infrastructure) has its own .venv and
# runs checks independently.

set -euo pipefail

# Tool name and input from Claude Code
TOOL_NAME="${1:-unknown}"
INPUT_JSON="${2:-{}}"

# Log file for debugging
LOG_FILE="/tmp/claude-hook-post-tool-use.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Claude Code Hook: post-tool-use ==="
echo "Tool: $TOOL_NAME"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"

# Extract modified file paths from input JSON
# Note: This extraction logic may need adjustment based on actual Claude Code
# hook protocol. Currently assumes file_path field for Edit/Write tools.
MODIFIED_FILES=$(echo "$INPUT_JSON" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    # Try common field names for file paths
    if 'file_path' in data:
        print(data['file_path'])
    elif 'files' in data:
        for f in data['files']:
            print(f if isinstance(f, str) else f.get('path', ''))
    elif 'path' in data:
        print(data['path'])
except:
    pass
" 2>/dev/null || echo "")

if [ -z "$MODIFIED_FILES" ]; then
    echo "No file paths detected, skipping checks"
    exit 0
fi

echo "Modified files:"
echo "$MODIFIED_FILES" | while read -r file; do
    [ -n "$file" ] && echo "  • $file"
done

# Detect which project was modified
# Pure Delegation: Run checks in the appropriate project's venv
if echo "$MODIFIED_FILES" | grep -q "^orchestrator/"; then
    echo ""
    echo "📦 Orchestrator files modified - running orchestrator checks"
    echo "Delegating to: make -C orchestrator/ check"

    if make -C orchestrator/ check 2>&1; then
        echo "✅ Orchestrator checks passed"
    else
        echo "⚠️  Orchestrator checks failed (see output above)"
    fi

elif echo "$MODIFIED_FILES" | grep -q "^infrastructure/"; then
    echo ""
    echo "📦 Infrastructure files modified - running infrastructure checks"
    echo "Delegating to: make -C infrastructure/ check"

    if make -C infrastructure/ check 2>&1; then
        echo "✅ Infrastructure checks passed"
    else
        echo "⚠️  Infrastructure checks failed (see output above)"
    fi

else
    echo ""
    echo "📦 Parent workspace files modified - running parent checks"
    echo "Running: make check"

    if make check 2>&1; then
        echo "✅ Parent workspace checks passed"
    else
        echo "⚠️  Parent workspace checks failed (see output above)"
    fi
fi

echo "=== Hook complete ==="
