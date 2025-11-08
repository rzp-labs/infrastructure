#!/usr/bin/env bash
# First-time SSH setup for Ansible access to homelab hosts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_DIR="${INFRA_DIR}/.ssh"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"

echo "🔐 SSH Setup for Homelab Access"
echo "================================"
echo ""

# Validate SSH agent forwarding
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "❌ ERROR: SSH agent not forwarded to container"
    echo ""
    echo "Expected: SSH_AUTH_SOCK environment variable set"
    echo "Actual: SSH_AUTH_SOCK is empty"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Ensure 1Password SSH agent is enabled (macOS: Settings → Developer)"
    echo "  2. Restart DevContainer to refresh SSH_AUTH_SOCK forwarding"
    echo "  3. Verify with: echo \$SSH_AUTH_SOCK"
    exit 1
fi

echo "✅ SSH agent detected: ${SSH_AUTH_SOCK}"

# List available keys
echo ""
echo "🔑 Available SSH keys from 1Password:"
ssh-add -l || {
    echo "⚠️  WARNING: No keys found in SSH agent"
    echo "Ensure SSH keys are added to 1Password vault"
}
echo ""

# Create .ssh directory
echo "📁 Creating SSH directory structure..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [ -f "${KNOWN_HOSTS}" ]; then
    echo "✅ Known hosts file exists: ${KNOWN_HOSTS}"
else
    touch "${KNOWN_HOSTS}"
    chmod 600 "${KNOWN_HOSTS}"
    echo "✅ Created known hosts file: ${KNOWN_HOSTS}"
fi
echo ""

# Test connectivity and accept host keys
echo "🏗️  Testing connectivity to homelab hosts..."
echo "You will be prompted to accept SSH host key fingerprints"
echo ""

cd "${INFRA_DIR}"
make ping

echo ""
echo "✅ SSH setup complete!"
echo ""
echo "Next steps:"
echo "  • Deploy infrastructure: make docker-deploy stack=<stack-name>"
echo "  • Run diagnostics: make ssh-test"
