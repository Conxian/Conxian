# Contract Guide: The Conxian DEX

**Primary Contracts:** `contracts/dex-router.clar`, `contracts/dex-factory.clar`, `contracts/dex-pool.clar`
**Trait:** `contracts/traits/pool-trait.clar`

## 1. Introduction to the DEX Architecture

The Conxian Decentralized Exchange (DEX) is a suite of smart contracts that allows users to trade SIP-010 tokens and provide liquidity to earn fees. The architecture is designed to be modular and extensible, separating the logic for routing, pool creation, and the pools themselves.

The three main components are:

-   **The Factory (`dex-factory.clar`):** A registry contract that creates and keeps track of all liquidity pools. For any given pair of tokens, there is a single, unique pool managed by the factory.
-   **The Router (`dex-router.clar`):** The primary entry point for users. It provides user-friendly functions to interact with the DEX, such as swapping tokens and managing liquidity. It looks up pools in the factory and executes the requested actions.
-   **The Pools (e.g., `dex-pool.clar`):** Individual contracts that hold reserves of two tokens and implement the core logic for swapping and liquidity provision. All pools must adhere to the `pool-trait`, which defines a standard interface for DEX pools.

## 2. The DEX Workflow

### How to Swap Tokens

A token swap is a two-step process from a developer's perspective:

1.  **Resolve the Pool:** First, you need to find the correct liquidity pool for the token pair you want to trade. You do this by calling `resolve-pool` on the `dex-router.clar` contract, which in turn calls `get-pool` on the factory.
2.  **Execute the Swap:** Once you have the principal of the pool contract, you call one of the router's swap functions (e.g., `swap-exact-in-direct`), passing the pool principal as a parameter. The router then calls the `swap` function on the specified pool to execute the trade.

### How to Provide Liquidity

Adding or removing liquidity follows a similar pattern:

1.  **Resolve the Pool:** Find the pool for the token pair using `resolve-pool`.
2.  **Add/Remove Liquidity:** Call the appropriate function on the router (`add-liquidity-direct` or `remove-liquidity-direct`), passing the pool principal and other required parameters.

## 3. Multi-Hop Routing

Multi-hop routing allows users to trade between two tokens that do not have a direct liquidity pool by routing the trade through an intermediary token (e.g., swapping Token A for STX, and then STX for Token B).

The `dex-router.clar` contract includes a function `swap-exact-in-multi-hop` for this purpose.

**Important Note:** As of the current version, the multi-hop functionality is a **placeholder** and is not fully implemented. The function exists in the ABI but does not perform a multi-step trade. This feature is planned for a future release.

## 4. Key Functions in `dex-router.clar`

### Liquidity Functions

**`add-liquidity-direct`**
Adds liquidity to a specified pool.
-   **Parameters:**
    -   `pool <pool-trait>`: The pool contract to add liquidity to.
    -   `dx uint`: The amount of token X to add.
    -   `dy uint`: The amount of token Y to add.
    -   `min-shares uint`: The minimum number of liquidity pool shares to accept.
    -   `deadline uint`: A block height by which the transaction must be confirmed.

**`remove-liquidity-direct`**
Removes liquidity from a specified pool.
-   **Parameters:**
    -   `pool <pool-trait>`: The pool contract to remove liquidity from.
    -   `shares uint`: The number of liquidity pool shares to burn.
    -   `min-dx uint`: The minimum amount of token X to receive.
    -   `min-dy uint`: The minimum amount of token Y to receive.
    -   `deadline uint`: A block height by which the transaction must be confirmed.

### Swap Functions

**`swap-exact-in-direct`**
Swaps an exact amount of an input token for a minimum amount of an output token.
-   **Parameters:**
    -   `pool <pool-trait>`: The pool contract to trade with.
    -   `amount-in uint`: The exact amount of the input token to swap.
    -   `min-out uint`: The minimum amount of the output token you are willing to accept (slippage protection).
    -   `x-to-y bool`: The direction of the swap (`true` for token X to Y, `false` for Y to X).
    -   `deadline uint`: A block height by which the transaction must be confirmed.

### Read-Only Functions

**`resolve-pool`**
Finds the liquidity pool for a given pair of tokens.
-   **Parameters:** `token-x principal`, `token-y principal`
-   **Returns:** `(optional principal)` - The principal of the pool contract if it exists.

**`get-amount-out-direct`**
Gets a price quote for a swap without executing it.
-   **Parameters:** `pool <pool-trait>`, `amount-in uint`, `x-to-y bool`
-   **Returns:** `(ok uint)` - The expected amount of the output token.

## 5. Error Codes

These are the primary error codes defined in `dex-router.clar`.

| Code   | Name                     | Description                                      |
| ------ | ------------------------ | ------------------------------------------------ |
| `u100` | `ERR_DEADLINE`           | The transaction was not confirmed before the deadline. |
| `u101` | `ERR_NOT_FOUND`          | The requested item (e.g., a pool) was not found. |
| `u102` | `ERR_INVALID_POOL`       | The provided pool principal is not a valid pool. |
| `u103` | `ERR_INVALID_AMOUNTS`    | An amount provided was invalid (e.g., zero).     |
| `u104` | `ERR_INSUFFICIENT_FUNDS` | The contract or user has insufficient funds.     |
