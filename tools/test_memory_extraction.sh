#!/bin/bash
# Test runner for memory extraction system
# Run before commits to ensure extraction tests pass

set -euo pipefail

echo "🧪 Running Memory Extraction Test Suite"
echo "========================================"
echo ""

# Activate virtual environment if not already active
if [ -z "${VIRTUAL_ENV:-}" ]; then
    if [ -d ".venv" ]; then
        echo "Activating virtual environment..."
        source .venv/bin/activate
    fi
fi

# Run extraction tests with verbose output
echo "Running extraction unit tests..."
uv run pytest tests/extraction/ -v --tb=short

echo ""
echo "Running extraction integration tests..."
uv run pytest tests/integration/test_memory_extraction.py -v --tb=short

echo ""
echo "✅ All memory extraction tests passed!"
echo ""
echo "Coverage areas verified:"
echo "  ✓ Exception propagation (TimeoutError, JSONDecodeError)"
echo "  ✓ Status reporting and metadata structure"
echo "  ✓ Configuration and environment variables"
echo "  ✓ Message formatting and filtering"
echo "  ✓ End-to-end extraction flow"
echo "  ✓ Storage integration"
echo "  ✓ Error recovery"
