# sBTC Vaults Module

**Status: Refactoring in Progress**

This module manages the sBTC vaults, which are currently undergoing a significant architectural refactoring. The monolithic `sbtc-vault.clar` is being phased out and replaced by a more modular, secure, and extensible system of specialized contracts.

## Overview

The sBTC vaults provide a secure and decentralized way for users to deposit their sBTC and earn yield. The new, modular architecture will enhance the security, maintainability, and extensibility of the vault system.

## Key Contracts

### New Modular Architecture
- **`custody.clar`**: Manages the deposit and withdrawal of sBTC.
- **`yield-aggregator.clar`**: Implements various yield strategies to generate returns for users.
- **`btc-bridge.clar`**: Handles the wrapping and unwrapping of sBTC.
- **`fee-manager.clar`**: Manages the fees collected by the vault system.

### Legacy Contract
- **`sbtc-vault.clar`**: The original, monolithic sBTC vault, which is being phased out.
