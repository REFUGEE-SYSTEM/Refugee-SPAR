#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/seed-demo.sh

Idempotently seeds FICTIONAL EXAMPLE-BANK financial address mappings into SPAR
id_fa_mappings (strategy_id=5). Sources IDs from:
  - fixtures/demo-ids.csv when SEED_FROM_FIXTURE=true, OR
  - REGISTRY_RO_DSN (read-only SELECT of RECOGNISED_REFUGEE + ACTIVE rows).
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found. Run ./scripts/init-env.sh first." >&2
  exit 1
fi

CLI_SEED_FROM_FIXTURE="${SEED_FROM_FIXTURE:-}"

set -a
# shellcheck disable=SC1091
source .env
set +a

BANK_CODE="${SPAR_BANK_CODE:-EXAMPLE-BANK}"
BRANCH_CODE="${SPAR_BRANCH_CODE:-MAIN}"
USE_FIXTURE="${CLI_SEED_FROM_FIXTURE:-${SEED_FROM_FIXTURE:-false}}"

TMP_ROWS="$(mktemp)"
TMP_SQL="$(mktemp)"
trap 'rm -f "$TMP_ROWS" "$TMP_SQL"' EXIT

if [[ "$USE_FIXTURE" == "true" ]]; then
  echo "[seed-demo] Reading fictional demo IDs from fixtures/demo-ids.csv ..."
  tail -n +2 fixtures/demo-ids.csv | tr ',' '\t' > "$TMP_ROWS"
elif [[ -n "${REGISTRY_RO_DSN:-}" ]]; then
  echo "[seed-demo] Querying RECOGNISED_REFUGEE + ACTIVE IDs via REGISTRY_RO_DSN (read-only) ..."
  docker compose exec -T postgres psql "$REGISTRY_RO_DSN" -At -F $'\t' -c \
    "SELECT internal_record_id, COALESCE(functional_record_id, internal_record_id), COALESCE(first_name, ''), COALESCE(last_name, '')
     FROM g2p_register_refugees
     WHERE legal_status = 'RECOGNISED_REFUGEE' AND record_status = 'ACTIVE'
     ORDER BY internal_record_id;" > "$TMP_ROWS"
else
  echo "ERROR: Set REGISTRY_RO_DSN in .env or run with SEED_FROM_FIXTURE=true." >&2
  exit 1
fi

{
  echo "BEGIN;"
  while IFS=$'\t' read -r internal_id functional_id first_name last_name; do
    [[ -z "$internal_id" ]] && continue
    account_number="${functional_id//-/}"
    fa_value="account_number:${account_number}.branch_code:${BRANCH_CODE}.bank_code:${BANK_CODE}.mobile_number:.email_address:.fa_type:BANK_ACCOUNT"
    full_name="$(printf '%s %s' "$first_name" "$last_name" | sed "s/'/''/g")"
    printf "INSERT INTO id_fa_mappings (id_value, fa_value, name, additional_info, active, created_at, updated_at) VALUES ('%s', '%s', '%s', '[{\"strategy_id\": 5}]'::json, true, NOW(), NOW()) ON CONFLICT (id_value) DO UPDATE SET fa_value = EXCLUDED.fa_value, name = EXCLUDED.name, active = true, updated_at = NOW();\n" \
      "$internal_id" "$fa_value" "$full_name"
  done < "$TMP_ROWS"
  echo "COMMIT;"
} > "$TMP_SQL"

docker compose exec -T postgres psql -v ON_ERROR_STOP=1 \
  -U "${SPAR_DB_USER:-sparuser}" -d "${SPAR_DB_NAME:-spardb}" < "$TMP_SQL" >/dev/null

LINKED="$(docker compose exec -T postgres psql -v ON_ERROR_STOP=1 \
  -U "${SPAR_DB_USER:-sparuser}" -d "${SPAR_DB_NAME:-spardb}" -tAc \
  "SELECT COUNT(*) FROM id_fa_mappings WHERE active = true;")"

echo "[seed-demo] SPAR now has ${LINKED} active fictional ID->FA mappings."
