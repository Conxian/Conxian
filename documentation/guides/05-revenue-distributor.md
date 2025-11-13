# Contract Guide: `revenue-distributor.clar`

**Primary Contract:** `contracts/revenue-distributor.clar`

## 1. Introduction

The `revenue-distributor.clar` contract is a core component of the Conxian protocol's economic system. It is responsible for the automated distribution of protocol fees to various stakeholders within the ecosystem. The contract is designed to be extensible, allowing for the registration of multiple fee sources and the distribution of various tokens.

## 2. Key Concepts

### Fee Distribution

The contract distributes revenue according to a fixed split:
-   **80%** to xCXD stakers (via the `.cxd-staking` contract)
-   **15%** to the treasury
-   **5%** to an insurance reserve

### Multi-Token Support

The revenue distributor can handle distributions for multiple SIP-010 tokens. Each token's revenue is tracked independently.

### Fee Source Registration

The contract owner can register new sources of revenue, such as fees from different protocol features. Each fee source is associated with a collection contract and a distribution weight, allowing for a flexible and extensible system.

## 3. State Variables

| Variable Name                 | Type             | Description                                                                 |
| ----------------------------- | ---------------- | --------------------------------------------------------------------------- |
| `contract-owner`              | `principal`      | The address of the contract owner, who can manage the contract's settings.  |
| `paused`                      | `bool`           | If `true`, all distributions are disabled.                                  |
| `treasury-address`            | `principal`      | The address of the protocol's treasury.                                     |
| `insurance-address`           | `principal`      | The address of the protocol's insurance reserve.                            |
| `last-distribution`           | `uint`           | The block height of the last distribution.                                  |
| `total-revenue-distributed`   | `uint`           | The total amount of revenue distributed by the contract.                    |
| `token-revenue`               | `map`            | Maps a token's contract principal to its accumulated revenue.               |
| `revenue-sources`             | `map`            | Maps a source identifier to its type, total collected, and last update.     |
| `distribution-history`        | `map`            | Maps a distribution ID to a record of the distribution.                     |
| `fee-types`                   | `map`            | Maps a fee type to its configuration, including the collection contract and weight. |

## 4. Core Functions

### `distribute-revenue`

Distributes a specified amount of a token's revenue to the stakeholders.

-   **Parameters:**
    -   `token principal`: The contract of the token being distributed.
    -   `amount uint`: The amount of the token to distribute.
-   **Returns:** The ID of the distribution record.

### `distribute-multi-token-revenue`

Distributes revenue for multiple tokens in a single transaction.

-   **Parameters:**
    -   `distributions (list 10 (tuple (token principal) (amount uint)))`: A list of token-amount pairs to distribute.
-   **Returns:** The number of distributions processed.

## 5. Admin Functions

| Function Name             | Parameters                                           | Description                                               |
| ------------------------- | ---------------------------------------------------- | --------------------------------------------------------- |
| `register-fee-source`     | `source-type (string-ascii 32)`, `collection-contract principal`, `weight uint` | Registers a new source of revenue.                        |
| `update-fee-source`       | `source-type (string-ascii 32)`, `is-active bool`, `weight uint` | Updates the configuration of a fee source.                |
| `emergency-pause`         | -                                                    | Pauses all distributions.                                 |
| `emergency-resume`        | -                                                    | Resumes distributions.                                    |
| `set-treasury-address`    | `new-treasury principal`                             | Sets the address of the treasury.                         |
| `set-insurance-address`   | `new-insurance principal`                            | Sets the address of the insurance reserve.                |

## 6. Read-Only Functions

| Function Name                 | Parameters                  | Returns                               | Description                                                     |
| ----------------------------- | --------------------------- | ------------------------------------- | --------------------------------------------------------------- |
| `get-contract-owner`          | -                           | `principal`                           | Returns the address of the contract owner.                      |
| `is-paused`                   | -                           | `bool`                                | Returns `true` if the contract is paused.                       |
| `get-treasury-address`        | -                           | `principal`                           | Returns the address of the treasury.                            |
| `get-insurance-address`       | -                           | `principal`                           | Returns the address of the insurance reserve.                   |
| `get-last-distribution`       | -                           | `uint`                                | Returns the block height of the last distribution.              |
| `get-token-revenue`           | `token principal`           | `uint`                                | Returns the accumulated revenue for a specified token.          |
| `get-total-revenue-distributed` | -                           | `uint`                                | Returns the total revenue distributed by the contract.          |
| `get-system-health`           | -                           | `tuple`                               | Returns a tuple with key health metrics of the system.          |
| `get-distribution-history`    | `distribution-id uint`      | `(optional tuple)`                    | Returns the record of a specific distribution.                  |
| `get-fee-source`              | `source-type (string-ascii 32)` | `(optional tuple)`                    | Returns the configuration of a specific fee source.             |

## 7. Error Codes

| Code   | Name                       | Description                                            |
| ------ | -------------------------- | ------------------------------------------------------ |
| `u100` | `ERR_UNAUTHORIZED`         | Caller is not authorized to perform the action.        |
| `u101` | `ERR_INVALID_AMOUNT`       | The specified amount is invalid.                       |
| `u102` | `ERR_INSUFFICIENT_BALANCE` | The contract does not have enough balance to distribute. |
| `u103` | `ERR_DISTRIBUTION_FAILED`  | The distribution failed for an unknown reason.         |
| `u104` | `ERR_INVALID_TOKEN`        | The specified token is not valid.                      |
| `u105` | `ERR_SYSTEM_PAUSED`        | The system is currently paused.                        |
