# Contracts Audit Report

Generated: 2025-09-14

This audit collected all on-disk Clarity contracts, detected which contracts appear in Clarinet manifest path entries, and flagged contracts that define traits in-file or use non-canonical trait principals in tests/docs. The goal: prepare a prioritized plan to canonicalize trait usage, ensure every contract is represented in a manifest for full-system tests, and remove in-file trait definitions.

Summary
- Total files scanned (Clarity & tests): 178 (all `**/*.clar` under the workspace)
- Manifests scanned for `path = "contracts/` entries: multiple (Clarinet.test.toml, Clarinet.lending.toml, Clarinet.simple.toml, Clarinet.enhanced.toml and `stacks/Clarinet.test.toml`)

Top findings

1) All on-disk contracts (selected extract; full list saved below)
- contracts/dex/revenue-distributor.clar
- contracts/dex/vault.clar
- contracts/dex/loan-liquidation-manager.clar
- contracts/dex/sbtc-flash-loan-vault.clar
- contracts/dex/sbtc-flash-loan-extension.clar
- contracts/dex/sbtc-lending-system.clar
- contracts/dex/sbtc-integration.clar
- contracts/dex/sbtc-lending-integration.clar
- contracts/dex/sbtc-bond-integration.clar
- contracts/lib/fixed-point-math.clar
- contracts/lib/math-lib-advanced.clar
- contracts/lib/precision-calculator.clar
- contracts/traits/* (many canonical trait files)
- contracts/tokens/* (cxvg/cxd/cxtr/cxlp/cxs)
- contracts/dimensional/* (tokenized-bond etc.)

(Full 178-file list is recorded in the run history and workspace; see file-search outputs.)

2) Contract paths declared inside Clarinet manifests (examples found)
- `Clarinet.test.toml` includes `contracts/dex/revenue-distributor.clar`, `contracts/dex/token-emission-controller.clar`, `contracts/dex/cxd-staking.clar`, a set of `contracts/tokens/*.clar`, `contracts/dimensional/tokenized-bond.clar`, and multiple trait files under `contracts/traits/*.clar`.
- `Clarinet.lending.toml` included older root paths and has been partially reconciled to `contracts/lib/*` and `contracts/dex/*` (e.g., `contracts/lib/fixed-point-math.clar`, `contracts/dex/loan-liquidation-manager.clar`, `contracts/governance/lending-protocol-governance.clar`, `contracts/dex/enhanced-flash-loan-vault.clar`, `contracts/vault.clar`).
- `stacks/Clarinet.test.toml` includes trait entries like `contracts/traits/sip-010-trait.clar` and `contracts/dimensional/tokenized-bond.clar`.

3) Files that `define-trait` in non-trait locations (need removal or consolidation)
- `contracts/dex/sbtc-flash-loan-vault.clar` — defines `flash-loan-receiver-trait` in-file (duplicate of `contracts/traits/flash-loan-receiver-trait.clar`)
- `contracts/dex/sbtc-flash-loan-extension.clar` — defines `flash-loan-receiver-trait` in-file

Note: canonical trait files are present under `contracts/traits/` (e.g., `flash-loan-receiver-trait.clar`, `vault-trait.clar`, `sip-010-trait.clar`, `staking-trait.clar`, etc.)

4) Non-canonical trait uses in tests/docs (should be normalized to leading-dot manifest keys)
- tests: `tests/tokenomics-unit-tests.clar`, `tests/tokenomics-integration-tests.clar`, `tests/system-validation-tests.clar`, and `tests/enterprise-integration-tests.clar` use quoted principals like `'traits.sip-010-trait.sip-010-trait` or shorthand `sip10`. These must be changed to `(use-trait ft-trait .sip-010-trait)` in test contracts or the test manifest must declare the named key.
- docs: multiple docs contain example `use-trait` snippets that are inconsistent; these are documentation-only but should be corrected where they are used as templates.

5) `use-trait` / `impl-trait` hygiene
- Many implementation contracts already use `(use-trait <alias> .<manifest-key>)` correctly (examples: `revenue-distributor.clar`, `vault.clar`, `sbtc-*` files). Some token contracts use `(impl-trait ft-trait)` appropriately.
- A number of contracts still used quoted principals historically — these are concentrated in tests and legacy docs.

Prioritized next fixes (proposed)
1. Remove duplicate in-file `define-trait` from implementation files (start with `sbtc-flash-loan-vault.clar` and `sbtc-flash-loan-extension.clar`) and replace with canonical `(use-trait ...)` + `(impl-trait ...)` referencing `contracts/traits/flash-loan-receiver-trait.clar` via the manifest key (e.g., `.flash-loan-receiver-trait`).
2. Finish manifest reconciliation: ensure every contract used by system tests is declared in the appropriate Clarinet manifest (test/simple/enhanced/lending). Add missing contracts to `Clarinet.test.toml` to run full-system tests.
3. Normalize tests to use leading-dot trait manifest keys instead of quoted principals (update `tests/*.clar` files).
4. Refactor `contracts/lib/fixed-point-math.clar` to resolve interdependent functions (`sqrt-iter`, `sqrt-fixed`, `geometric-mean`).
5. Run `clarinet check` after each small batch of changes and iterate until 0 errors.

Files flagged for immediate editing
- contracts/dex/sbtc-flash-loan-vault.clar — remove in-file define-trait, add `(use-trait flash-loan-receiver .flash-loan-receiver-trait)` + `(impl-trait flash-loan-receiver)`
- contracts/dex/sbtc-flash-loan-extension.clar — same as above
- tests/tokenomics-unit-tests.clar — replace `'traits.sip-010-trait.sip-010-trait` with `.sip-010-trait` use-trait

Automation suggestion
- Create a small script (Node.js or PowerShell) to:
  1. Parse Clarinet TOML manifests and produce a set of manifest keys -> file paths.
  2. Scan all `contracts/*.clar` and ensure each implementation `use-trait` uses `.manifest-key` that exists. If not, produce a proposed edit.
  3. Produce a PR with batched, safe edits: replace quoted principals in tests/docs with leading-dot forms and remove duplicate `define-trait` blocks.

How I validated
- Collected `**/*.clar` list (178 entries) and grepped repository for `use-trait`, `impl-trait`, `define-trait`, and manifest `path = "contracts/...` entries to find inconsistencies.

Next action (I will perform if you approve)
- Apply Batch B edits: remove duplicate `define-trait` from the two sBTC flash-loan files and add canonical `(use-trait ...)` + `(impl-trait ...)` lines.
- Normalize tests (`tests/*.clar`) to leading-dot trait keys.
- Re-run `clarinet check`, capture output, and continue iterating.

If you approve, I'll start by applying the two sBTC flash-loan edits and then re-run `clarinet check` (I'll retry capturing terminal output until successful).
