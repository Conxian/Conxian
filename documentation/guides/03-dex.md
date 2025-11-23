# Contract Guide: `multi-hop-router-v3.clar`

**Primary Contract:** `contracts/dex/multi-hop-router-v3.clar`

## 1. Introduction to the DEX Router

The `multi-hop-router-v3.clar` contract is the main entry point for executing trades on the Conxian DEX. It acts as a facade, delegating all core logic to a set of specialized, single-responsibility contracts. This modular design enhances security and maintainability.

## 2. Core Architecture

The `multi-hop-router-v3` contract does not compute routes or manage their execution directly. Instead, it delegates calls to the following specialized contracts:

-   **`dijkstra-pathfinder.clar`**: This contract is responsible for computing the most efficient path for a token swap using Dijkstra's algorithm.
-   **`route-manager.clar`**: This contract manages the lifecycle of a trade, from proposal to execution.

This architecture separates the core logic of the DEX router from the more specialized tasks of route computation and execution management.

## 3. How to Swap Tokens

### Step 1: Propose a Route

Call the `propose-route` function with the following parameters:

-   `token-in principal`: The token you want to sell.
-   `token-out principal`: The token you want to buy.
-   `amount-in uint`: The amount of `token-in` you want to sell.
-   `min-amount-out uint`: The minimum amount of `token-out` you are willing to accept.
-   `route-timeout uint`: The number of blocks after which the proposed route expires.

This function will return a `route-id`.

### Step 2: Execute the Route

Call the `execute-route` function with the following parameters:

-   `route-id uint`: The ID of the route you want to execute.
-   `min-amount-out uint`: The minimum amount of the output token you are willing to accept.
-   `recipient principal`: The address that will receive the output tokens.

## 4. Key Functions

| Function Name         | Parameters                                                                                                                              | Description                                                                                                                            |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `propose-route`       | `token-in principal`, `token-out principal`, `amount-in uint`, `min-amount-out uint`, `route-timeout uint`                                 | Computes the best route for a swap and returns a `route-id`.                                                                           |
| `execute-route`       | `route-id uint`, `min-amount-out uint`, `recipient principal`                                                                        | Executes a previously proposed route.                                                                                                  |
| `compute-best-route`  | `token-in principal`, `token-out principal`, `amount-in uint`                                                                             | A read-only function that computes the best route and returns the path and the expected output amount.                                |
| `get-route-stats`     | `route-id uint`                                                                                                                    | A read-only function that returns statistics for a given route, such as the number of hops and the expiration block.                   |

## 5. Admin Functions

| Function Name         | Parameters                | Description                                               |
| --------------------- | ------------------------- | --------------------------------------------------------- |
| `set-dijkstra-pathfinder`   | `pathfinder principal`         | Sets the address of the dijkstra-pathfinder contract.                         |
| `set-route-manager` | `manager principal`       | Sets the address of the route-manager contract.                               |
