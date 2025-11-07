# Conxian Contribution Guide

We maintain a single source of truth for contracts and manifests to keep development simple and consistent.

Canonical layout

- Root Clarinet manifest: `Clarinet.toml`
- Canonical contracts: `contracts/`
- Deployment plans: `deployments/`
- Tests: `tests/` (Vitest, Clarinet SDK)
- Documentation: `documentation/`

Testing and manifests

- Default test runs compile the root manifest (`Clarinet.toml`).
- The `stacks/` directory is for test harnesses only (alternate manifests, mocks). It must reference root contracts and must not contain production logic duplicates.

Traits and interfaces

- Import traits via alias: `(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)`
- Implement traits via alias: `(impl-trait sip-010-ft-trait)`
- Do not use principal-qualified traits; avoid hardcoded ST* principals. Configure external contract principals via admin functions.

Encoding and security

- Use canonical encoding: `sha256(unwrap-panic (to-consensus-buff? payload))`
- MEV protection: commit-reveal and circuit breaker hooks; use admin-set principal for breaker.
- Oracle: centralized dimensional-oracle (oracle-aggregator-v2) naming and interfaces.

Quick start

1) Install Node 18+ and dependencies: `npm install`
2) Run tests: `npm test`
3) Check manifests: `npx clarinet check` (if Clarinet CLI available)
4) Add contracts under `contracts/` and implement traits via alias imports.

Policy checks

- CI runs static scans to catch principal-qualified traits, path-form `impl-trait`, and hardcoded principals.
- Tests publish performance and verification artifacts for benchmarking.

Questions

- See `README.md` Quick Start and `documentation/prd/dimensional-system-prd.md` for architecture and requirements.
