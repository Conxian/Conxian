# Contract Guide: `sbtc-vault.clar`

**Primary Contract:** `contracts/vaults/sbtc-vault.clar`

## 1. Introduction

The `sbtc-vault.clar` contract is a secure ledger for managing user deposits and shares of sBTC. It is designed to be controlled by an external `yield-optimizer` contract, which is responsible for executing investment strategies. The vault itself does not contain complex logic for yield generation; instead, it focuses on the core accounting of deposits, withdrawals, and shares.

## 2. Key Concepts

### sBTC-Only Ledger

The vault is designed to support only sBTC, with a deposit cap set by the admin.

### Share-Based Accounting

The vault uses a share-based accounting system:

-   **Shares:** When a user deposits sBTC, they receive shares that represent their proportional ownership of the total sBTC balance within the vault.
-   **Share Price:** The value of each share is calculated as `(Total sBTC Balance) / (Total Shares)`.

### Yield Optimizer Integration

The vault is designed to be managed by a `yield-optimizer` contract. This contract has the authority to move funds from the vault to various investment strategies. This separation of concerns allows the vault to remain simple and secure, while the optimizer handles the complexities of yield generation.

## 3. State Variables

| Variable Name                | Type          | Description                                                                 |
| ---------------------------- | ------------- | --------------------------------------------------------------------------- |
| `admin`                      | `principal`   | The address of the admin, who can manage the vault's settings.              |
| `paused`                     | `bool`        | If `true`, all deposits and withdrawals are disabled.                       |
| `yield-optimizer-contract`   | `principal`   | The address of the contract that can move funds to strategies.              |
| `total-balance`              | `uint`        | The total balance of sBTC in the vault.                                     |
| `vault-shares`               | `uint`        | The total number of shares issued.                                          |
| `user-shares`                | `map`         | Maps a user's principal to their share balance.                             |
| `asset-cap`                  | `uint`        | The maximum deposit cap for sBTC.                                           |

## 4. User Functions

### `deposit`

Deposits a specified amount of sBTC and mints shares for the user.

-   **Parameters:**
    -   `asset <sip-010-ft-trait>`: The contract of the sBTC token.
    -   `amount uint`: The amount of sBTC to deposit.
-   **Returns:** The number of shares minted for the user.

### `withdraw`

Burns a specified number of shares to withdraw the corresponding amount of sBTC.

-   **Parameters:**
    -   `asset <sip-010-ft-trait>`: The contract of the sBTC token.
    -   `shares uint`: The number of shares to burn.
-   **Returns:** The amount of sBTC withdrawn.

## 5. Admin Functions

| Function Name         | Parameters                | Description                                               |
| --------------------- | ------------------------- | --------------------------------------------------------- |
| `set-admin`           | `new-admin principal`     | Sets a new admin address.                                 |
| `set-paused`          | `pause bool`              | Pauses or unpauses the vault's core functions.            |
| `set-yield-optimizer` | `optimizer principal`     | Sets the address of the yield optimizer contract.         |
| `set-asset-cap`       | `cap uint`                | Sets the maximum deposit cap for sBTC.                    |

## 6. Optimizer-Only Functions

These functions can only be called by the `yield-optimizer-contract`.

| Function Name            | Parameters                                                      | Description                                                         |
| ------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| `deposit-to-strategy`    | `asset <sip-010-ft-trait>`, `amount uint`, `strategy <strategy-trait>` | Deposits a specified amount of sBTC into a strategy contract.   |
| `withdraw-from-strategy` | `asset <sip-010-ft-trait>`, `amount uint`, `strategy <strategy-trait>` | Withdraws a specified amount of sBTC from a strategy contract. |

## 7. Read-Only Functions

| Function Name       | Parameters      | Returns      | Description                                           |
| ------------------- | --------------- | ------------ | ----------------------------------------------------- |
| `get-total-balance` | `none`          | `(ok uint)`  | Returns the total balance of sBTC in the vault.       |
