# Tokens Module

> **Note:** This `README.md` is aligned with the actual code implementation as of December 2025.

## Status

**Nakamoto Ready**: The contracts in this module are feature-complete and fully integrated with the Conxian modular trait system. They support Stacks Epoch 3.0 fast blocks and Bitcoin finality.

Comprehensive token system for the Conxian Protocol implementing multiple token standards and economic models including SIP-010 fungible tokens, liquidity provider tokens, and governance tokens.

## Overview

The tokens module provides a complete token ecosystem supporting:

- **SIP-010 Fungible Tokens**: Standard-compliant ERC-20 equivalent tokens
- **LP Tokens**: Liquidity provider tokens with staking rewards
- **Governance Tokens**: Voting power and protocol governance
- **Token Economics**: Emission controls, inflation schedules, and economic incentives
- **Price Discovery**: Initial price setting and market making

## Key Contracts

### Core Protocol Tokens

#### CXD Token (`cxd-token.clar`)

- **Primary protocol token** implementing SIP-010 standard (`.defi-traits.sip-010-ft-trait`)
- **Economic incentives** for liquidity providers and stakers
- **Governance voting rights** proportional to holdings
- **Deflationary mechanisms** through protocol fees

#### CXTR Token (`cxtr-token.clar`)

- **Treasury reserve token** for protocol stability
- **Backing for stablecoin operations** in lending protocols
- **Liquidity incentives** for DEX pools
- **Cross-chain bridging** support

#### CXLP Token (`cxlp-token.clar`)

- **Liquidity provider token** representing DEX positions
- **Staking rewards** for providing liquidity
- **Governance voting** in DEX-related decisions
- **NFT-backed positions** with metadata

### Utility Tokens

#### CXVG Token (`cxvg-token.clar`)

- **Governance utility token** for protocol upgrades
- **Voting power delegation** and representation
- **Incentive alignment** between token holders and protocol
- **Long-term value accrual** through governance participation

#### CXS Token (`cxs-token.clar`)

- **Stability token** for lending and borrowing operations
- **Collateral backing** with algorithmic stability mechanisms
- **Interest accrual** for lenders and borrowers
- **Peg maintenance** through arbitrage incentives

### Infrastructure

#### Token System Coordinator (`token-system-coordinator.clar`)

- **Central coordination** of all token operations
- **Cross-token interactions** and transfers
- **Economic parameter management** across the protocol
- **Emergency controls** for token operations

#### Price Initializer (`cxd-price-initializer.clar`)

- **Initial price discovery** for new token launches
- **Fair launch mechanisms** with bonding curves
- **Liquidity bootstrapping** for new tokens
- **Market maker incentives** for price stability

## Token Standards Compliance

### SIP-010 Implementation

All tokens implement the Stacks Improvement Proposal 010 (SIP-010) standard via the `.defi-traits.sip-010-ft-trait` interface.

```clarity
;; SIP-010 Interface
(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
```

## Usage Examples

### Token Transfers

```clarity
;; Transfer CXD tokens
(contract-call? .cxd-token transfer amount sender recipient memo)

;; Transfer LP tokens with staking
(contract-call? .cxlp-token transfer-and-stake amount sender recipient)
```

### Minting New Tokens

```clarity
;; Mint protocol tokens (governance controlled)
(contract-call? .cxd-token mint-to amount recipient)

;; Initialize token price
(contract-call? .cxd-price-initializer initialize-price token initial-price)
```

### Token Economics

```clarity
;; Check token supply
(contract-call? .cxd-token get-total-supply)

;; Get emission schedule
(contract-call? .token-system-coordinator get-current-emission-rate)
```

## Economic Model

### Token Distribution

- **Liquidity Mining**: 40% allocated to DEX liquidity providers
- **Treasury Reserve**: 30% for protocol development and operations
- **Community Governance**: 20% for community voting and incentives
- **Team & Advisors**: 10% with vesting schedules

### Inflation Schedule

- **Initial Supply**: 100 million tokens
- **Annual Inflation**: 5% decreasing to 2% over 4 years
- **Deflationary Pressure**: Protocol fees burned
- **Staking Rewards**: 50% of inflation allocated to stakers

### Governance Rights

- **Proposal Creation**: Minimum 1% of total supply
- **Voting Power**: Proportional to token holdings
- **Delegation**: Support for vote delegation
- **Quorum Requirements**: 10% participation minimum

## Security Features

- **Access Controls**: Role-based permissions for sensitive operations
- **Transfer Restrictions**: Blacklist/whitelist functionality
- **Emergency Pauses**: Circuit breaker mechanisms
- **Audit Compliance**: Comprehensive security audits
- **Upgrade Mechanisms**: Timelocked contract upgrades

## Integration Points

### With DEX Module

- LP token minting and burning
- Staking rewards distribution
- Governance over DEX parameters

### With Governance Module

- Voting power calculation
- Proposal execution permissions
- Treasury management

### With Lending Module

- Collateral token acceptance
- Interest accrual mechanisms
- Liquidation token handling

## Performance Optimizations

- **Batch Operations**: Efficient multi-token transfers
- **Gas Optimization**: Optimized storage patterns
- **Caching**: Frequently accessed data caching
- **Event Logging**: Comprehensive transaction logging
