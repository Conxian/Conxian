# Contract Guide: `vault.clar`

**Primary Contract:** `contracts/vault.clar`

## 1. Introduction

The `vault.clar` contract is a secure ledger for managing user deposits and shares across multiple assets. It is designed to be controlled by an external `yield-optimizer` contract, which is responsible for executing investment strategies. The vault itself does not contain complex logic for yield generation; instead, it focuses on the core accounting of deposits, withdrawals, and shares.

## 2. Key Concepts

### Multi-Asset Ledger

The vault can support multiple SIP-010 tokens, with each asset having its own deposit cap. The admin is responsible for adding supported assets to the vault.

### Share-Based Accounting

For each supported asset, the vault uses a share-based accounting system:

-   **Shares:** When a user deposits an asset, they receive shares that represent their proportional ownership of that asset's total balance within the vault.
-   **Share Price:** The value of each share is calculated as `(Total Asset Balance) / (Total Shares)`.

### Yield Optimizer Integration

The vault is designed to be managed by a `yield-optimizer` contract. This contract has the authority to move funds from the vault to various investment strategies. This separation of concerns allows the vault to remain simple and secure, while the optimizer handles the complexities of yield generation.

## 3. State Variables

| Variable Name                | Type          | Description                                                                 |
| ---------------------------- | ------------- | --------------------------------------------------------------------------- |
| `admin`                      | `principal`   | The address of the admin, who can manage the vault's settings.              |
| `paused`                     | `bool`        | If `true`, all deposits and withdrawals are disabled.                       |
| `yield-optimizer-contract`   | `principal`   | The address of the contract that can move funds to strategies.              |
| `total-balances`             | `map`         | Maps an asset's contract principal to its total balance in the vault.       |
| `vault-shares`               | `map`         | Maps an asset's contract principal to the total number of shares issued.    |
| `user-shares`                | `map`         | Maps a tuple of `(user, asset)` to the user's share balance for that asset. |
| `supported-assets`           | `map`         | Maps an asset's contract principal to a boolean indicating if it's supported. |
| `asset-caps`                 | `map`         | Maps an asset's contract principal to its maximum deposit cap.              |

## 4. User Functions

### `deposit`

Deposits a specified amount of a supported asset and mints shares for the user.

-   **Parameters:**
    -   `asset <sip-010-ft-trait>`: The contract of the token being deposited.
    -   `amount uint`: The amount of the token to deposit.
-   **Returns:** The number of shares minted for the user.

### `withdraw`

Burns a specified number of shares to withdraw the corresponding amount of the underlying asset.

-   **Parameters:**
    -   `asset <sip-010-ft-trait>`: The contract of the token being withdrawn.
    -   `shares uint`: The number of shares to burn.
-   **Returns:** The amount of the underlying asset withdrawn.

## 5. Admin Functions

| Function Name         | Parameters                | Description                                               |
| --------------------- | ------------------------- | --------------------------------------------------------- |
| `set-admin`           | `new-admin principal`     | Sets a new admin address.                                 |
| `set-paused`          | `pause bool`              | Pauses or unpauses the vault's core functions.            |
| `set-yield-optimizer` | `optimizer principal`     | Sets the address of the yield optimizer contract.         |
| `add-supported-asset` | `asset principal`, `cap uint` | Adds a new asset to the list of supported assets and sets its deposit cap. |

## 6. Optimizer-Only Functions

These functions can only be called by the `yield-optimizer-contract`.

| Function Name            | Parameters                                                      | Description                                                         |
| ------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| `deposit-to-strategy`    | `asset <sip-010-ft-trait>`, `amount uint`, `strategy <strategy-trait>` | Deposits a specified amount of an asset into a strategy contract.   |
| `withdraw-from-strategy` | `asset <sip-010-ft-trait>`, `amount uint`, `strategy <strategy-trait>` | Withdraws a specified amount of an asset from a strategy contract. |

## 7. Read-Only Functions

| Function Name       | Parameters      | Returns      | Description                                           |
| ------------------- | --------------- | ------------ | ----------------------------------------------------- |
| `get-total-balance` | `asset principal` | `(ok uint)` | Returns the total balance of a specified asset in the vault. |

## 8. Error Codes

| Code    | Name                       | Description                                            |
| ------- | -------------------------- | ------------------------------------------------------ |
| `u6001` | `ERR_UNAUTHORIZED`         | Caller is not authorized to perform the action.        |
| `u6002` | `ERR_PAUSED`               | The vault is currently paused.                         |
| `u6003` | `ERR_INSUFFICIENT_BALANCE` | The user does not have enough balance to withdraw.     |
| `u6004` | `ERR_INVALID_AMOUNT`       | The specified amount is zero.                          |
| `u6005` | `ERR_CAP_EXCEEDED`         | The deposit would exceed the asset's cap.              |
| `u6006` | `ERR_INVALID_ASSET`        | The specified asset is not supported by the vault.     |
| `u6013` | `ERR_OPTIMIZER_ONLY`       | The caller is not the registered yield optimizer contract. |
