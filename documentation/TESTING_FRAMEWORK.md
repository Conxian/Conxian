# Conxian Protocol - Testing Framework Setup

## Overview

This document outlines the comprehensive testing framework for the Conxian Protocol.

## Testing Structure

### Unit Tests

- **Location**: `tests/unit/`
- **Purpose**: Test individual contract functions
- **Framework**: Vitest + Clarinet SDK

### Integration Tests  

- **Location**: `tests/integration/`
- **Purpose**: Test cross-contract interactions
- **Framework**: Vitest + Clarinet SDK

### Load Testing

- **Location**: `tests/load/`
- **Purpose**: Performance and stress testing
- **Framework**: Custom load testing scripts

## Test Configuration

### Environment Setup

```bash
# Install dependencies
npm install

# Run all tests
npm test

# Run specific test suites
npm run test:unit
npm run test:integration
npm run test:load
```

### Test Coverage Requirements

- **Minimum Coverage**: 80%
- **Critical Contracts**: 95%
- **Math Libraries**: 100%

## Test Data Management

### Mock Data

- Price feeds
- Token balances
- User identities
- Market conditions

### Test Scenarios

- Normal operations
- Edge cases
- Error conditions
- Security vulnerabilities

## Continuous Integration

### GitHub Actions

- Automated test execution
- Coverage reporting
- Performance benchmarks
- Security scanning

### Test Results

- Pass/Fail status
- Coverage metrics
- Performance reports
- Security findings

## Best Practices

1. **Test Isolation**: Each test should be independent
2. **Clear Assertions**: Use descriptive assertion messages
3. **Mock External Dependencies**: Use mocks for oracles and external contracts
4. **Comprehensive Coverage**: Test all code paths
5. **Regular Updates**: Keep tests updated with contract changes

## Dimension-Based Test Suites

To localize failures quickly in a large codebase, tests can be run by **dimension → subsystem → module → file**. Each dimension groups contracts and tests for a specific functional area.

### Dimensions and npm Commands

- **DEX Dimension**  
  **Scope**: `contracts/dex/**`, pool registry/factory, routers, MEV protection, price impact.  
  **Representative tests**: `tests/dex/**`, `tests/dex-factory*.ts`, `tests/pool-integration.test.ts`, `tests/pool-management.test.ts`, `tests/liquidity-provider.test.ts`, `tests/price-impact-calculator.test.ts`, `tests/router/**`, `tests/mev-protector.test.ts`.  
  **Command**: `npm run test:dex-dimension`

- **Lending & Risk Dimension**  
  **Scope**: `contracts/lending/**`, `contracts/risk/**`, liquidation engine, funding calculator, risk manager.  
  **Representative tests**: `tests/lending/**`, `tests/comprehensive-lending-system.*.ts`, `tests/flash-loan-integration.test.ts`, `tests/loan-liquidation-manager.spec.ts`, `tests/lending-system-*.ts`, `tests/liquidation-manager-test.ts`.  
  **Command**: `npm run test:lending-dimension`

- **Governance & Tokens Dimension**  
  **Scope**: `contracts/governance/**`, `contracts/governance-token.clar`, `contracts/tokens/**`, price initializer.  
  **Representative tests**: `tests/governance/**`, `tests/governance-token.test.ts`, `tests/governance-signature-verifier.test.ts`, `tests/tokenized-bond.test.ts`.  
  **Command**: `npm run test:governance-dimension`

- **Oracle & Monitoring Dimension**  
  **Scope**: `contracts/dex/oracle*.clar`, `contracts/oracle/**`, `contracts/integrations/twap-oracle.clar`, manipulation detector, monitoring contracts.  
  **Representative tests**: `tests/chainlink-adapter.test.ts`, `tests/twap-oracle*.test.ts`, `tests/lending-system-oracle-test.ts`, `tests/monitoring/**`.  
  **Command**: `npm run test:oracle-dimension`

- **Dimensional Core Dimension**  
  **Scope**: `contracts/dimensional/**`, `contracts/core/dimensional-engine.clar`, position factory.  
  **Representative tests**: `tests/dimensional/**`, `tests/dimensional-engine.test.ts`, `tests/pool-integration.test.ts`, `tests/funding-rate-calculations.test.ts`, `tests/sbtc-integration.test.ts`.  
  **Command**: `npm run test:dimensional-dimension`

- **Risk & Insurance Dimension**  
  **Scope**: risk monitors, insurance funds, liquidation metrics.  
  **Representative tests**: `tests/risk-management.test.ts`, `tests/insurance-fund.test.ts`.  
  **Command**: `npm run test:risk-dimension`

### Usage

- During development, run the dimension relevant to your change first (for example, `npm run test:dex-dimension` for DEX changes), then run broader suites such as `npm test` or `npm run test:all` before merging.  
- In CI, dimension-specific jobs can be used to quickly pinpoint which area regressed before drilling down to individual failing tests.
