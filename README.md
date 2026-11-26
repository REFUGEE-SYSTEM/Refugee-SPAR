# Refugee-SPAR

Standalone OpenG2P Social Payments Account Registry (SPAR) for the Refugee project.

> **Demo Notice**: All financial addresses, bank codes (`EXAMPLE-BANK`), and account numbers seeded into this stack are **100% fictional**. No real bank, mobile wallet, or payment network is connected.

## Quick Start

```bash
./scripts/init-env.sh
./scripts/up.sh
SEED_FROM_FIXTURE=true ./scripts/seed-demo.sh
./scripts/smoke-test.sh
```

To seed from a live read-only `refugee_registry_db` instead of `fixtures/demo-ids.csv`, set `REGISTRY_RO_DSN` in `.env` (for example `postgresql://pbms_reader:<password>@host.docker.internal:5535/refugee_registry_db`) and run `./scripts/seed-demo.sh`.

## Endpoints & Ports

| Service | Host Port | URL |
|---|---|---|
| SPAR Mapper Partner API | `8390` | `http://localhost:8390/docs` |
| SPAR Beneficiary Portal API | `8391` | `http://localhost:8391/docs` |
| SPAR Postgres (`spardb`) | `5735` | `localhost:5735` |

## Operations

- `./scripts/status.sh` — container status and endpoints
- `./scripts/logs.sh [service]` — tail service logs
- `./scripts/down.sh` — stop containers (preserves `refugee_spar_postgres_data`)
- `./scripts/reset.sh [--yes]` — stop containers and delete `refugee_spar_*` volumes only
