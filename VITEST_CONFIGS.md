# Vitest Configuration Guide

## Overview

This repository contains multiple Vitest configuration files for different testing scenarios. Each serves a specific purpose in the testing infrastructure.

## Configuration Files

### 1. `vitest.config.ts` (Minimal - Governance Tests)

**Purpose**: Focused configuration for governance token tests  
**Use Case**: Quick governance-specific test runs  
**Include**: `tests/governance-token.test.ts`  
**Setup**: Uses global Clarinet SDK setup

```bash
# Run governance tests
npx vitest --config vitest.config.ts
```

### 2. `vitest.config.enhanced.ts` (Comprehensive - Main Config)

**Purpose**: Full-featured testing with coverage and benchmarking  
**Use Case**: Complete test suite with all features  
**Include**: All SDK tests in `stacks/sdk-tests/`  
**Features**:

- Coverage reporting (V8 provider)
- Benchmark support
- Performance thresholds
- Comprehensive reporting

```bash
# Run full test suite with coverage
npm test -- --config vitest.config.enhanced.ts
npm run coverage
```

### 3. `vitest.config.traits.ts` (Isolated - Trait Tests)

**Purpose**: Isolated trait implementation testing  
**Use Case**: Testing trait compliance without SDK coupling  
**Include**: `stacks/tests/trait-impl.spec.ts`  
**Setup**: No Clarinet SDK setup (isolated environment)

```bash
# Run trait tests
npx vitest --config vitest.config.traits.ts
```

## Recommended Usage

### Development Workflow

Use `vitest.config.enhanced.ts` for comprehensive testing during development:

```bash
npm test
```

### CI/CD Pipeline

The CI pipeline uses `vitest.config.enhanced.ts` for full validation with coverage reporting.

### Quick Checks

- **Governance changes**: Use `vitest.config.ts`
- **Trait implementations**: Use `vitest.config.traits.ts`
- **Full validation**: Use `vitest.config.enhanced.ts` (default)

## SDK Version Compatibility

All configurations are compatible with **Clarinet SDK 3.7.0**.

- Global simnet initialization via `stacks/global-vitest.setup.ts`
- Test manifest: `stacks/Clarinet.test.toml`
- Modern SDK patterns (no deprecated APIs)

## Configuration Comparison

| Feature | minimal | enhanced | traits |
|---------|---------|----------|---------|
| Coverage | ❌ | ✅ | ❌ |
| Benchmarks | ❌ | ✅ | ❌ |
| SDK Setup | ✅ | ✅ | ❌ |
| Full Test Suite | ❌ | ✅ | ❌ |
| Isolated Tests | ❌ | ❌ | ✅ |

## Adding New Tests

1. **Unit/Integration tests**: Add to `stacks/sdk-tests/` (uses enhanced config)
2. **Governance tests**: Add to `tests/` (uses minimal config)
3. **Trait tests**: Add to `stacks/tests/trait-impl.spec.ts` (uses traits config)

## Troubleshooting

### Tests not running

- Check config file includes your test path
- Verify SDK setup is correct for your test type

### Coverage not generating

- Ensure using `vitest.config.enhanced.ts`
- Run with `npm run coverage`

### SDK conflicts

- Use `vitest.config.traits.ts` for tests that need isolation from Clarinet SDK

---

*Last Updated: October 9, 2025*  
*SDK Version: Clarinet 3.7.0*
