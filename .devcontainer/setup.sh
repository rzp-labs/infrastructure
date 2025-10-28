#!/bin/bash
set -e

echo "🚀 Setting up DevContainer system tools..."

# Install uv
echo "📦 Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Install Go
echo "🔧 Installing Go..."
sudo apt-get update
sudo apt-get install -y golang-go

# Install yamlfmt
echo "📝 Installing yamlfmt..."
go install github.com/google/yamlfmt/cmd/yamlfmt@latest

# Install shfmt
echo "🐚 Installing shfmt..."
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Add Go bin to PATH
echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/go/bin:$PATH"

# Fix SSH permissions
echo "🔐 Fixing SSH permissions..."
chmod 700 ~/.ssh 2>/dev/null || true
chmod 600 ~/.ssh/* 2>/dev/null || true

# Now run make setup to install project dependencies
echo ""
echo "📚 Installing project dependencies..."
make setup

# Verify installations
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
echo "  make lint        - Lint code"
echo "  make format      - Format code"
echo "  make ping        - Test VM connectivity"
echo "  make install-docker - Install Docker on VM"
echo "  make deploy stack=<name> - Deploy a stack"
echo ""
