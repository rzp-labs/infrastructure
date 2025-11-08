#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${INFRA_IDENTITY_FILE:-}" && ! -f "${INFRA_IDENTITY_FILE}" ]]; then
  echo "⚠️  INFRA_IDENTITY_FILE '${INFRA_IDENTITY_FILE}' not found; ignoring." >&2
  unset INFRA_IDENTITY_FILE
fi

exec uv run "$@"
