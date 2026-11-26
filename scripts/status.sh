#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/status.sh

Displays container status and HTTP endpoints for Refugee-SPAR.
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

docker compose ps
echo ""
echo "Endpoints:"
echo "  Mapper API:    http://localhost:${SPAR_MAPPER_PORT:-8390}/docs"
echo "  Bene API:      http://localhost:${SPAR_BENE_PORT:-8391}/docs"
echo "  Postgres:      localhost:${SPAR_POSTGRES_PORT:-5735}"
