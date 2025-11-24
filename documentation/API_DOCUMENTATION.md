# Conxian Protocol API Documentation

## Overview

The Conxian Protocol provides a comprehensive set of APIs for interacting with its DeFi ecosystem on Stacks. This document outlines all available interfaces, methods, and integration patterns.

## Core Architecture

### Trait-Based Design

The protocol uses a modular trait system where all contracts implement standardized interfaces:

- **SIP Standards**: Token standards (SIP-010, SIP-009)
- **Core Protocol**: Ownership, pausing, RBAC
- **DeFi Primitives**: Pools, routers, concentrated liquidity
- **Dimensional Traits**: Multi-dimensional position management
- **Math Utilities**: Fixed-point arithmetic and financial calculations

## Contract APIs

### Token Contracts

#### CXD Token (Protocol Governance)

```clarity
;; Transfer tokens
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))

;; Get balance
(define-read-only (get-balance (owner principal))

;; Get total supply
(define-read-only (get-total-supply))
```

#### CXLP Token (Liquidity Provider)

```clarity
;; Mint liquidity tokens
(define-public (mint (amount uint) (recipient principal))

;; Burn liquidity tokens
(define-public (burn (amount uint) (owner principal))

;; Get voting power
(define-read-only (get-voting-power (owner principal)))
```

### DEX Contracts

#### Pool Factory

```clarity
;; Create new pool
(define-public (create-pool (token-a principal) (token-b principal) (fee-bps uint))

;; Get existing pool
(define-read-only (get-pool (token-a principal) (token-b principal))

;; List all pools
(define-read-only (get-all-pools))
```

#### Concentrated Liquidity Pool

```clarity
;; Add liquidity
(define-public (mint (recipient principal) (tick-lower int) (tick-upper int) (amount uint))

;; Remove liquidity
(define-public (burn (tokenId uint) (amount uint))

;; Swap tokens
(define-public (swap (recipient principal) (zero-for-one bool) (amountSpecified uint) (sqrtPriceLimit uint))
```

#### Advanced Router (Dijkstra)

```clarity
;; Find optimal swap path
(define-read-only (find-optimal-path (token-in principal) (token-out principal) (amount-in uint))

;; Execute multi-hop swap
(define-public (swap-exact-tokens-for-tokens (amount-in uint) (amount-out-min uint) (path (list 10 principal)) (to principal))
```

### Lending Contracts

#### Comprehensive Lending System

```clarity
;; Deposit collateral
(define-public (deposit (asset principal) (amount uint))

;; Borrow assets
(define-public (borrow (asset principal) (amount uint))

;; Repay loan
(define-public (repay (asset principal) (amount uint))

;; Liquidate position
(define-public (liquidate (borrower principal) (collateral-asset principal) (repay-amount uint))
```

#### Interest Rate Model

```clarity
;; Calculate interest rate
(define-read-only (get-interest-rate (asset principal))

;; Update interest parameters
(define-public (set-rate-params (base-rate uint) (multiplier uint))
```

### Governance Contracts

#### Proposal Engine

```clarity
;; Create proposal
(define-public (create-proposal (title (string-ascii 100)) (description (string-utf8 1000)))

;; Vote on proposal
(define-public (vote (proposal-id uint) (in-favor bool))

;; Execute proposal
(define-public (execute (proposal-id uint))
```

### Oracle Contracts

#### Oracle Aggregator V2

```clarity
;; Get asset price
(define-read-only (get-price (asset principal))

;; Get TWAP (Time-Weighted Average Price)
(define-read-only (get-twap (asset principal) (window uint))

;; Update price feed
(define-public (update-price (asset principal) (price uint) (timestamp uint))
```

## Integration Patterns

### 1. Basic Token Swap

```typescript
import { Clarinet, Tx, types } from '@hirosystems/clarinet-sdk';

async function swapTokens(sender: string, tokenIn: string, tokenOut: string, amount: number) {
  const pool = await Clarinet.getPool(tokenIn, tokenOut);
  const result = await pool.swap({
    sender,
    amountIn: amount,
    amountOutMin: 0, // Accept any amount
    recipient: sender
  });
  return result;
}
```

### 2. Liquidity Provision

```typescript
async function addLiquidity(sender: string, tokenA: string, tokenB: string, amountA: number, amountB: number) {
  const pool = await Clarinet.getPool(tokenA, tokenB);
  const result = await pool.mint({
    sender,
    amountA,
    amountB,
    tickLower: -60720, // 0.1% price range
    tickUpper: 60720,
    recipient: sender
  });
  return result;
}
```

### 3. Lending Operations

```typescript
async function depositCollateral(sender: string, asset: string, amount: number) {
  const lending = await Clarinet.getContract('comprehensive-lending-system');
  const result = await lending.call('deposit', {
    sender,
    asset,
    amount
  });
  return result;
}
```

## Error Handling

### Standard Error Codes

- `u1100`: Unauthorized access
- `u1207`: Zero amount
- `u1307`: Insufficient liquidity
- `u3001`: Invalid tick
- `u5000`: General protocol error

### Response Types

All public functions return `(response <return-type> uint)` where:

- `ok <value>`: Successful operation
- `err <code>`: Error with error code

## Security Considerations

### 1. Access Control

- Use RBAC for permission management
- Validate caller permissions
- Implement rate limiting

### 2. Input Validation

- Validate all input parameters
- Check for overflow/underflow
- Validate price ranges

### 3. Reentrancy Protection

- Use checks-effects-interactions pattern
- Implement reentrancy guards
- Validate state changes

## Rate Limits

### API Limits

- **Read operations**: 100 requests/minute
- **Write operations**: 50 requests/minute
- **Complex operations**: 10 requests/minute

### Gas Optimization

- Batch operations when possible
- Use optimal data structures
- Minimize cross-contract calls

## Monitoring & Analytics

### Event Streaming

```typescript
// Listen to swap events
pool.onEvent('Swap', (event) => {
  console.log(`Swap: ${event.amount0} -> ${event.amount1}`);
});

// Listen to liquidity events
pool.onEvent('Mint', (event) => {
  console.log(`Liquidity added: ${event.amount}`);
});
```

### Performance Metrics

- **TVL (Total Value Locked)**: Track protocol liquidity
- **Volume**: Monitor trading volume
- **APY**: Calculate yield rates
- **Gas Usage**: Optimize transaction costs

## SDK Integration

### JavaScript/TypeScript SDK

```bash
npm install @conxian/protocol-sdk
```

```typescript
import { ConxianProtocol } from '@conxian/protocol-sdk';

const protocol = new ConxianProtocol({
  network: 'testnet',
  nodeUrl: 'https://stacks-node-api.testnet.stacks.co'
});

// Get protocol stats
const stats = await protocol.getStats();
console.log(`TVL: $${stats.tvl}`);
```

### Python SDK

```bash
pip install conxian-protocol
```

```python
from conxian import Protocol

protocol = Protocol(network='testnet')
stats = protocol.get_stats()
print(f"TVL: ${stats.tvl}")
```

## Deployment

### Environment Configuration

```typescript
const config = {
  network: 'mainnet',
  contracts: {
    'comprehensive-lending-system': 'SP1...',
    'dex-factory-v2': 'SP2...',
    'oracle-aggregator-v2': 'SP3...'
  },
  settings: {
    maxGas: 1000000,
    confirmationBlocks: 6
  }
};
```

### Contract Addresses

- **Mainnet**: Published after deployment
- **Testnet**: Available for testing
- **Devnet**: Local development environment

## Support

### Documentation

- [API Reference](./api-reference.md)
- [Integration Guides](./guides/)
- [Examples](./examples/)

### Community

- Discord: [Conxian Protocol](https://discord.gg/conxian)
- GitHub: [Issues & Discussions](https://github.com/Anya-org/Conxian)
- Twitter: [@ConxianProtocol](https://twitter.com/ConxianProtocol)

---

*This documentation is continuously updated. For the latest version, visit [docs.conxian.io](https://docs.conxian.io)*
