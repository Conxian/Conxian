# Conxian Naming Standards

This document defines the official naming conventions and standards for the
Conxian Protocol token ecosystem **and** its governance / organizational
components. All contracts and documentation must adhere to these standards to
ensure consistency, clarity, and regulatory-friendly terminology.

## 1. Normative policy and terminology

**Normative keywords:** MUST, SHOULD, MAY are used as defined in RFC 2119.

### 1.1 One concept, one name

Each distinct concept MUST have a single canonical name used consistently in:

* contracts (file names, contract identifiers, traits)
* tests and scripts
* deployment plans
* documentation

Legacy names MAY appear only in historical discussions (e.g., changelogs) and
SHOULD be explicitly marked as legacy.

### 1.2 Compliance & regulatory language policy

Compliance-related language is permitted as a **capability label**, but MUST NOT
be used as an unqualified claim of legal or regulatory compliance.

Allowed (capability-based):

* "supports KYC status checks"
* "enforces tiered account limits"
* "exposes audit-trail events"
* "integrates policy hooks (when configured)"

Not allowed (unqualified claim):

* "regulatory compliant"
* "OFAC/FATF/GDPR/MiCA/SOC 2 compliant"
* "guarantees AML compliance"

Status labeling:

* Documentation that references compliance-related capabilities MUST include a
  status label.
* Use one of: `Status: Prototype`, `Status: Experimental`,
  `Status: Production-intent`, `Status: Operational`.

## 2. Canonical formatting and file naming rules

### 2.1 Clarity contracts (names, files, and paths)

* Contract names MUST be `kebab-case`.
* Contract file names MUST be `<contract-name>.clar`.
* Contract directories SHOULD be grouped by domain under `contracts/<module>/`.

Breaking-change rule:

* Renaming a contract changes its principal and is a breaking deployment change.
  It MUST be treated as a migration.

Examples:

* `contracts/enterprise/enterprise-facade.clar` -> `enterprise-facade`
* `contracts/tokens/cxd-token.clar` -> `cxd-token`

### 2.2 Clarity identifiers

* Public/private/read-only functions MUST be `kebab-case` and verb-first.
  * Example: `register-account`, `check-kyc-compliance`
* Data vars, maps, tuples SHOULD be `kebab-case`.
  * Example: `enterprise-active`, `contract-owner`, `audit-trail`
* Trait names MUST be `kebab-case` with a `-trait` suffix.
  * Example: `compliance-manager-trait`, `sip-010-ft-trait`
* Error constants SHOULD be `UPPER_SNAKE_CASE`.
  * Example: `ERR_ENTERPRISE_DISABLED`, `ERR_PROTOCOL_PAUSED`

### 2.3 Off-chain naming (TypeScript, Python, YAML/TOML)

* TypeScript files SHOULD be `kebab-case.ts` (`*.test.ts` for tests).
* Python files SHOULD be `snake_case.py`.
* YAML/TOML keys SHOULD be `kebab-case`.
* Contract references in TS/YAML/TOML MUST use the canonical contract name
  string (e.g., `enterprise-facade`).

## 3. Contract role taxonomy (canonical suffixes)

Contract names SHOULD end with a suffix that communicates architectural role:

1. **`-facade`**
   Single on-chain entrypoint that delegates to manager contracts.
   Example: `enterprise-facade`.
1. **`-manager`**
   Single-responsibility stateful component.
   Examples: `compliance-manager`, `institutional-account-manager`,
   `advanced-order-manager`, `enterprise-loan-manager`.
1. **`-hooks`**
   Hook contract called from core flows to enforce optional policy/capabilities.
   Example: `compliance-hooks`.
1. **`-engine`**
   Complex orchestration/state machine.
   Examples: `proposal-engine`, `liquidation-engine`.
1. **`-controller`**
   Privileged gate for upgrades/emissions/critical actions.
   Example: `upgrade-controller`.
1. **`-registry`**
   Primarily indexing/storage.
   Example: `audit-registry`.
1. **`-coordinator`**
   Coordinates across multiple modules.
   Example: `token-system-coordinator`.
1. **`-treasury`, `-vault`, `-fund`**
   Balance holding/routing.
   Examples: `dao-treasury`, `conxian-insurance-fund`.

### 3.1 Enterprise module (canonical entrypoint: Option A)

The canonical on-chain Enterprise entrypoint is:

* `enterprise-facade` -> `contracts/enterprise/enterprise-facade.clar`

The phrase "Enterprise API" MUST be reserved for true off-chain APIs (REST/SDK)
and MUST be explicitly disambiguated (e.g., "off-chain Enterprise API",
`Status: planned`).

Enterprise manager contracts:

* `institutional-account-manager` -> `contracts/enterprise/institutional-account-manager.clar`
* `compliance-manager` -> `contracts/enterprise/compliance-manager.clar`
* `advanced-order-manager` -> `contracts/enterprise/advanced-order-manager.clar`
* `enterprise-loan-manager` -> `contracts/enterprise/enterprise-loan-manager.clar`

Enterprise hook contract:

* `compliance-hooks` -> `contracts/enterprise/compliance-hooks.clar`

## 4. Domain standards and repo-accurate examples

### 4.1 Trait contracts

Traits are deployed as contracts under `contracts/traits/`.

* Trait contract name SHOULD follow `<domain>-traits`.
* Trait usage SHOULD follow `.<domain>-traits.<trait-name>`.

Example:

* `(use-trait compliance-manager .enterprise-traits.compliance-manager-trait)`

### 4.2 Tokens

Symbol and naming rules:

* Symbols MUST be 3-4 uppercase letters.
* Conxian-native assets SHOULD be prefixed with `CX` where possible.
* Token contracts MUST use `-token` in the file name.

Canonical token set:

* **CXD** -> `contracts/tokens/cxd-token.clar` (`Conxian Revenue Token`)
* **CXS** -> `contracts/tokens/cxs-token.clar` (`Conxian Staking Position`)
* **CXLP** -> `contracts/tokens/cxlp-token.clar` (`Conxian LP Token`)
* **CXTR** -> `contracts/tokens/cxtr-token.clar` (`Conxian Treasury Token`)
* **CXVG** -> `contracts/tokens/cxvg-token.clar` (`Conxian Voting Token`)

Related NFT:

* `contracts/tokens/cxlp-position-nft.clar`

### 4.3 Governance bodies and role metadata

* DAO name MUST be `Conxian Protocol DAO`.
* Councils/committees SHOULD use consistent, descriptive names:
  * `Protocol & Strategy Council`
  * `Risk & Compliance Council`
  * `Treasury & Investment Council`
  * `Technology & Security Council`
  * `Operations & Resilience Council`

Metadata slugs SHOULD be `kebab-case`:

* `risk-and-compliance-council-member`
* `operations-and-resilience-council-member`

### 4.4 Deployment plans, Clarinet, and tests

* `Clarinet.toml` identifiers MUST match the contract name.
* Deployment plan `contract-name` MUST match the contract name and file path.
* Tests MUST call canonical contract names (e.g., `enterprise-facade`).

## 5. Token Naming Implementation Status

* [x] CXD: Name consistent.
* [x] CXS: Name consistent ("Conxian Staking Position").
* [x] CXTR: Name consistent ("Conxian Treasury Token").
* [x] CXLP: Name consistent.
* [x] CXVG: Name consistent.
