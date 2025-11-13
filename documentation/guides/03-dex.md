# Contract Guide: `multi-hop-router-v3.clar`

**Primary Contract:** `contracts/dex/multi-hop-router-v3.clar`

## 1. Introduction to the DEX Router

The `multi-hop-router-v3.clar` contract is the primary entry point for executing trades on the Conxian DEX. It is designed to find the most efficient path for a token swap, even if it requires multiple "hops" through different liquidity pools.

## 2. Key Concepts

### Multi-Hop Routing

-   The router uses Dijkstra's algorithm to find the shortest path between two tokens, which translates to the best possible exchange rate for the user.
-   Routes can involve multiple intermediate pools to achieve the best price.

### Route Proposal and Execution

-   **Proposing a Route:** Before a trade can be executed, a user must first "propose" a route. This is done by calling the `propose-route` function, which computes the best path and returns a `route-id`.
-   **Executing a Route:** Once a route has been proposed, it can be executed by calling the `execute-route` function with the `route-id`.

### Slippage Protection

-   When proposing a route, users can specify a `min-amount-out`, which is the minimum amount of the output token they are willing to accept. This protects them from unfavorable price changes (slippage) that may occur between the time a route is proposed and when it is executed.

## 3. How to Swap Tokens

### Step 1: Propose a Route

Call the `propose-route` function with the following parameters:

-   `token-in`: The token you want to sell.
-   `token-out`: The token you want to buy.
-   `amount-in`: The amount of `token-in` you want to sell.
-   `min-amount-out`: The minimum amount of `token-out` you are willing to accept.
-   `route-timeout`: The number of blocks after which the proposed route expires.

This function will return a `route-id`.

### Step 2: Execute the Route

Call the `execute-route` function with the following parameters:

-   `route-id`: The ID of the route you want to execute.
-   `min-amount-out`: The minimum amount of the output token you are willing to accept.
-   `recipient`: The address that will receive the output tokens.

## 4. Key Functions

| Function Name         | Parameters                                                                                                                              | Description                                                                                                                            |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `propose-route`       | `token-in principal`, `token-out principal`, `amount-in uint`, `min-amount-out uint`, `route-timeout uint`                                 | Computes the best route for a swap and returns a `route-id`.                                                                           |
| `execute-route`       | `route-id (buff 32)`, `min-amount-out uint`, `recipient principal`                                                                        | Executes a previously proposed route.                                                                                                  |
| `compute-best-route`  | `token-in principal`, `token-out principal`, `amount-in uint`                                                                             | A read-only function that computes the best route and returns the path and the expected output amount.                                |
| `get-route-stats`     | `route-id (buff 32)`                                                                                                                    | A read-only function that returns statistics for a given route, such as the number of hops and the expiration block.                   |

## 5. Error Codes

| Code    | Name                            | Description                                      |
| ------- | ------------------------------- | ------------------------------------------------ |
| `u1400` | `ERR_INVALID_ROUTE`             | The specified route is invalid.                  |
| `u1401` | `ERR_ROUTE_NOT_FOUND`           | The specified route was not found.               |
| `u1402` | `ERR_INSUFFICIENT_OUTPUT`       | The actual output of the swap was less than the minimum specified. |
| `u1403` | `ERR_HOP_LIMIT_EXCEEDED`        | The route exceeds the maximum number of hops.     |
| `u1404` | `ERR_INVALID_TOKEN`             | An invalid token was specified.                  |
| `u1405` | `ERR_ROUTE_EXPIRED`             | The route has expired.                           |
| `u1406` | `ERR_REENTRANCY_GUARD`          | A reentrancy error occurred.                     |
| `u1407` | `ERR_NO_PATH_FOUND`             | No valid path was found between the two tokens.   |
| `u1408` | `ERR_DIJKSTRA_INIT_FAILED`      | The Dijkstra algorithm failed to initialize.      |
| `u1409` | `ERR_POOL_NOT_FOUND`            | A required liquidity pool was not found.         |
| `u1410` | `ERR_GET_AMOUNT_IN_FAILED`      | Failed to get the input amount for a swap.       |
| `u1411` | `ERR_REENTRANCY_GUARD_TRIGGERED`| A reentrancy guard was triggered.                |
| `u1412` | `ERR_SLIPPAGE_TOLERANCE_EXCEEDED`| The slippage tolerance was exceeded.             |
| `u1413` | `ERR_INVALID_PATH`              | The specified path is invalid.                   |
| `u1414` | `ERR_SWAP_FAILED`               | A swap failed.                                   |
| `u1415` | `ERR_TOKEN_TRANSFER_FAILED`     | A token transfer failed.                         |
