# Architecture

`Refugee-SPAR` is a standalone Docker Compose stack (`COMPOSE_PROJECT_NAME=refugee-spar`) with its own network (`refugee_spar_net`) and volume (`refugee_spar_postgres_data`).

```mermaid
flowchart LR
  Bridge["Refugee-G2P-Bridge"] -->|"POST /mapper/resolve (:8390)"| MapperAPI["spar-mapper-api (:8390)"]
  MapperAPI --> DB[("spardb (Postgres :5735)")]
  BeneAPI["spar-bene-api (:8391)"] --> DB
  Seed["scripts/seed-demo.sh"] -->|"fictional EXAMPLE-BANK FAs"| DB
  Reg[("refugee_registry_db (:5535)")] -.->|"optional read-only SELECT"| Seed
```

## Components
- **Vendored source**: `vendor/spar/{models,mapper-core,mapper-partner-api,bene-portal-api}` (copied from `openg2p-workspace/spar` commit `d47e6af`).
- **Bootstrap (`spar-init`)**: Runs Alembic/SQLAlchemy migrations (`main.py migrate`) and idempotently seeds `strategy` rows (`1`, `2`, `5`) via `docker/spar-init/01-strategies.sql`.
