
# Load & Fuzz Testing

This directory contains advanced testing suites for the Conxian protocol.

## 1. Performance Benchmarking

**File:** `massive-scale.test.ts`
**Command:** `npm run test:performance`

Measures the throughput and execution time of core DEX operations (Swaps).
Use this to establish baselines for gas consumption and optimization.

## 2. Fuzz Testing

**File:** `fuzz-system.test.ts`
**Command:** `npm run test:fuzz`

Performs random operations against the protocol to identify edge cases,
logic errors, and unexpected panics.

- **Actions:** Randomly selects between Swapping and Adding Liquidity.
- **Inputs:** Generates random amounts, tick ranges, and users.
- **Invariants:** Checks for successful execution of valid transactions and
                  graceful handling of errors.

## Usage

Run the specific suite using the npm commands above. Adjust the `iterations`
constant in the test files to scale the testing duration up or down.
