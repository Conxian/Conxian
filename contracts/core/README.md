# Core Module

This module contains the core logic for the Conxian Protocol's dimensional engine.
The contracts in this module are responsible for managing user positions,
calculating funding rates, and handling collateral.

## Contracts

- **`dimensional-engine.clar`**: The main entry point for the dimensional engine. This contract acts as a facade, delegating calls to the other specialized contracts in this module. Uses modular traits including `.core-protocol.rbac-trait`.

- **`position-manager.clar`**: Manages the lifecycle of user positions, including opening, closing, and liquidations. Implements `.dimensional-traits.position-manager-trait`.

- **`funding-rate-calculator.clar`**: Calculates the funding rate for perpetual markets. Implements `.dimensional-traits.funding-rate-calculator-trait` and uses `.core-protocol.rbac-trait`.

- **`collateral-manager.clar`**: Handles the deposit and withdrawal of collateral. Implements `.dimensional-traits.collateral-manager-trait`.

- **`conxian-protocol.clar`**: The main protocol coordinator contract managing protocol-wide configuration, authorized contracts, and emergency controls.

## Status

**Nakamoto Ready**: The contracts in this module are feature-complete and compatible with Stacks Epoch 3.0. All critical compilation errors have been resolved. The module uses the centralized trait system for interface definitions.
