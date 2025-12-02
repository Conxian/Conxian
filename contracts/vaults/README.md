# Vaults Module

This module contains the contracts for the Conxian Protocol's sBTC vault, which allows users to deposit sBTC and earn yield.

## Status

**Nakamoto Ready**: The contracts in this module are feature-complete and compatible with Stacks Epoch 3.0.

## Contracts

- **`sbtc-vault.clar`**: The main entry point for the sBTC vault. This contract acts as a facade, delegating calls to the other specialized contracts in this module.
- **`custody.clar`**: Manages the custody of the sBTC deposited in the vault.
- **`yield-aggregator.clar`**: Aggregates yield from various strategies.
- **`btc-bridge.clar`**: Handles the wrapping and unwrapping of BTC and sBTC.
- **`fee-manager.clar`**: Manages the fees for the vault.
- **`vault-registrar.clar`**: A registry for vaults.
