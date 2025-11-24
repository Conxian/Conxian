# Liquidation Flow Documentation

## Overview

This document outlines the liquidation process in the Conxian protocol, including the interactions between the `comprehensive-lending-system` and `liquidation-manager` contracts.

## Key Components

### 1. `comprehensive-lending-system`

-   The main contract for the lending protocol.
-   Manages user positions, collateral, and debt.
-   Contains the core `liquidate` function, which is called by the `liquidation-manager`.

### 2. `liquidation-manager`

-   A specialized contract that manages the liquidation process.
-   Provides a public `liquidate-position` function that can be called by any user.
-   Verifies that a position is eligible for liquidation before calling the `liquidate` function on the `comprehensive-lending-system`.
-   Manages whitelisted assets for liquidation and a liquidation incentive.

## Liquidation Process

### Standard Liquidation

1.  **Initiation:** Any user can call the `liquidate-position` function on the `liquidation-manager` contract.
2.  **Verification:** The `liquidation-manager` checks if the position is underwater by calling the `is-position-underwater` function on the `comprehensive-lending-system`.
3.  **Execution:** If the position is underwater, the `liquidation-manager` calls the `liquidate` function on the `comprehensive-lending-system`.
4.  **Completion:** The `comprehensive-lending-system` updates the borrower's debt and collateral, transfers the collateral to the liquidator, and emits a liquidation event.

### Emergency Liquidation (Admin-Only)

-   The `liquidation-manager` has an `emergency-liquidate` function that can only be called by the admin.
-   This function bypasses some of the standard checks and can liquidate up to 100% of a position.

## Key Functions

### `liquidation-manager.clar`

-   **`liquidate-position`**: The main entry point for liquidations. Can be called by any user.
-   **`can-liquidate-position`**: A read-only function that checks if a position is eligible for liquidation.
-   **`calculate-liquidation-amounts`**: A read-only function that calculates the amount of collateral to be seized and the liquidation incentive.
-   **`emergency-liquidate`**: An admin-only function for emergency liquidations.

### `comprehensive-lending-system.clar`

-   **`liquidate`**: The core liquidation function. Can only be called by the `liquidation-manager`.
-   **`is-position-underwater`**: A read-only function that checks if a position's health factor is below the liquidation threshold.

## Security Considerations

-   All liquidation parameters are validated by the `liquidation-manager` before the `liquidate` function is called.
-   The `comprehensive-lending-system` contract includes reentrancy guards to prevent reentrancy attacks.
-   The `liquidation-manager` contract has a `set-paused` function that allows the admin to pause liquidations in case of an emergency.
