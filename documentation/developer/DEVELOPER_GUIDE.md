# Conxian Developer Guide

This guide provides everything you need to develop, test, and deploy
Conxian smart contracts.

> **Note for Institutional Developers:** If you are building on top of our enterprise features, please see our [Enterprise Onboarding Guide](../enterprise/ONBOARDING.md) for more specific information.

## Quick Start

### Prerequisites

- Clarinet SDK v3.8.0 (via root `package.json`) and Clarinet CLI v3.8.0 on PATH
- Node.js (v18+)
- Git for version control

### Setup

```bash
# Clone repository
git clone https://github.com/Anya-org/Conxian.git
cd Conxian

# Install dependencies
npm ci

# Verify setup
clarinet check   # ✅ 65+ contracts (syntax validation)
npx vitest run --config ./vitest.config.enhanced.ts   # 🔄 Framework tests
```

## Access Control Implementation

Conxian uses a robust Role-Based Access Control (RBAC) system to manage permissions across the protocol. The implementation follows the OpenZeppelin AccessControl pattern with additional features for DeFi security.

### Key Features

- **Role-Based Permissions**: Granular control over contract functions
- **Emergency Pause**: Ability to pause critical operations
- **Multi-signature Support**: For sensitive operations
- **Time-Delayed Changes**: For critical role modifications
- **Event Logging**: Comprehensive audit trail

### Available Roles

- **DEFAULT_ADMIN_ROLE**: Full system access and role management
- **EMERGENCY_ROLE**: Can pause/unpause the system
- **OPERATOR_ROLE**: Day-to-day operations
- **GOVERNANCE_ROLE**: Protocol parameter updates

### Usage Example

```typescript
// Granting a role
const grantTx = await simnet.callPublicFn(
  'access-control',
  'grant-role',
  [
    Cl.buffer(hexToBuffer(ROLES.OPERATOR)),
    Cl.principal(operatorAddress)
  ],
  adminAddress
);

// Checking a role
const hasRole = await simnet.callReadOnlyFn(
  'access-control',
  'has-role',
  [
    Cl.buffer(hexToBuffer(ROLES.OPERATOR)),
    Cl.principal(operatorAddress)
  ],
  adminAddress
);
```

## Project Structure

```text
Conxian/
├── contracts/                  # Smart contract source files
├── stacks/sdk-tests/           # TypeScript test files
├── documentation/              # Project documentation
├── settings/                   # Network configs (Testnet.toml)
├── .github/workflows/          # CI/CD workflows
├── Clarinet.toml               # Project configuration (root)
├── package.json                # Node.js scripts and dependencies
├── vitest.config.enhanced.ts   # Test configuration
└── bin/                        # Binary tools
```

## Development Workflow

### 1. Access Control Integration

When developing new contracts, follow these patterns for access control:

1. **Import Access Control**
   ```clarity
   (use-trait access-control-trait .access-control.access-control-trait)
   ```

2. **Define Required Roles**
   ```clarity
   (define-constant ROLE_OPERATOR 0x4f50455241544f52)  // "OPERATOR" in hex
   ```

3. **Add Access Control Checks**
   ```clarity
   (define-public (protected-function)
     (begin
       (try! (contract-call? .access-control has-role ROLE_OPERATOR (as-contract tx-sender)))
       ;; Function logic here
     )
   )
   ```

### 2. Smart Contract Development

#### Creating a New Contract

```bash
cd stacks/contracts
# Create new contract file
touch my-contract.clar

# Add to Clarinet.toml
vim ../Clarinet.toml
```

#### Contract Template

```clarity
;; my-contract.clar
;; Description: Brief description of contract functionality

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u1))

;; Data variables
(define-data-var counter uint u0)

;; Public functions
(define-public (increment)
  (begin
    (var-set counter (+ (var-get counter) u1))
    (ok (var-get counter))
  )
)

;; Read-only functions  
(define-read-only (get-counter)
  (var-get counter)
)
```

#### Best Practices

- **Use descriptive names** for functions and variables
- **Include comprehensive error handling** with descriptive error codes
- **Add detailed comments** explaining complex logic
- **Follow naming conventions**: kebab-case for functions, UPPER_CASE for constants
- **Implement proper access controls** for admin functions

### 2. Testing

#### Test Structure

```typescript
// sdk-tests/my-contract.spec.ts
import { describe, expect, it, beforeEach } from 'vitest';
import { Simnet } from '@hirosystems/clarinet-sdk';

describe('My Contract Tests', () => {
  let simnet: Simnet;
  let accounts: Map<string, string>;

  beforeEach(async () => {
    simnet = await Simnet.fromFile('Clarinet.toml');
    accounts = simnet.getAccounts();
  });

  it('should increment counter', () => {
    const result = simnet.callPublicFn(
      'my-contract',
      'increment',
      [],
      accounts.get('deployer')!
    );
    
    expect(result.result).toBeOk();
    expect(result.result.value).toBe(1);
  });
});
```

#### Running Tests

```bash
# Run all tests
npm test

# Run specific test file
npm test -- my-contract.spec.ts

# Run tests with coverage
npm run test:coverage

# Run tests in watch mode
npm run test:watch
```

#### Test Categories

- **Unit Tests**: Individual contract function testing
- **Integration Tests**: Cross-contract interaction testing
- **Production Tests**: End-to-end system validation
- **Security Tests**: Vulnerability and attack vector testing

### 3. Contract Compilation

```bash
# Check all contracts
npx clarinet check

# Check specific contract
npx clarinet check --contract my-contract

# Format contracts
npx clarinet format

# Generate documentation
npx clarinet docs
```

## Nakamoto Development Guide

### Nakamoto Timing Considerations

**Fast Block Development**: Nakamoto introduces 3-5 second block times. The `nakamoto-compatibility.clar` contract provides timing conversion functions:

```typescript
// Test timing constants from nakamoto-compatibility.clar
const NAKAMOTO_BLOCKS_PER_HOUR = 720;  // 5s blocks
const NAKAMOTO_BLOCKS_PER_DAY = 17280;
const LEGACY_BLOCKS_PER_DAY = 144;     // 10min blocks

// Use contract conversion function
const conversionResult = simnet.callReadOnlyFn(
  'nakamoto-compatibility',
  'convert-legacy-to-nakamoto',
  [Cl.uint(144)], // 1 day in legacy blocks
  deployer
);
expected(conversionResult.result).toBe(Cl.uint(17280));
```

**Bitcoin Finality Integration**:

```typescript
// Test Bitcoin finality functions (implemented in nakamoto-compatibility.clar)
const result = simnet.callReadOnlyFn(
  'nakamoto-compatibility',
  'is-bitcoin-finalized',
  [Cl.uint(blockHeight - 100)],
  deployer
);

// Function uses caching and validation logic
expect(result.result).toBe(Cl.bool(true));
```

**MEV Protection Testing**:

```typescript
// Test MEV protection mechanisms (basic framework in nakamoto-compatibility.clar)
const protectionResult = simnet.callPublicFn(
  'nakamoto-compatibility',
  'enable-mev-protection',
  [],
  deployer // Admin function
);

expect(protectionResult.result).toBeOk();
```

## Testing Framework

### Test Environment Setup

```typescript
// Test setup with Simnet
import { Simnet } from '@hirosystems/clarinet-sdk';
import { Cl } from '@stacks/transactions';

// Initialize test environment
const simnet = await Simnet.fromFile('Clarinet.toml');
const accounts = simnet.getAccounts();
const deployer = accounts.get('deployer')!;
const user1 = accounts.get('wallet_1')!;
```

### Nakamoto Testing Patterns

#### Testing Fast Block Functions

```typescript
// Test epoch calculations with Nakamoto timing
const epochResult = simnet.callReadOnlyFn(
  'nakamoto-compatibility',
  'get-nakamoto-epoch-length',
  [],
  deployer
);

expect(epochResult.result).toBe(Cl.uint(120960)); // 1 week in Nakamoto blocks
```

#### Testing Bitcoin Finality

```typescript
// Test finality-dependent operations (framework implementation)
const finalityResult = simnet.callReadOnlyFn(
  'nakamoto-compatibility',
  'is-bitcoin-finalized',
  [Cl.uint(simnet.blockHeight - 10)],
  deployer
);

// Basic finality detection with caching
expected(finalityResult.result).toBe(Cl.bool(true));
```

#### Testing Cross-Chain Operations

```typescript
// Test Wormhole bridge functionality (development framework - events only)
const bridgeResult = simnet.callPublicFn(
  'wormhole-integration',
  'initiate-bridge-transfer',
  [
    Cl.contractPrincipal(deployer, 'test-token'),
    Cl.uint(1000000),
    Cl.uint(2), // Ethereum (framework only)
    Cl.bufferFromHex('0x742d35cc6548c63e02e4286d82bae9b8feff4bc8')
  ],
  user1
);

// Returns sequence number and fee (event emission framework)
expected(bridgeResult.result).toBeOk();
```

### Common Test Patterns

#### Testing Public Functions

```typescript
const result = simnet.callPublicFn(
  'contract-name',
  'function-name',
  [Cl.uint(100), Cl.stringAscii('test')],
  deployer
);

expect(result.result).toBeOk();
```

#### Testing Read-Only Functions

```typescript
const result = simnet.callReadOnlyFn(
  'contract-name',
  'read-function',
  [Cl.principal(user1)],
  deployer
);

expect(result.result.type).toBe('uint');
```

#### Testing Error Conditions

```typescript
const result = simnet.callPublicFn(
  'contract-name',
  'restricted-function',
  [],
  user1 // Non-admin user
);

expect(result.result).toBeErr();
expect(result.result.value).toBe(Cl.uint(1)); // ERR_UNAUTHORIZED
```

### Mock Data and Fixtures

```typescript
// Test fixtures
const testUsers = [
  { address: deployer, name: 'deployer' },
  { address: user1, name: 'user1' }
];

const testAmounts = [
  1000n,    // Small amount
  100000n,  // Medium amount  
  10000000n // Large amount
];
```

## 🚀 Deployment

### Local Development

```bash
# Start local blockchain
npx clarinet devnet start

# Deploy contracts locally
npx clarinet devnet deploy

# Interact with contracts
npx clarinet console
```

### Testnet Deployment

```bash
# Configure testnet settings in Clarinet.toml
[network.testnet]
node_rpc_api = "https://stacks-node-api.testnet.stacks.co"

# Deploy to testnet
npx clarinet deploy --testnet

# Verify deployment
npx clarinet deployment describe --testnet
```

### Mainnet Deployment

```bash
# Configure mainnet settings
[network.mainnet]
node_rpc_api = "https://stacks-node-api.mainnet.stacks.co"

# Deploy to mainnet (requires careful preparation)
npx clarinet deploy --mainnet

# Monitor deployment
npx clarinet deployment status --mainnet
```

## Debugging

### Common Issues

#### Contract Compilation Errors

```bash
# Check syntax errors
npx clarinet check --contract problematic-contract --sdk-version 3.7.0

# View detailed error messages
npx clarinet check --verbose --sdk-version 3.7.0
npx clarinet check --verbose
```

#### Test Failures

```bash
# Run tests with detailed output
npm test -- --reporter=verbose

# Debug specific test
npm test -- --grep "failing test name"

# Check simnet state
console.log(simnet.getBlockHeight());
console.log(simnet.getAssetsMap());
```

#### Deployment Issues

```bash
# Check network connectivity
npx clarinet network status

# Verify account balances
npx clarinet accounts

# Check transaction status
npx clarinet tx status <tx-id>
```

### Debugging Tools

- **Clarinet Console**: Interactive contract testing
- **Simnet Inspector**: Test blockchain state examination
- **Transaction Tracer**: Step-by-step execution analysis
- **Error Logging**: Comprehensive error reporting

## 📚 Code Standards

### Clarity Style Guide

```clarity
;; Constants (UPPER_CASE)
(define-constant MAX_SUPPLY u1000000)

;; Data variables (kebab-case)
(define-data-var total-supply uint u0)

;; Functions (kebab-case)
(define-public (mint-tokens (amount uint))
  ;; Function implementation
)

;; Error codes (descriptive)
(define-constant ERR_INSUFFICIENT_BALANCE (err u100))
(define-constant ERR_UNAUTHORIZED_MINT (err u101))
```

### TypeScript Style Guide

```typescript
// Use descriptive variable names
const deployerAddress = accounts.get('deployer')!;

// Use type annotations
const amount: bigint = 1000n;

// Use async/await for async operations
const result = await simnet.callPublicFn(...);

// Use consistent naming
describe('Vault Contract Tests', () => {
  it('should handle deposits correctly', () => {
    // Test implementation
  });
});
```

### Documentation Standards

- **Function Documentation**: Clear description, parameters, return values
- **Error Documentation**: All error codes documented with explanations
- **Example Usage**: Practical examples for each public function
- **Architecture Documentation**: High-level system design explanations

## 🤝 Contributing

### Development Process

1. **Fork Repository**: Create your own fork
2. **Create Branch**: `git checkout -b feature/new-feature`
3. **Develop & Test**: Write code and comprehensive tests
4. **Documentation**: Update relevant documentation
5. **Pull Request**: Submit for review

### Code Review Checklist

- [ ] All tests pass
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] Security considerations addressed
- [ ] Performance implications considered

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Make changes and commit
git add .
git commit -m "feat: add new feature"

# Push to fork
git push origin feature/my-feature

# Create pull request on GitHub
```

## 📞 Support

### Getting Help

- **Documentation**: Check `/documentation/` directory
- **GitHub Issues**: [Report bugs or request features](https://github.com/Anya-org/Conxian/issues)
- **Code Examples**: See `sdk-tests/` for comprehensive examples
- **Community**: Join development discussions

### Common Resources

- **Clarity Language Guide**: [Official Clarity Documentation](https://docs.stacks.co/clarity)
- **Clarinet CLI Guide**: [Clarinet Documentation](https://github.com/hirosystems/clarinet)
- **Stacks.js SDK**: [Stacks.js Documentation](https://stacks.js.org/)

---

## Summary

This developer guide provides:

- **Complete development setup** instructions
- **Comprehensive testing** framework and examples
- **Deployment procedures** for all environments
- **Code standards** and best practices
- **Debugging tools** and troubleshooting guides

Follow this guide to contribute effectively to the Conxian project.

## CI/CD Pipeline

### Overview

This document describes the enhanced CI/CD pipeline for the Conxian protocol, providing automated testing, building, and deployment capabilities.

### Pipeline Structure

The pipeline consists of several key stages:

1. **Validation**: Initial checks and setup
2. **Security**: Security scanning and code quality checks
3. **Test**: Unit and integration testing
4. **Build**: Docker image creation and packaging
5. **Deploy**: Automated deployment to environments
6. **Post-Deploy**: Verification and reporting

### Workflow Triggers

- **Push to main/develop**: Runs tests and builds
- **Pull Requests**: Runs tests and security checks
- **Scheduled**: Weekly security scans

### Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NODE_VERSION` | Node.js version | No | 20 |
| `CLARINET_VERSION` | Clarinet version | No | 3.7.0 |
| `DOCKERHUB_USERNAME` | Docker Hub username | Yes | - |
| `IMAGE_NAME` | Docker image name | No | Conxian-protocol |

### Required Secrets

|--------|-------------|
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `AWS_ACCESS_KEY_ID` | AWS access key for deployments |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for deployments |
| `SLACK_WEBHOOK_URL` | Webhook URL for notifications |
| `CODECOV_TOKEN` | Codecov access token |

### Manual Deployment

Deploy to an environment using the GitHub Actions UI:

1. Go to Actions > Enhanced CI/CD Pipeline
2. Click "Run workflow"
3. Select the environment (staging/production)
4. Click "Run workflow"

### Monitoring and Alerts

- **Success/Failure Notifications**: Sent to configured Slack channel
- **Deployment Status**: Available in GitHub Actions UI
- **Test Coverage**: Reported to Codecov
- **Security Alerts**: Generated for vulnerabilities

### Rollback Procedure

To rollback a deployment:

1. Identify the previous working commit
2. Revert to the previous version:

   ```bash
   git revert <commit-hash>
   git push origin main
   ```

3. The CI/CD pipeline will automatically deploy the previous version

### Troubleshooting

#### Common Issues

1. **Build Failures**:
   - Check test logs for failures
   - Verify dependency versions
   - Ensure all required environment variables are set

2. **Deployment Issues**:
   - Check AWS credentials
   - Verify network connectivity
   - Review deployment logs

3. **Test Failures**:
   - Run tests locally
   - Check for environment-specific issues
   - Review test coverage reports

### Best Practices

1. **Branch Protection**:
   - Require status checks to pass before merging
   - Enforce code review requirements
   - Prevent force pushes

2. **Security**:
   - Regularly update dependencies
   - Scan for vulnerabilities
   - Use secret management

3. **Monitoring**:
   - Monitor deployment health
   - Set up alerts for failures
   - Regularly review logs

### Support

For issues with the CI/CD pipeline, contact the DevOps team or create an issue in the repository.

## Error Codes

### Overview

This document outlines the standardized error codes used across the Conxian protocol.

### Error Code Ranges

| Component | Range | Description |
|-----------|-------|-------------|
| Common Errors | 1000-1999 | Shared across all contracts |
| Liquidation Manager | 1000-1099 | Liquidation-specific errors |
| Lending System | 2000-2999 | Core lending protocol errors |
| Vault System | 3000-3999 | Vault and strategy errors |
| Oracle | 4000-4999 | Price feed and oracle errors |
| Governance | 5000-5999 | Governance and access control |
| Token System | 6000-6999 | Token-related errors |
| Staking | 7000-7999 | Staking and rewards errors |
| Bridge | 8000-8999 | Cross-chain bridge errors |
| Migration | 9000-9999 | Migration and upgrade errors |

### Common Errors (1000-1999)

| Code | Constant | Description |
|------|----------|-------------|
| 1000 | ERR_UNKNOWN | An unknown error occurred |
| 1001 | ERR_LIQUIDATION_PAUSED | Liquidation is currently paused |
| 1002 | ERR_UNAUTHORIZED | Caller is not authorized |
| 1003 | ERR_INVALID_AMOUNT | Invalid amount specified |
| 1004 | ERR_POSITION_NOT_UNDERWATER | Position is not underwater |
| 1005 | ERR_SLIPPAGE_TOO_HIGH | Slippage exceeds maximum allowed |
| 1006 | ERR_LIQUIDATION_NOT_PROFITABLE | Liquidation would not be profitable |
| 1007 | ERR_MAX_POSITIONS_EXCEEDED | Maximum number of positions exceeded |
| 1008 | ERR_ASSET_NOT_WHITELISTED | Asset is not whitelisted |
| 1009 | ERR_INSUFFICIENT_COLLATERAL | Insufficient collateral |
| 1010 | ERR_INSUFFICIENT_LIQUIDITY | Insufficient liquidity |

### Lending System Errors (2000-2999)

| Code | Constant | Description |
|------|----------|-------------|
| 2000 | ERR_INVALID_ASSET | Invalid or unsupported asset |
| 2001 | ERR_INSUFFICIENT_BALANCE | Insufficient balance |
| 2002 | ERR_HEALTH_FACTOR_TOO_LOW | Health factor below minimum threshold |
| 2003 | ERR_INVALID_INTEREST_RATE | Invalid interest rate parameters |
| 2004 | ERR_RESERVE_FACTOR_TOO_HIGH | Reserve factor exceeds maximum |

### Vault System Errors (3000-3999)

| Code | Constant | Description |
|------|----------|-------------|
| 3000 | ERR_VAULT_PAUSED | Vault operations are paused |
| 3001 | ERR_INSUFFICIENT_SHARES | Insufficient shares to redeem |
| 3002 | ERR_STRATEGY_ACTIVE | Strategy is already active |
| 3003 | ERR_STRATEGY_INACTIVE | Strategy is not active |
| 3004 | ERR_STRATEGY_DEBT_LIMIT | Strategy debt limit exceeded |

### Oracle Errors (4000-4999)

| Code | Constant | Description |
|------|----------|-------------|
| 4000 | ERR_PRICE_STALE | Price data is too old |
| 4001 | ERR_PRICE_INVALID | Invalid price data |
| 4002 | ERR_ORACLE_DISPUTED | Price is disputed |
| 4003 | ERR_ORACLE_NOT_FOUND | Oracle not found for asset |

### Governance Errors (5000-5999)

| Code | Constant | Description |
|------|----------|-------------|
| 5000 | ERR_GOVERNANCE_ONLY | Caller is not governance |
| 5001 | ERR_TIMELOCK_NOT_EXPIRED | Timelock has not expired |
| 5002 | ERR_INSUFFICIENT_VOTES | Insufficient voting power |
| 5003 | ERR_VOTING_CLOSED | Voting is closed |

### Token System Errors (6000-6999)

| Code | Constant | Description |
|------|----------|-------------|
| 6000 | ERR_TRANSFER_FAILED | Token transfer failed |
| 6001 | ERR_APPROVAL_FAILED | Token approval failed |
| 6002 | ERR_INSUFFICIENT_ALLOWANCE | Insufficient allowance |

### Staking Errors (7000-7999)

| Code | Constant | Description |
|------|----------|-------------|
| 7000 | ERR_STAKING_PAUSED | Staking is paused |
| 7001 | ERR_INSUFFICIENT_STAKE | Insufficient stake |
| 7002 | ERR_STAKE_LOCKED | Stake is still locked |
| 7003 | ERR_REWARDS_NOT_CLAIMABLE | Rewards not yet claimable |

### Bridge Errors (8000-8999)

| Code | Constant | Description |
|------|----------|-------------|
| 8000 | ERR_INVALID_CHAIN | Invalid chain ID |
| 8001 | ERR_INVALID_MESSAGE | Invalid bridge message |
| 8002 | ERR_ALREADY_PROCESSED | Message already processed |
| 8003 | ERR_INVALID_SIGNATURE | Invalid bridge signature |

### Migration Errors (9000-9999)

| Code | Constant | Description |
|------|----------|-------------|
| 9000 | ERR_MIGRATION_NOT_STARTED | Migration has not started |
| 9001 | ERR_MIGRATION_COMPLETED | Migration already completed |
| 9002 | ERR_INVALID_MIGRATION_DATA | Invalid migration data |
| 9003 | ERR_MIGRATION_PAUSED | Migration is paused |

### Best Practices

1. Always use the named constants instead of raw error codes
2. When adding new errors, use the next available code in the appropriate range
3. Update this documentation when adding new error codes
4. Include descriptive error messages in the contract code
5. Log relevant context with errors when possible

## Trait Registry

### Overview
The Trait Registry is a central contract that manages trait implementations in the Conxian protocol. It provides a standardized way to discover and use traits across different contracts.

### Key Features

1. **Centralized Trait Management**
   - Single source of truth for all trait implementations
   - Easy discovery of available traits
   - Versioning support for traits

2. **Trait Lifecycle**
   - Register new trait implementations
   - Deprecate old traits
   - Suggest replacements for deprecated traits

3. **Metadata**
   - Rich metadata for each trait
   - Version tracking
   - Descriptions and documentation

### Usage

#### Registering a New Trait

```clarity
(register-trait
  "my-trait"  ;; trait name
  1           ;; version
  "Description of my trait"
  'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.my-contract
  false       ;; deprecated
  none        ;; replacement (optional)
)
```

#### Using a Trait in Your Contract

```clarity
;; 1. Define the trait registry constant
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; 2. Resolve the trait at deployment time
(use-trait my-trait (unwrap! (contract-call? TRAIT_REGISTRY get-trait-contract 'my-trait) (err u1000)))

;; 3. Implement the trait
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.my-trait)
```

#### Checking if a Trait is Deprecated

```clarity
(contract-call? TRAIT_REGISTRY is-trait-deprecated 'my-trait)
```

#### Finding a Replacement for a Deprecated Trait

```clarity
(contract-call? TRAIT_REGISTRY get-trait-replacement 'deprecated-trait)
```

### Best Practices

1. **Always Use the Registry**
   - Never hardcode trait principals in your contracts
   - Always resolve traits through the registry

2. **Versioning**
   - Increment version numbers for breaking changes
   - Document changes between versions

3. **Deprecation**
   - Mark old traits as deprecated when replacing them
   - Always provide a replacement when deprecating
   - Keep deprecated traits in the registry for backward compatibility

4. **Error Handling**
   - Always handle cases where a trait might not be found
   - Use meaningful error codes

### Initialization

Use the provided initialization script to register standard traits:

```typescript
import { initializeTraitRegistry } from '../scripts/init-trait-registry';

// In your test or deployment script
await initializeTraitRegistry(chain, deployer);
```

### Security Considerations

- Only the contract owner can register or update traits
- Always verify the trait contract address before using it
- Be cautious when updating existing trait implementations
