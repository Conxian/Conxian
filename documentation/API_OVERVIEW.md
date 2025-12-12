# Conxian API Overview

This document summarizes all current and planned API surfaces in the Conxian ecosystem, across on-chain smart contracts, deployment tooling, user interfaces, and planned enterprise services.

> **Maturity & Availability (as of 2025-12-06)**
>
> - On-chain APIs (Clarity contracts via Stacks nodes) and StacksOrbit deployment APIs are **usable today on devnet/testnet**.
> - Enterprise REST APIs for compliance, analytics, and audit are **design targets**; no production endpoints are exposed in this repository.

## 1. On-Chain APIs (Clarity Contracts)

The primary, canonical API for the Conxian Protocol is the set of Clarity contracts deployed on the Stacks blockchain.

- **Access pattern**:
  - **ABI discovery**: `GET /v2/contracts/interface/{principal}/{name}` (Hiro Core API).
  - **Read-only calls**: `POST /v2/contracts/call-read/{principal}/{name}/{function-name}` with hex-encoded Clarity arguments.
  - **Public function calls**: Signed transactions via Stacks wallets and SDKs (e.g. `@stacks/transactions`, `@stacks/connect`).
- **Used by**:
  - Conxian Portal (Next.js UI).
  - Internal test harnesses (`tests/` in Conxian repo).
  - External integrators building their own frontends or automation.
- **Documentation**:
  - Contract modules and traits are documented in `documentation/architecture/ARCHITECTURE.md` and `contracts/traits/README-TRAIT-ARCHITECTURE.md`.

## 2. Deployment & Tooling APIs (StacksOrbit)

StacksOrbit provides programmatic deployment APIs in addition to its CLI.

### 2.1 JavaScript API

Documented in `stacksorbit/docs/api.md`:

```javascript
const { StacksOrbit } = require('stacksorbit');

const deployer = new StacksOrbit({
  network: 'testnet',
  privateKey: process.env.DEPLOYER_PRIVKEY,
  systemAddress: process.env.SYSTEM_ADDRESS
});

await deployer.deployAll();
await deployer.deploy(['contract1.clar', 'contract2.clar']);
```

### 2.2 Python API

Also documented in `stacksorbit/docs/api.md`:

```python
from stacksorbit import StacksOrbit

deployer = StacksOrbit(
    network='testnet',
    private_key=os.environ.get('DEPLOYER_PRIVKEY'),
    system_address=os.environ.get('SYSTEM_ADDRESS'),
)

deployer.deploy_all()
deployer.deploy(['contract1.clar', 'contract2.clar'])
```

### 2.3 CLI

The `stacksorbit` CLI and `stacksorbit_cli.py` expose commands for deploy/check/monitor/verify/diagnose. See `README_ENHANCED.md` and `AGENTS.md` in the `stacksorbit` repo for full details.

## 3. Web Application Integration (Conxian Portal)

The Conxian UI uses browser-based integrations with the Stacks ecosystem:

- **Wallet and transactions**: via `@stacks/connect` and Stacks.js.
- **Contract metadata & calls**:
  - ABI fetch: `GET /v2/contracts/interface/{principal}/{name}`.
  - Read-only calls: `POST /v2/contracts/call-read/...`.
- **Configuration**:
  - Core API endpoint chosen via `NEXT_PUBLIC_CORE_API_URL` (see `Conxian_UI/README.md`).

These are **client-side integrations** built on top of the on-chain APIs described in section 1.

## 4. Planned Enterprise REST APIs

Enterprise documents (`COMPLIANCE_SECURITY.md`, `BUSINESS_VALUE_ROI.md`) describe a **target design** for additional REST APIs. These are not yet implemented but are expected to cover at least three domains:

1. **Compliance APIs** (AML/KYC, sanctions, Travel Rule)
2. **User data & privacy APIs** (GDPR exports, erasure)
3. **Risk, analytics, and audit APIs** (portfolio risk, transaction logs, system health)

### 4.1 Example: GDPR Data Export API (Planned)

```http
POST /api/v1/gdpr/export
Authorization: Bearer <token>
Content-Type: application/json

{
  "walletAddress": "SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7"
}
```

**Behavior (target design)**:

- Authenticate and authorize requesting party.
- Aggregate on-chain and off-chain records associated with the wallet.
- Log access in an immutable audit log.
- Return an encrypted, signed bundle of user data.

### 4.2 Example: Audit Events API (Planned)

```http
GET /api/v1/audit/events?from=2025-01-01T00:00:00Z&to=2025-01-31T23:59:59Z&subject=wallet:SP2...
Authorization: Bearer <token>
```

**Behavior (target design)**:

- Filter events (on-chain actions, admin changes, compliance checks) for the given subject and time range.
- Paginate results, with strong access controls and tamper-evident storage.

> These REST API examples are **illustrative** and must not be treated as live endpoints until a concrete implementation, authentication model, and SLA are defined.

## 5. Alignment & Next Steps

- **For engineering**: Use this overview to avoid duplicating API surfaces and to keep new endpoints aligned with the existing on-chain and StacksOrbit interfaces.
- **For sales & marketing**: When describing "enterprise APIs", be explicit whether you are referring to:
  - Current on-chain + deployment APIs, or
  - Planned REST APIs for compliance/analytics that are still in design.
- **For procurement & regulators**: Treat the on-chain and StacksOrbit APIs as the only production-grade interfaces until dedicated REST services are implemented, documented, and covered by formal SLAs.
