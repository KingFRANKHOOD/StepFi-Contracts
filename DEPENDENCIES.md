# Dependencies Audit — StepFi-Contracts

Last audited: 2026-05-05
Auditor: maintainer
Next scheduled audit: 2026-08-05 (quarterly)

Run audit: `cargo audit`
Run tree: `cargo tree --depth=1`

---

## Audit Summary

| Total | Critical | High | Moderate | Warnings |
|---|---|---|---|---|
| 0 vulnerabilities | 0 | 0 | 0 | 2 (unmaintained) |

**Status: Clean ✅**
No actionable security vulnerabilities. Both warnings are transitive through `soroban-sdk` and cannot be resolved by StepFi — they require Stellar to update the SDK.

---

## Warnings (Unmaintained — Not Actionable) ⚠️

### derivative (2.2.0)
- **Warning:** Unmaintained since June 2024
- **Via:** `ark-ec` → `soroban-env-host` → `soroban-sdk`
- **Action:** None — transitive through Stellar's `soroban-sdk`. Monitor Stellar SDK updates.
- **Advisory:** RUSTSEC-2024-0388

### paste (1.0.15)
- **Warning:** Unmaintained since October 2024
- **Via:** `wasmi_core` → `soroban-wasmi` → `soroban-env-host` → `soroban-sdk`
- **Action:** None — transitive through Stellar's `soroban-sdk`. Monitor Stellar SDK updates.
- **Advisory:** RUSTSEC-2024-0436

---

## Direct Dependencies

| Crate | Version | Purpose | Status |
|---|---|---|---|
| `soroban-sdk` | 22.0.11 | Soroban smart contract SDK — storage, events, auth, cross-contract calls | ✅ Safe |

---

## Workspace Structure

```
StepFi-Contracts (workspace)
├── creditline-contract v1.0.0    # Depends on all 4 contracts below
├── liquidity-pool-contract v1.0.0
├── parameters-contract v1.0.0
├── reputation-contract v1.0.0
└── vendor-registry-contract v1.0.0
```

All 5 contracts share a single `soroban-sdk` dependency via the workspace. No other external crates are directly depended on.

---

## Rules for Adding New Dependencies

Before adding any new crate to any contract:

1. **Justify it** — explain in the PR why the Soroban SDK alone cannot solve the problem
2. **Check maintenance** — the crate must have a commit within the last 12 months
3. **Run `cargo audit`** after adding — zero new vulnerabilities or warnings allowed
4. **Prefer no-std compatible crates** — Soroban contracts compile to WASM, full std is not available
5. **Add to this file** — add the crate to the Direct Dependencies table on the same PR
6. **No crates with known CVEs** — ever

---

## Monitoring

Stellar SDK (`soroban-sdk`) is the only external dependency. Monitor:
- https://github.com/stellar/rs-soroban-sdk/releases for SDK updates
- https://rustsec.org for new advisories on transitive dependencies

When Stellar releases a new `soroban-sdk` version, update all contracts' `Cargo.toml` together:
```toml
soroban-sdk = "X.Y.Z"
```

---

## Quarterly Audit Schedule

| Date | Auditor | Vulnerabilities | Warnings | Action Taken |
|---|---|---|---|---|
| 2026-05-05 | @EmeditWeb | 0 | 2 (unmaintained, not actionable) | Documented — monitor Stellar SDK updates |
| 2026-08-05 | — | — | — | Scheduled |
| 2026-11-05 | — | — | — | Scheduled |