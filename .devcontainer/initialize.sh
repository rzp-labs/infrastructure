#!/bin/bash
# Description: Pre-build checks executed on the host before creating the Dev Container
set -euo pipefail

WORKSPACE_DIR="$(pwd)"
SSH_DIR="${HOME}/.ssh"
OP_PARENT="${HOME}/Library/Group Containers"
OP_AGENT_DIR="${OP_PARENT}/2BUA8C4S2C.com.1password"

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}" >/dev/null 2>&1 || true

if [ ! -d "${OP_AGENT_DIR}" ]; then
  mkdir -p "${OP_AGENT_DIR}"
  echo "[initialize] Created missing directory: ${OP_AGENT_DIR}"
fi

if [ ! -S "${OP_AGENT_DIR}/agent.sock" ]; then
  echo "[initialize] Notice: 1Password SSH agent socket not detected at ${OP_AGENT_DIR}/agent.sock"
  echo "[initialize] The Dev Container will still start, but SSH_AUTH_SOCK will remain unset until the agent is available."
fi

if [ ! -f "${HOME}/.gitconfig" ]; then
  touch "${HOME}/.gitconfig"
  echo "[initialize] Created empty ${HOME}/.gitconfig so the Dev Container can bind mount it."
fi

if [ ! -d "${WORKSPACE_DIR}" ]; then
  echo "[initialize] Warning: expected workspace directory ${WORKSPACE_DIR} missing."
fi
