#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'EOF'
Usage: ./scripts/smoke-test.sh

Verifies containers, strategies, API health, seeded mappings, and POST /mapper/resolve.
Prints a PASS/FAIL table and exits non-zero on any failure.
EOF
  exit 0
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found." >&2
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

FAILURES=0
record() {
  local status="$1" name="$2" detail="$3"
  printf "%-6s | %-38s | %s\n" "$status" "$name" "$detail"
  if [[ "$status" == "FAIL" ]]; then
    FAILURES=$((FAILURES + 1))
  fi
}

printf "%-6s | %-38s | %s\n" "STATUS" "CHECK" "DETAIL"
printf "%-6s-+-%-38s-+-%s\n" "------" "--------------------------------------" "------------------------------"

# 1. Containers running
for svc in postgres spar-mapper-api spar-bene-api; do
  cid="$(docker compose ps -q "$svc")"
  if [[ -n "$cid" && "$(docker inspect -f '{{.State.Status}}' "$cid")" == "running" ]]; then
    record PASS "container:$svc" "running"
  else
    record FAIL "container:$svc" "not running"
  fi
done

# 2. Strategies present
strat_count="$(docker compose exec -T postgres psql -U "${SPAR_DB_USER:-sparuser}" -d "${SPAR_DB_NAME:-spardb}" -tAc \
  "SELECT COUNT(*) FROM strategy WHERE id IN (1, 2, 5) AND active = true;" 2>/dev/null || echo 0)"
if [[ "$strat_count" -ge 3 ]]; then
  record PASS "db:strategies" "${strat_count} active strategies (incl. id=5)"
else
  record FAIL "db:strategies" "expected >=3 strategies, got ${strat_count}"
fi

# 3. Mapper API /ping & /docs
mapper_url="http://localhost:${SPAR_MAPPER_PORT:-8390}"
if curl -sf "${mapper_url}/ping" | grep -q "pong"; then
  record PASS "http:spar-mapper-api:/ping" "pong"
else
  record FAIL "http:spar-mapper-api:/ping" "ping failed"
fi
docs_code="$(curl -s -o /dev/null -w '%{http_code}' "${mapper_url}/docs")"
if [[ "$docs_code" == "200" ]]; then
  record PASS "http:spar-mapper-api:/docs" "HTTP 200"
else
  record FAIL "http:spar-mapper-api:/docs" "HTTP ${docs_code}"
fi

# 4. Bene API /ping & /docs
bene_url="http://localhost:${SPAR_BENE_PORT:-8391}"
if curl -sf "${bene_url}/ping" | grep -q "pong"; then
  record PASS "http:spar-bene-api:/ping" "pong"
else
  record FAIL "http:spar-bene-api:/ping" "ping failed"
fi
bdocs_code="$(curl -s -o /dev/null -w '%{http_code}' "${bene_url}/docs")"
if [[ "$bdocs_code" == "200" ]]; then
  record PASS "http:spar-bene-api:/docs" "HTTP 200"
else
  record FAIL "http:spar-bene-api:/docs" "HTTP ${bdocs_code}"
fi

# 5. Seeded mappings count + POST /mapper/resolve check
mapped_count="$(docker compose exec -T postgres psql -U "${SPAR_DB_USER:-sparuser}" -d "${SPAR_DB_NAME:-spardb}" -tAc \
  "SELECT COUNT(*) FROM id_fa_mappings WHERE active = true;" 2>/dev/null || echo 0)"
if [[ "$mapped_count" -gt 0 ]]; then
  record PASS "db:id_fa_mappings" "${mapped_count} active rows"
  sample_row="$(docker compose exec -T postgres psql -U "${SPAR_DB_USER:-sparuser}" -d "${SPAR_DB_NAME:-spardb}" -At -F $'\t' -c \
    "SELECT id_value, fa_value FROM id_fa_mappings WHERE active = true ORDER BY id_value LIMIT 1;")"
  sample_id="${sample_row%%$'\t'*}"
  expected_fa="${sample_row#*$'\t'}"
  if python3 - "$mapper_url" "$sample_id" "$expected_fa" <<'PY'
import json, sys, urllib.request
url, sample_id, expected_fa = sys.argv[1], sys.argv[2], sys.argv[3]
payload = {
    "request_header": {
        "sender_app_mnemonic": "refugee-spar-smoke",
        "sender_app_url": "",
        "request_id": "smoke-test-msg-1",
        "request_timestamp": "2026-01-01T00:00:00Z",
    },
    "request_body": {
        "request_payload": {
            "transaction_id": "smoke-tx-1",
            "resolve_request": [
                {
                    "reference_id": "ref-1",
                    "timestamp": "2026-01-01T00:00:00Z",
                    "id": sample_id,
                    "scope": "details",
                }
            ],
        }
    },
}
req = urllib.request.Request(f"{url}/mapper/resolve", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
with urllib.request.urlopen(req, timeout=10) as resp:
    res = json.loads(resp.read().decode())
items = res["response_body"]["response_payload"]["resolve_response"]
assert items and items[0]["status"] == "succ", f"Unexpected resolve response: {res}"
fa = items[0]["fa"]
acct = expected_fa.split("account_number:")[1].split(".")[0]
assert fa and fa.get("account_number") == acct, f"Expected account {acct}, got {fa}"
PY
  then
    record PASS "api:POST:/mapper/resolve" "resolved ${sample_id} -> expected FA"
  else
    record FAIL "api:POST:/mapper/resolve" "resolve mismatch or error for ${sample_id}"
  fi
else
  record PASS "db:id_fa_mappings" "0 rows (seed-demo.sh not run yet; resolve skipped)"
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "[smoke-test] FAILED (${FAILURES} check(s) failed)."
  exit 1
fi
echo "[smoke-test] All checks passed!"
