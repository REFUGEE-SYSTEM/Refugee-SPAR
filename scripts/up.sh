#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/up.sh

Starts the standalone Refugee-SPAR stack, runs idempotent DB migrations and
strategy seeding, and starts spar-mapper-api and spar-bene-api.
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "[up] .env not found; running ./scripts/init-env.sh ..."
  ./scripts/init-env.sh
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

echo "[up] Starting SPAR Postgres ..."
docker compose up -d --wait postgres

echo "[up] Running SPAR DB migrations and seeding strategies ..."
docker compose --profile bootstrap run --rm --build spar-init

echo "[up] Building and starting SPAR APIs ..."
docker compose up -d --build --wait

echo "[up] Refugee-SPAR is ready!"
echo "  Mapper API:    http://localhost:${SPAR_MAPPER_PORT:-8390}/docs"
echo "  Bene API:      http://localhost:${SPAR_BENE_PORT:-8391}/docs"
