#!/bin/bash
# Description: Bootstrap system tools and environment inside DevContainer
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "🚀 Setting up DevContainer system tools..."

# === Fix SSH permissions ===
echo "🔐 Fixing SSH permissions..."
chmod 700 ~/.ssh 2>/dev/null || true
chmod 600 ~/.ssh/* 2>/dev/null || true

# === Install project dependencies ===
echo ""
echo "📚 Installing project dependencies..."
if command -v make &>/dev/null; then
  make setup
else
  echo "⚠️  Skipping make setup (make not found)"
fi

# === Reload updated shell environment ===
if [ -n "${ZSH_VERSION-}" ]; then
  echo "🔄 Reloading Zsh environment..."
  # shellcheck source=/home/vscode/.zshrc disable=SC1091
  source ~/.zshrc
elif [ -n "${BASH_VERSION-}" ]; then
  echo "🔄 Reloading Bash environment..."
  # shellcheck source=/home/vscode/.bashrc disable=SC1091
  source ~/.bashrc
fi

# === Verify installations ===
echo ""
echo "✅ DevContainer ready!"
echo ""
uv run ansible --version | head -1
echo ""
echo "🎯 Quick commands:"
echo "  make lint"
echo "  make format"
echo "  make ping"
echo "  make install-docker"
echo "  make deploy stack=<name>"
echo ""
