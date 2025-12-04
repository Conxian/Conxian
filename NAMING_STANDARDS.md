# Conxian Token Naming Standards

This document defines the official naming conventions and standards for the
Conxian Protocol token ecosystem. All contracts and documentation must adhere
to these standards to ensure consistency and clarity.

## Core Protocol Tokens

### CXD - Conxian Revenue Token

* **Symbol**: `CXD`
* **Name**: `Conxian Revenue Token`
* **Type**: SIP-010 Fungible Token
* **Role**: The primary utility and revenue-accruing token of the protocol.
            It captures protocol fees and is used for governance participation.
* **Contract**: `contracts/tokens/cxd-token.clar`

### CXS - Conxian Staking Position

* **Symbol**: `CXS`
* **Name**: `Conxian Staking Position`
* **Type**: SIP-009 Non-Fungible Token (NFT)
* **Role**: Represents a unique staking position within the protocol.
            It tracks user deposits, lock durations, and accrued rewards.
* **Contract**: `contracts/tokens/cxs-token.clar`

### CXLP - Conxian Liquidity Provider Token

* **Symbol**: `CXLP`
* **Name**: `Conxian LP Token`
* **Type**: SIP-010 Fungible Token
* **Role**: Represents a share of a liquidity pool.
            Minted when users deposit assets into a pool and burned upon withdrawal.
* **Contract**: `contracts/tokens/cxlp-token.clar`

### CXTR - Conxian Treasury Token

* **Symbol**: `CXTR`
* **Name**: `Conxian Treasury Token`
* **Type**: SIP-010 Fungible Token
* **Role**: Represents claims on the protocol treasury reserves.
            Used for internal accounting and treasury management.
* **Contract**: `contracts/tokens/cxtr-token.clar`

### CXVG - Conxian Voting Token

* **Symbol**: `CXVG`
* **Name**: `Conxian Voting Token`
* **Type**: SIP-010 Fungible Token
* **Role**: Represents raw voting power derived from staking CXD or other assets.
            Used in the governance module.
* **Contract**: `contracts/tokens/cxvg-token.clar`

## Naming Rules

1. **Consistency**: The contract `name` variable must match the official
                    name defined in this standard.
1. **Clarity**: Names should be descriptive of the token's function
                (e.g., "Revenue", "Staking Position", "Voting").
1. **Symbols**: Symbols must be 3-4 uppercase letters,
                prefixed with "CX" for Conxian-native assets where possible.
1. **Files**: Contract filenames must match the symbol
              (lowercase) + `-token.clar` (e.g., `cxd-token.clar`).

## Implementation Status

* [x] CXD: Name consistent.
* [ ] CXS: Name update required (currently "Conxian Staking Token" ->
            "Conxian Staking Position").
* [ ] CXTR: Name update required (currently "Conxian Contributor Token" ->
             "Conxian Treasury Token").
* [x] CXLP: Name consistent.
* [x] CXVG: Name consistent.
