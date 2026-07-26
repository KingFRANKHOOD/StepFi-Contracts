# Progress Tracker — StepFi-Contracts

Update this file after every completed contract change, fix, or architectural decision. Progress state must reflect the actual deployed and tested state — not the intended state.

---

## Current Phase

**Phase 1 — Contract Infrastructure & Core Fixes**

## Current Goal

`LoanType` and per-installment tracking are in. Next: per-loan grace period (Next Up #4), then vouching contract.

---

## Completed

### Issue #7 — Vendor Approval Flow
- Added `VendorStatus` enum (`Pending`, `Approved`, `Suspended`, `Rejected`) to `types.rs`
- Replaced `active: bool` with `status: VendorStatus` in `VendorInfo`
- `register_vendor()` now sets `status = VendorStatus::Pending` instead of immediately active
- Added `approve_vendor()` (admin-only, requires Pending → Approved)
- Added `suspend_vendor()` (admin-only, any status → Suspended)
- `is_active()` returns `true` only for `Approved` vendors — automatically prevents unapproved/suspended vendors from receiving loans in `creditline-contract`
- Legacy functions (`activate_vendor`, `deactivate_vendor`, `set_vendor_status`) updated to map to new enum
- New error: `VendorNotPending = 10` in `vendor-registry-contract`
- Updated `publish_vendor_status` event to emit `VendorStatus` instead of `bool`
- All vendor-registry tests updated; 7 new tests added (approval flow, non-pending rejection, suspension, re-approval, reentrancy guards for approve/suspend)
- Creditline tests updated to approve vendors after registration
- No changes needed to `creditline-contract/src/lib.rs` — `validate_vendor()` already uses `is_active()` which now checks for `Approved`

### Workspace Cleanup
- Removed dead code: `lp-contract` (superseded by `liquidity-pool-contract`)
- Removed empty placeholder: `adapter-trustless-contract`
- Updated `Cargo.toml` workspace members to reflect 5 active contracts
- Removed `[profile]` sections from individual contract `Cargo.toml` files (profiles belong in workspace root only)

### Renaming
- Renamed `merchant-registry-contract` → `vendor-registry-contract`
- Updated all Rust source references: `merchant_registry_contract` → `vendor_registry_contract`
- Updated all struct names: `MerchantRegistry*` → `VendorRegistry*`
- Updated `Cargo.toml` dependency paths in `creditline-contract`

### Critical Fixes
- Added TTL constants (`PERSISTENT_TTL_THRESHOLD`, `PERSISTENT_TTL_EXTEND_TO`) to `creditline-contract/src/storage.rs`
- Added `upgrade()` function to all 5 contracts: reputation, creditline, liquidity-pool, vendor-registry, parameters
- All 5 contracts build cleanly: `cargo build` passes with zero errors (3 minor unused constant warnings — acceptable)
 - Added numeric `VERSION` instance key, `get_version()` API, and `CONTRACTUPGRADED` event across contracts; added unit tests asserting admin gating and version bump on upgrade

### Deployment
- Created `scripts/deploy-testnet.sh` — full deployment script covering all 5 contracts in correct dependency order
- Script outputs contract IDs and saves to `.env.contracts`

### Documentation
- `README.md` fully rewritten as StepFi-Contracts 

### LoanType + Per-Installment Tracking (creditline-contract)
- Added `LoanType` enum (`Standard`, `LearnerInstallment`) to `types.rs`
- Added `paid: bool` and `paid_at: u64` to `RepaymentInstallment`
- Added `loan_type: LoanType` to `Loan`
- Threaded `loan_type` through `create_loan`, `request_loan`, `build_loan`
- New `repay_installment(borrower, loan_id, installment_index, amount) -> i128`: bounds-checks index, rejects already-paid slots, decrements `remaining_balance`, marks `paid`/`paid_at`, persists, emits `INSTPAID`
- New errors: `InvalidInstallmentIndex = 23`, `InstallmentAlreadyPaid = 24`
- New event: `INSTPAID` via `emit_installment_paid`
- All 93 existing tests updated and passing; 0 failing

### repay_installment Unit Tests
- Added `setup_loan_with_schedule` helper that creates a loan with N equal installments
- `test_repay_installment_happy_path`: pays installment 0, verifies `paid`/`paid_at`, balance decremented, second installment untouched
- `test_repay_installment_double_pay_rejected`: asserts `InstallmentAlreadyPaid` (#24) on second payment of same slot
- `test_repay_installment_out_of_bounds`: asserts `InvalidInstallmentIndex` (#23) for index >= schedule length
- `test_repay_installment_non_borrower_rejected`: asserts `UnauthorizedRepayer` (#14) when caller is not the borrower
- `test_repay_installment_zero_amount_rejected`: asserts `InvalidRepaymentAmount` (#13) for zero payment
- Total tests: 98 (93 existing + 5 new) — all passing

### Issue #6 — Typed Storage Errors
- Removed all `.expect(...)` and bare `.unwrap()` matches from `contracts/*/src/storage.rs`
- Converted storage getters/readers to typed `Result<T, ContractError>` paths while preserving intentional zero/false/default semantics
- Added TTL extension after persistent writes for creditline user indexes/active debt, liquidity-pool LP shares, and vendor-registry vendor/count records
- Added missing `NotInitialized` variants to creditline, parameters, and reputation errors without renumbering existing variants
- Added before-initialize regression coverage across all 5 active contracts using generated `try_*` clients
- Verified with `cargo check --offline`, `cargo build --offline`, `cargo test --offline`, and `cargo clippy --offline -- -D warnings` — 230 passed, 0 failed, 4 ignored

### Issue #4 — Mentor Vouching Contract
- Added `vouching-contract` workspace member with `vouch`, `revoke_vouch`, `get_vouches`, `set_mentor`, and initialization APIs
- Stored verified mentors and mentor/learner vouch records in persistent storage with TTL extension after every persistent write
- Added learner-to-mentor indexing so `get_vouches(learner)` avoids global scans
- Added `MENTORVOUCHED`, `VOUCHREVOKED`, and `MENTORVERIFIED` event helpers using short Soroban event symbols
- Added reputation `add_boost` and `remove_boost` updater-gated APIs for vouching cross-contract calls
- Added mock reputation cross-contract tests covering mentor verification, vouching, revocation, duplicate rejection, unverified mentor rejection, admin rejection, and event emission

---

## In Progress

- None currently.

## Recently Fixed

### Security: Unauthorized `distribute_interest` / `accumulate_interest` (SC-17)
- **Problem:** `distribute_interest()` and `accumulate_interest()` were public mutating functions with no `require_auth()` and no caller restriction. Any funded account could call them with an arbitrary amount, draining the pool's token balance to treasury and merchant fund addresses and inflating the share price so the caller could redeem LP shares for more than deposited.
- **Fix:** Changed both function signatures to accept `creditline: Address` as the first parameter. Added `creditline.require_auth()` as the literal first line and `Self::require_creditline(&env, &creditline)` as the second, matching `receive_repayment()` exactly. Both functions now pull `interest_amount` tokens into the pool via `token_client.transfer()` before any accounting change. Updated doc comments to remove the admin edge-case mention.
- **Internal call site preserved:** `receive_repayment()` still calls `distribute_interest_internal()` directly — it has already pulled funds and validated the caller, so it must not go through the newly guarded public wrappers.
- **Pre-existing bug fixed:** `calculate_withdrawal()` now returns 0 when the pool has no shares, fixing two pre-existing test failures.
- **Files:** `contracts/liquidity-pool-contract/src/lib.rs`, `contracts/liquidity-pool-contract/src/tests.rs`
- **New tests:** 8 new tests (unauthorized caller rejection for both functions, token pull + distribution for both, receive_repayment no-regression, receive_repayment single-distribution regression)
- **Verification:** `cargo check`, `cargo test -p liquidity-pool-contract` (86 passed, 0 failed), `cargo clippy -p liquidity-pool-contract -- -D warnings` (0 warnings)

### Issue #7 — Follow-up: Missing `approve_vendor` in `RealIntegrationCtx::register_vendor`
- Discovered second `register_vendor` helper in `RealIntegrationCtx` (integration test struct, ~line 2390) that only called `register_vendor` without `approve_vendor`
- All integration tests using `RealIntegrationCtx` created loans with `Pending` vendors → `validate_vendor` → `is_active` returned `false` → `VendorNotActive` (#3)
- Added `self.vendor_registry.approve_vendor(&self.admin, vendor)` after registration in `RealIntegrationCtx::register_vendor`

---

## Next Up (In Order)

1. **Learner grace period** — Make `grace_period_seconds` per-loan (not just global via parameters)
2. **Reputation rules** — Update `creditline-contract` to call different reputation adjustments for `LoanType::LearnerInstallment`
3. **Testnet deployment** — Deploy all contracts, capture IDs, add to StepFi-API `.env`
4. **End-to-end validation** — Verify loan lifecycle on testnet via Stellar CLI

---

## Open Questions

- What token is used for loans — native XLM or a USDC anchor? (Affects token contract address in `initialize()`)
- What is the correct `grace_period_seconds` for learner installment loans? (Longer than standard BNPL — possibly 7-14 days per installment)
- Should sponsor pool deposits go through `liquidity-pool-contract` or a new `sponsor-pool-contract`?

---

## Architecture Decisions

- **5 contracts, not 6** — `lp-contract` was dead code, removed. `liquidity-pool-contract` is the canonical LP implementation.
- **Vendor over Merchant** — Renamed to reflect StepFi's learning-focused domain.
- **TTL approach** — Using 60-day threshold / 120-day extension constants. Off-chain indexer is responsible for bumping TTL on active loan entries.
- **Upgrade pattern** — All contracts have `upgrade()` gated by admin `require_auth()`. Admin address is set at `initialize()` and transferable via `set_admin()`.
- **Loan sharding** — 32 shards (`loan_id % 32`) in creditline-contract to distribute persistent storage keys and avoid hot-key contention.
- **Reentrancy** — Boolean `LOCKED` flag in instance storage. Cheaper than mutex, sufficient for Soroban's single-threaded execution model.

---

## Contract Deployment Status

| Contract | Testnet Deployed | Contract ID | Last Deployed |
|---|---|---|---|
| `reputation-contract` | ❌ No | — | — |
| `parameters-contract` | ❌ No | — | — |
| `vendor-registry-contract` | ❌ No | — | — |
| `liquidity-pool-contract` | ❌ No | — | — |
| `creditline-contract` | ❌ No | — | — |

> Update this table after running `scripts/deploy-testnet.sh`

---

## Session Notes

- Always run `cargo build` after any contract change before committing.
- Always run `cargo test` before marking any contract feature complete.
- Never modify storage key structures of a contract that has been deployed — it breaks existing data. Use a migration pattern or deploy a new contract.
- The `creditline-contract` depends on all other contracts — it must be initialized last.
- Do not add new workspace members to `Cargo.toml` without creating the full contract file structure first.
