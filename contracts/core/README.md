# Core Module

This module contains the core logic for the Conxian Protocol's dimensional engine. The contracts in this module are responsible for managing user positions, calculating funding rates, and handling collateral.

## Contracts

- **`dimensional-engine.clar`**: The main entry point for the dimensional engine. This contract acts as a facade, delegating calls to the other specialized contracts in this module.
- **`position-manager.clar`**: Manages the lifecycle of user positions, including opening, closing, and liquidations.
- **`funding-rate-calculator.clar`**: Calculates the funding rate for perpetual markets.
- **`collateral-manager.clar`**: Handles the deposit and withdrawal of collateral.
- **`conxian-protocol.clar`**: The main contract for the Conxian protocol.

## Status

**Migration In Progress**: The contracts in this module have not yet been migrated to the new modular trait system. They still use the legacy, individual trait files. This is a high-priority task in the ongoing architectural refactoring.
