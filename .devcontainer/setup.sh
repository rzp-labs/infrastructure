#!/bin/bash
# Description: Bootstrap system tools and environment inside DevContainer
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"; exit 1' ERR

echo "🚀 Setting up DevContainer system tools..."

# === Install uv ===
echo "📦 Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# === Update PATH in bash/zsh startup files ===
for rc in ~/.bashrc ~/.zshrc; do
  [ -f "$rc" ] || continue
  # shellcheck disable=SC2016  # Keep $HOME and $PATH literal for future shells
  if ! grep -qE '^[[:space:]]*export[[:space:]]+PATH=.*\$HOME/\.local/bin' "$rc" 2>/dev/null; then
    # shellcheck disable=SC2016
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$rc"
  fi
  # shellcheck disable=SC2016
  if ! grep -qE '^[[:space:]]*export[[:space:]]+PATH=.*\$HOME/go/bin' "$rc" 2>/dev/null; then
    # shellcheck disable=SC2016
    echo 'export PATH="$HOME/go/bin:$PATH"' >>"$rc"
  fi
done

# === Install Go and CLI tools ===
echo "🔧 Installing Go and tools..."
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends make golang-go
sudo rm -rf /var/lib/apt/lists/*
go install github.com/google/yamlfmt/cmd/yamlfmt@latest
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# === Fix SSH permissions ===
echo "🔐 Fixing SSH permissions..."
chmod 700 ~/.ssh 2>/dev/null || true
chmod 600 ~/.ssh/* 2>/dev/null || true

# === Configure 1Password SSH agent ===
SSH_AGENT_SOCK="$HOME/.1password/agent.sock"
if [ -S "$SSH_AGENT_SOCK" ]; then
  for rc in ~/.bashrc ~/.zshrc; do
    [ -f "$rc" ] || continue
    # shellcheck disable=SC2016  # Keep $HOME literal for future shells
    if ! grep -qE '^[[:space:]]*export[[:space:]]+SSH_AUTH_SOCK=' "$rc" 2>/dev/null; then
      # shellcheck disable=SC2016
      echo 'export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"' >>"$rc"
    fi
  done
else
  echo "⚠️  Warning: 1Password SSH agent socket not found at $SSH_AGENT_SOCK"
fi

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
echo "Installed system tools:"
uv --version
go version
yamlfmt -version
shfmt -version
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
