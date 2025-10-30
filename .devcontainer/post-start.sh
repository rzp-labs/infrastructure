#!/bin/bash
# Description: Container start hook to reconcile optional host integrations
set -euo pipefail

REMOTE_USER=${REMOTE_USER:-vscode}
REMOTE_HOME="/home/${REMOTE_USER}"

SSH_AGENT_SOCKET="${REMOTE_HOME}/.1password/agent.sock"
PROFILE_DIR="${REMOTE_HOME}/.profile.d"
PROFILE_SNIPPET="${PROFILE_DIR}/ssh-agent.sh"

mkdir -p "${PROFILE_DIR}"

if [ -S "${SSH_AGENT_SOCKET}" ]; then
  cat <<'EOF' >"${PROFILE_SNIPPET}"
export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
EOF
  echo "[post-start] 1Password SSH agent detected; sessions will export SSH_AUTH_SOCK."
else
  rm -f "${PROFILE_SNIPPET}"
  echo "[post-start] 1Password SSH agent socket missing; SSH_AUTH_SOCK unset for new shells."
fi

SSH_DIR="${REMOTE_HOME}/.ssh"
if [ -d "${SSH_DIR}" ]; then
  chmod 700 "${SSH_DIR}" || true
  find "${SSH_DIR}" -type f -exec chmod 600 {} + >/dev/null 2>&1 || true
fi
