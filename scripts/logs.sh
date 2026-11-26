#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/logs.sh [service]

Tails logs for all Refugee-SPAR services or a specific service.
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ $# -gt 0 ]]; then
  exec docker compose logs -f --tail=100 "$1"
else
  exec docker compose logs -f --tail=50
fi
