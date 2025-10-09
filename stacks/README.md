# Conxian Stacks Smart Contracts

Production-ready smart contracts for the Conxian DeFi platform on
Stacks blockchain.

## Contracts Overview

### Core System (6 contracts)

- `vault.clar` - Share-based asset management with fee controls
- `treasury.clar` - DAO fund management and automated buybacks  
- `dao-governance.clar` - Proposal creation and voting system
- `timelock.clar` - Security delays for critical parameter changes
- `analytics.clar` - Protocol metrics and tracking
- `registry.clar` - System coordination and contract discovery

### Token Economics (4 contracts)

- `cxvg-token.clar` - 10M governance token with voting power
- `cxlp-token.clar` - 5M liquidity token for progressive migration
- `CXVG.clar` - Voting power distribution mechanism
- `creator-token.clar` - Creator incentive alignment system

### Security & Infrastructure (8 contracts)

- `bounty-system.clar` - Merit-based development incentives
- `automated-bounty-system.clar` - Automated bounty processing
- `traits/sip-010-trait.clar` - Standard fungible token interface
- `traits/vault-trait.clar` - Vault interface specification
- `traits/vault-admin-trait.clar` - Administrative interface
- `traits/strategy-trait.clar` - Strategy interface
- `dao.clar` - DAO core functionality
- `mock-ft.clar` - Testing token implementation

### DEX & Advanced (Foundational / Experimental)

- `pool-trait.clar` – Pool trait interface
- `math-lib.clar` – High-precision math primitives (sqrt, fixed-point)
- `dex-factory.clar` – Deterministic pool creation
- `dex-pool.clar` – Constant product AMM baseline
- `dex-router.clar` – Single-hop routing
- `multi-hop-router.clar` – Path-based routing (experimental)
- `stable-pool.clar` – Stable swap invariant prototype
- `weighted-pool.clar` – Weighted pool prototype
- `mock-dex.clar` – Testing harness
- `circuit-breaker.clar` – Volatility / volume / liquidity safeguards
- `enterprise-monitoring.clar` – Structured telemetry & event codes
- `dao-automation.clar` – Automated parameter adjustments

Total tracked contracts (Clarinet): 30

## Requirements

- **Clarinet SDK** (pinned v3.7.0 via npm in root `package.json`)
- **Node.js** (v18+) to run SDK and tests
- **Deno** (optional; required for console features)

## Quick Start

```bash
# From stacks/ directory
npm ci
npx clarinet check
# ✅ 30 contracts checked

npm test
# ✅ 65/65 tests passing

# Start console for testing
npx clarinet console
```

## Basic Usage

### Vault Operations

```clj
;; Deposit assets (using mock-ft for testing)
(contract-call? .mock-ft mint tx-sender u1000000)
(contract-call? .mock-ft approve .vault u500000)
(contract-call? .vault deposit u100000)

;; Check balances
(contract-call? .vault get-balance tx-sender)
(contract-call? .vault get-total-balance)

;; Withdraw with shares
(contract-call? .vault withdraw u20000)
```

### DAO Governance

```clj
;; Create a proposal
(contract-call? .dao-governance create-proposal 
  "Adjust vault fees" 
  "vault" 
  "set-fees" 
  (list u50 u25))

;; Vote on proposal
(contract-call? .dao-governance vote u0 true)
```

### Treasury Management

```clj
;; Check treasury status
(contract-call? .treasury get-treasury-info)

;; Execute buyback (DAO controlled)
(contract-call? .treasury execute-buyback u1000)
```

## Administrative Controls

### Vault Administration

- `set-paused` - Emergency pause mechanism
- `set-global-cap` / `set-user-cap` - Deposit limits
- `set-fees` - Deposit and withdrawal fee basis points
- `set-rate-limit` - Anti-manipulation protection

### Timelock Governance

```clj
;; Queue an admin action
(contract-call? .timelock queue-set-fees u50 u20)

;; Execute after delay
(contract-call? .timelock execute-set-fees u0)
```

## Testing

**Run all tests:**

```bash
npm test
```

**Manual testing:**

```bash
npm run test:manual
```

**Integration testing:**

```bash
npm run int-autonomics
```

## Deployment

**Testnet deployment:**

```bash
npm run deploy-testnet
```

**Contract verification:**

```bash
npm run verify-post
```

**SDK deployment (sequential):**

```bash
DEPLOYER_PRIVKEY=your_testnet_privkey NETWORK=testnet npm run deploy-contracts
```

## Autonomic Economics

The vault includes on-chain controllers for automated parameter adjustments:

- **Utilization-based fees** - Automatic fee adjustment based on vault utilization
- **Reserve management** - Maintains healthy protocol reserves
- **Governance bounds** - All automation respects DAO-defined limits

**Trigger autonomic updates:**

```bash
npm run update-autonomics
```

**Economic simulation:**

```bash
python ../scripts/economic_simulation.py
```

## Testing Architecture

**Test Structure (65 total):**

- **Production Validation** (28)
- **Core Contracts** (13)
- **Security Features** (6)
- **Governance** (3)
- **Infrastructure & Monitoring** (8)
- **Circuit Breaker** (5)
- **DEX Foundations** (2)

## Development Workflow

1. **Write contracts** in `contracts/`
2. **Add tests** in `sdk-tests/`
3. **Run checks** with `npx clarinet check`
4. **Test functionality** with `npm test`
5. **Deploy to testnet** for integration testing

## API Integration

**Read-only calls (Testnet):**

```bash
curl -X POST \
  https://api.testnet.hiro.so/v2/contracts/call-read/ST1234.../vault/\
get-balance \
  -H "Content-Type: application/json" \
  -d '{"sender":"ST1234...","arguments":["0x..."]}'
```

## Security Features

- **Multi-signature treasury** - Requires multiple approvals
- **Emergency pause** - Immediate protocol halt capability
- **Rate limiting** - Protection against manipulation
- **Time delays** - Critical changes require waiting periods
- **Access controls** - Granular permission system

## Next Steps

- Deploy to testnet for integration testing
- Configure timelock as admin for production safety
- Set up automated monitoring and alerts
- Integrate with frontend applications

For complete documentation, see [../documentation/](../documentation/)

### Updated: Aug 17, 2025
