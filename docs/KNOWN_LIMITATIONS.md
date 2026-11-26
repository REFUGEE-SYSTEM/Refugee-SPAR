# Known Limitations

1. **Authentication Disabled (Demo Mode)**: `SPAR_MAPPER_PARTNER_API_AUTH_ENABLED=false`, `SPAR_MAPPER_PARTNER_API_JWT_AUTH_ENABLED=false`, and `G2P_SPAR_BENE_PORTAL_API_AUTH_ENABLED=false`. Both APIs accept unauthenticated calls from any host that can reach ports `8390` / `8391`. Run only on a trusted local network.
2. **Fictional Data Only**: All `id_fa_mappings` rows use fictional `EXAMPLE-BANK` / `MAIN` financial addresses. No real bank, mobile wallet, or payment network is connected.
3. **Demo Only**: Intended for local integration testing with `Refugee-G2P-Bridge` and `Refugee-PBMS`.
