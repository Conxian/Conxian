# Governance Module

Decentralized governance and protocol upgrade management for the Conxian Protocol.

## Status

**Migration Required**: The contracts in this module are not aligned with the protocol's target architecture. They do not currently use the modular trait system and instead rely on hardcoded contract principals, which is a significant security and maintenance risk. A full refactoring is required to align this module with the rest of the protocol.

## Overview

This module provides comprehensive governance functionality including:

- Proposal creation and voting
- Emergency governance mechanisms
- Protocol upgrade management
- Signature verification for governance actions
- Lending protocol governance

## Key Contracts

### Core Governance

- `proposal-engine.clar`: Core proposal and voting system with token-weighted voting
- `proposal-engine-trait.clar`: The trait for the proposal engine.
- `proposal-registry.clar`: A registry for governance proposals.
- `upgrade-controller.clar`: Manages protocol upgrades with timelocks and multi-signature requirements
- `emergency-governance.clar`: Emergency governance for critical protocol issues
- `timelock.clar`: A timelock contract for governance actions.
- `voting.clar`: A contract for voting on proposals.
- `enhanced-governance-nft.clar`: An NFT for enhanced governance features.

### Supporting Infrastructure

- `governance-signature-verifier.clar`: Verifies signatures for governance proposals
- `signed-data-base.clar`: Manages signed data structures for governance
- `lending-protocol-governance.clar`: Specialized governance for lending operations

## Usage

### Creating a Proposal

*Note: The following code is for illustrative purposes only and does not reflect the current implementation.*
```clarity
(contract-call? .proposal-engine propose description targets values signatures calldatas start-block end-block)
```

### Voting on Proposals

*Note: The following code is for illustrative purposes only and does not reflect the current implementation.*
```clarity
(contract-call? .proposal-engine vote proposal-id support votes)
```

### Proposing Contract Upgrades

*Note: The following code is for illustrative purposes only and does not reflect the current implementation.*
```clarity
(contract-call? .upgrade-controller propose-contract-upgrade target-contract new-implementation description)
```

## Security Features

- Multi-signature requirements for critical actions
- Time-locked upgrades with approval windows
- Emergency governance mechanisms
- Signature verification for all governance actions

## Governance Parameters

- **Voting Period**: Configurable block duration (default ~10 days)
- **Quorum Threshold**: Minimum participation required (default 50%)
- **Upgrade Timelock**: Delay before upgrades can be executed
- **Emergency Threshold**: Required approvals for emergency actions
