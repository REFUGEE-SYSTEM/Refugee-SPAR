#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/init-env.sh

Creates .env from .env.example with a freshly generated random SPAR_DB_PASSWORD
if .env does not already exist. Never overwrites an existing .env.
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  echo "[init-env] .env already exists; leaving it untouched."
  exit 0
fi

SPAR_DB_PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24).replace("-", "A").replace("_", "B"))')"

sed \
  -e "s|^SPAR_DB_PASSWORD=.*|SPAR_DB_PASSWORD=${SPAR_DB_PASSWORD}|" \
  .env.example > .env

chmod 600 .env
echo "[init-env] Created .env with generated secrets."
