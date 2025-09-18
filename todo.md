# TODO - Outstanding Issues for Conxian Repository

This document outlines the remaining issues that need to be addressed to get the test suite passing and ensure the stability of the Conxian protocol's smart contracts.

## 1. Persistent Clarity Trait Resolution Errors

**Issue:** The most critical and blocking issue is the widespread `(use-trait ...) expects a trait name and a trait identifier` error across numerous Clarity smart contracts. This error prevents the test suite from running correctly and seems to stem from a fundamental issue in how traits are being defined, imported, or resolved by the `clarinet` test environment.

**Files Affected:** Nearly all contracts that use traits are affected. This includes but is not limited to:
- `contracts/dex/dex-router.clar`
- `contracts/dex/bond-factory.clar`
- `contracts/tokens/cxlp-token.clar`
- And many others...

**Debugging Steps Taken:**
- Verified the syntax of `use-trait` statements.
- Verified the syntax of `define-trait` statements.
- Corrected malformed `Clarinet.toml` files by removing duplicate contract definitions and consolidating them.
- Experimented with relative vs. fully-qualified trait paths.
- Re-installed all npm dependencies.
- Attempted to run tests using different node versions and direct `vitest` calls.

**Next Steps:** A deeper investigation into the `clarinet` and `@hirosystems/clarinet-sdk` setup is required. The problem might be in the test environment configuration itself or an obscure syntax issue that has been missed.

## 2. Miscellaneous Clarity Syntax Errors

Several smaller syntax errors were identified and fixed, but some might remain or have been reintroduced. The test error logs should be consulted for the most up-to-date list.

- **`unknown symbol, '%'`**: Found in `contracts/lib/precision-calculator.clar` and `contracts/lib/fixed-point-math.clar`. This appears to be a typo where a contract call should use a `.` instead of a `%`.
- **`unknown symbol, '='`**: Found in `contracts/dex/bond-factory.clar`. The `=` operator is not valid in Clarity for comparison; `is-eq` should be used instead.
- **`Failed to parse uint literal`**: An extremely large `uint` literal in `contracts/dex/liquidation-manager.clar` is causing a parsing failure. This value may need to be handled differently.

## 3. Skipped Tests

A large number of tests (134) are currently being skipped. Once the blocking Clarity errors are resolved, these tests need to be re-enabled and run to ensure full test coverage and contract correctness.

## 4. Final Code Cleanup

As per the user's request, the codebase, particularly the `Clarinet.toml` files and trait definitions, should be reviewed for alignment and cleanliness to ensure a single, standardized configuration for both mainnet and testnet. My attempt at this was reverted to isolate the primary bug, but this task should be revisited.
