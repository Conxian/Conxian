# Conxian Naming Standards

This document defines the official naming conventions and standards for the
Conxian Protocol token ecosystem **and** its governance / organizational
components. All contracts and documentation must adhere to these standards to
ensure consistency, clarity, and regulatory-friendly terminology.

## 1. Core Protocol Tokens

### CXD - Conxian Revenue Token

* **Symbol**: `CXD`
* **Name**: `Conxian Revenue Token`
* **Type**: SIP-010 Fungible Token
* **Role**: The primary utility and revenue-accruing token of the protocol.
            It captures protocol fees and is used for governance participation.
* **Contract**: `contracts/tokens/cxd-token.clar`

### CXS - Conxian Staking Position

* **Symbol**: `CXS`
* **Name**: `Conxian Staking Position`
* **Type**: SIP-009 Non-Fungible Token (NFT)
* **Role**: Represents a unique staking position within the protocol.
            It tracks user deposits, lock durations, and accrued rewards.
* **Contract**: `contracts/tokens/cxs-token.clar`

### CXLP - Conxian Liquidity Provider Token

* **Symbol**: `CXLP`
* **Name**: `Conxian LP Token`
* **Type**: SIP-010 Fungible Token
* **Role**: Represents a share of a liquidity pool.
            Minted when users deposit assets into a pool and burned upon withdrawal.
* **Contract**: `contracts/tokens/cxlp-token.clar`

### CXTR - Conxian Treasury Token

* **Symbol**: `CXTR`
* **Name**: `Conxian Treasury Token`
* **Type**: SIP-010 Fungible Token
* **Role**: Represents claims on the protocol treasury reserves.
            Used for internal accounting and treasury management.
* **Contract**: `contracts/tokens/cxtr-token.clar`

### CXVG - Conxian Voting Token

* **Symbol**: `CXVG`
* **Name**: `Conxian Voting Token`
* **Type**: SIP-010 Fungible Token
* **Role**: Represents raw voting power derived from staking CXD or other assets.
            Used in the governance module.
* **Contract**: `contracts/tokens/cxvg-token.clar`

## 2. Governance & Organizational Bodies

### 2.1 DAO

* **Official name**: `Conxian Protocol DAO`
* **Description**: The token-holder governed entity that ultimately owns and
  controls the Conxian Protocol. The DAO acts similarly to a traditional
  "shareholder meeting" or general assembly.

### 2.2 Councils & Committees

Conxian uses the terms **Council** and **Committee** for board-like bodies
that oversee specific domains, aligning with DeFi practice and TradFi
governance codes.

Standard councils / committees:

* **Protocol & Strategy Council**  
  Oversees core protocol direction, parameter frameworks, and long-term
  strategy.

* **Risk & Compliance Council**  
  Oversees prudential risk limits, regulatory alignment, and compliance-style
  invariants (LegEx).

* **Treasury & Investment Council**  
  Oversees treasury reserves, investment policies, and capital deployment
  (InvEx / CapEx at policy level).

* **Technology & Security Council**  
  Oversees protocol upgrades, audits, incident response posture, and
  security-critical changes (DevEx + security).

* **Operations & Resilience Council**  
  Oversees day-to-day operational health, incident handling, service budgets,
  and resilience targets (OpEx + operational CapEx).

These names SHOULD be used consistently in:

* Governance documentation.
* Governance NFT metadata (e.g., `council-type`, `council-role`).
* Off-chain board / committee descriptions.

### 2.3 Role & Seat NFTs

Role and governance seats are represented on-chain via NFTs, primarily in
`contracts/governance/enhanced-governance-nft.clar`.

Naming guidelines:

* Use **"Council Membership NFT"** for NFTs representing a seat on a
  particular council (e.g., Operations & Resilience Council member).
* Use **"Reputation Badge"**, **"Delegation Certificate"**, **"Veto
  Certificate"**, and **"Quorum Booster"** consistently with the existing
  `enhanced-governance-nft` contract semantics.
* Where role names appear in metadata, prefer descriptive, TradFi-aligned
  wording such as:
  * `"risk-and-compliance-council-member"`
  * `"treasury-and-investment-council-member"`
  * `"operations-and-resilience-council-member"`

### 2.4 Conxian Automated Operations Seat

Conxian itself has a logically fully automated governance seat that
represents the protocol's metrics and operational engine.

* **Role name**: `Conxian Operations Engine`  
  A council member of the Operations & Resilience Council.
* **Planned contract**: `contracts/governance/conxian-operations-engine.clar`  
  A contract principal that:
  * Reads metrics from risk, treasury, oracle, circuit-breaker, and
    coordination contracts.
  * Aggregates LegEx / DevEx / OpEx / CapEx / InvEx-style inputs into a
    deterministic recommendation.
  * Holds a council membership NFT and casts votes according to its policy.
* **External description**: In documentation and communications, this seat
  SHOULD be described using standard industry language such as "Automated
  Operations & Resilience council member" or "Conxian automated executive
  seat", while the on-chain name remains `Conxian Operations Engine`.

## 3. Contract Naming Conventions

Contract filenames and logical roles SHOULD follow these suffix conventions:

1. **`-engine`**  
   For core decision or execution engines that orchestrate complex flows
   (e.g., `proposal-engine.clar`, `liquidation-engine.clar`,
   `conxian-operations-engine.clar`).

1. **`-controller`**  
   For privileged controllers that gate upgrades, emissions, or other critical
   actions (e.g., `upgrade-controller.clar`, `token-emission-controller.clar`).

1. **`-registry`**  
   For contracts that primarily store and index data (e.g.,
   `proposal-registry.clar`, any future `operations-metrics-registry.clar`).

1. **`-coordinator`**  
   For orchestrators that coordinate across multiple modules or tokens (e.g.,
   `token-system-coordinator.clar`).

1. **`-fund`, `-treasury`, `-vault`**  
   For components that hold or route balances (e.g., `dao-treasury.clar`,
   `conxian-insurance-fund.clar`, any future service payment vaults).

1. **Bodies & roles**  
   Human- or organization-facing governing bodies SHOULD use
   `Council` / `Committee` / `Guardian` / `Steward` naming in docs and NFT
   metadata, mapped to the on-chain contracts and NFTs described above.

## 4. Token Naming Rules

1. **Consistency**: The contract `name` variable must match the official
   name defined in this standard.
1. **Clarity**: Names should be descriptive of the token's function
   (e.g., "Revenue", "Staking Position", "Voting").
1. **Symbols**: Symbols must be 3-4 uppercase letters,
   prefixed with "CX" for Conxian-native assets where possible.
1. **Files**: Contract filenames must match the symbol
   (lowercase) + `-token.clar` (e.g., `cxd-token.clar`).

## 5. Token Naming Implementation Status

* [x] CXD: Name consistent.
* [x] CXS: Name consistent ("Conxian Staking Position").
* [x] CXTR: Name consistent ("Conxian Treasury Token").
* [x] CXLP: Name consistent.
* [x] CXVG: Name consistent.
