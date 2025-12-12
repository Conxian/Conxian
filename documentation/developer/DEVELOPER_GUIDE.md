# Conxian Developer Guide

This guide provides everything you need to develop, test, and deploy Conxian smart contracts.

> **Note for Institutional Developers:** If you are building on top of our enterprise features, please see our [Enterprise Onboarding Guide](../enterprise/ONBOARDING.md) for more specific information.

## Quick Start

### Prerequisites

- Clarinet SDK v3.9.0 (via root `package.json`) and Clarinet CLI v3.9.0 on PATH
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
clarinet check
npm run test:system

### Environment Troubleshooting
If you encounter `Cannot read properties of undefined (reading 'split')` errors during tests, it is likely due to `clarinet-sdk` failing to load accounts from `Clarinet.toml` in your environment.
The tests include fallback logic for critical accounts (`wallet_1`), but ensure your `Clarinet.toml` is valid.
```

## Project Structure

```text
Conxian/
├── contracts/
│   ├── core/
│   ├── dex/
│   ├── governance/
│   ├── lending/
│   ├── oracle/
│   ├── security/
│   ├── tokens/
│   └── traits/
├── tests/
├── documentation/
├── deployments/
├── Clarinet.toml
├── package.json
└── vitest.config.enhanced.ts
```

## Development Workflow

### 1. Modular Trait Integration

When developing new contracts, follow these patterns for trait integration per **official Stacks standards**:

1. **Import Modular Traits**

   ```clarity
   (use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
   (use-trait pool-trait .defi-primitives.pool-trait)
   (use-trait rbac-trait .core-protocol.rbac-trait)
   ```

2. **Implement Traits**

   ```clarity
   (impl-trait .sip-standards.sip-010-ft-trait)
   ```

3. **Trait Pattern**: Always use `.contract-name.trait-name` format per official Stacks documentation

### 2. Smart Contract Development

#### Creating a New Contract

```bash
cd contracts
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
// tests/my-contract.spec.ts
import { describe, expect, it, beforeEach } from 'vitest';
 import { Simnet } from '@stacks/clarinet-sdk';

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
npx vitest run

# Run specific test file
npx vitest run -- my-contract.spec.ts

# Run tests with coverage
npx vitest run --coverage

# Run tests in watch mode
npx vitest watch
```

### 3. Contract Compilation

```bash
# Check all contracts
npx clarinet check

# Check specific contract
npx clarinet check --contract my-contract

# Format contracts
npx clarinet format
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
# Deploy to testnet
npx clarinet deploy --testnet

# Verify deployment
npx clarinet deployment describe --testnet
```

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

## 📞 Support

### Getting Help

- **Documentation**: Check `/documentation/` directory
- **GitHub Issues**: [Report bugs or request features](https://github.com/Anya-org/Conxian/issues)
- **Code Examples**: See `tests/` for comprehensive examples

### Common Resources

- **Clarity Language Guide**: [Official Clarity Documentation](https://docs.stacks.co/clarity)
- **Clarinet CLI Guide**: [Clarinet Documentation](https://github.com/hirosystems/clarinet)
- **Stacks.js SDK**: [Stacks.js Documentation](https://stacks.js.org/)
