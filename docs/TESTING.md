# Conxian Test Architecture

## Overview

This document describes the testing architecture and practices for the Conxian protocol. The test suite is designed to ensure the reliability, security, and performance of the smart contracts.

## Test Categories

### 1. Unit Tests
- **Location**: `tests/unit/`
- **Purpose**: Test individual functions in isolation
- **Tools**: Vitest, Clarinet
- **Coverage**: 100% of public functions

### 2. Integration Tests
- **Location**: `tests/integration/`
- **Purpose**: Test interactions between contracts
- **Tools**: Vitest, Clarinet SDK
- **Coverage**: Critical user flows and cross-contract calls

### 3. Security Tests
- **Location**: `tests/security/`
- **Purpose**: Identify vulnerabilities
- **Tools**: Custom test cases, formal verification
- **Coverage**: Reentrancy, access control, overflow/underflow

### 4. Load Tests
- **Location**: `tests/load-testing/`
- **Purpose**: Measure performance under load
- **Tools**: Vitest, custom load testing framework
- **Metrics**: TPS, latency, gas usage

### 5. Invariant Tests
- **Location**: `tests/invariants/`
- **Purpose**: Verify system invariants
- **Coverage**: Financial invariants, state consistency

## Running Tests

### Run All Tests
```bash
npm test
```

### Run Specific Test Category
```bash
# Unit tests
npm test -- --testPathPattern="unit"

# Integration tests
npm test -- --testPathPattern="integration"

# Security tests
npm test -- --testPathPattern="security"

# Load tests
npm test -- --testPathPattern="load"

# Invariant tests
npm test -- --testPathPattern="invariant"
```

### Run with Coverage
```bash
npm run test:coverage
```

## Debugging Tests

### Debugging with VS Code
1. Set breakpoints in your test files
2. Use the VS Code debugger with the "Debug Current Test" configuration
3. Step through code execution

### Common Issues
1. **Test Timeouts**: Increase timeout in `vitest.config.ts`
2. **Type Errors**: Ensure all types are properly imported and defined
3. **Contract Deployment Failures**: Check contract dependencies in `Clarinet.toml`

## Adding New Tests

1. **Create Test File**
   - Place in the appropriate test directory
   - Follow naming convention: `<contract-or-feature>.test.ts`

2. **Write Test Cases**
   - Use descriptive test names
   - Follow AAA pattern: Arrange, Act, Assert
   - Include edge cases and error conditions

3. **Test Data**
   - Use test fixtures for complex data
   - Keep test data in `tests/fixtures/`

## Monitoring and Reporting

### Generate Test Report
```bash
node monitoring/monitor.js run
```

### View Historical Reports
Reports are saved in `monitoring/reports/` as HTML files.

### Metrics Tracked
- Test pass/fail rates
- Code coverage
- Performance metrics
- Test execution time

## Formal Verification

### Running Formal Verification
```bash
cd formal-verification
make verify
```

### Adding New Specifications
1. Create a new `.k` file in `formal-verification/specs/`
2. Define the properties to verify
3. Add to the `Makefile` if needed

## CI/CD Integration

Tests are automatically run on:
- Push to `main` or `develop` branches
- Pull requests
- Scheduled runs (daily)

## Performance Budgets

| Metric            | Warning Threshold | Error Threshold |
|-------------------|-------------------|-----------------|
| Test Runtime      | > 5 min           | > 10 min        |
| Test Coverage     | < 80%             | < 70%           |
| Avg. Response Time| > 500ms           | > 1000ms        |
| Memory Usage     | > 1GB             | > 2GB           |

## Best Practices

1. **Isolation**: Each test should be independent
2. **Determinism**: Tests should be deterministic
3. **Readability**: Clear test names and structure
4. **Maintainability**: Reuse test utilities
5. **Performance**: Keep tests fast and efficient
