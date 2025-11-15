;; ===========================================
;; ROUTER TRAIT
;; ===========================================
;; @desc Interface for a multi-hop router.
;; This trait defines the core functionality for routing swaps
;; across multiple pools and token pairs.
;;
;; @example
;; (use-trait router-trait .router-trait.router-trait)
(define-trait router-trait
  (
    ;; @desc Adds a token node to the routing graph.
    ;; @param token: The principal of the token to add.
    ;; @returns (response uint uint): The token index, or an error code.
    (add-token (token principal)) (response uint uint))

    ;; @desc Adds an edge (pool connection) between two tokens.
    ;; @param token-from: The source token.
    ;; @param token-to: The destination token.
    ;; @param pool: The pool contract connecting the tokens.
    ;; @param pool-type: The type of pool (e.g., "constant-product").
    ;; @param liquidity: The available liquidity in the pool.
    ;; @param fee: The swap fee for this pool.
    ;; @returns (response bool uint): True if successful, or an error.
    (add-edge (token-from principal) (token-to principal) (pool principal) (pool-type (string-ascii 20)) (liquidity uint) (fee uint)) (response bool uint))

    ;; @desc Finds the optimal swap path between two tokens.
    ;; @param token-in: The input token.
    ;; @param token-out: The output token.
    ;; @param amount-in: The amount of the input token.
    ;; @returns (response { path: (list 20 principal), distance: uint, hops: uint } uint): A tuple containing the optimal path data, or an error code.
    (find-optimal-path (token-in principal) (token-out principal) (amount-in uint)) (response { path: (list 20 principal), distance: uint, hops: uint } uint))

    ;; @desc Executes a swap along the optimal path.
    ;; @param token-in: The input token.
    ;; @param token-out: The output token.
    ;; @param amount-in: The amount of the input token.
    ;; @param min-amount-out: The minimum acceptable output amount.
    ;; @returns (response { amount-out: uint, path: (list 20 principal), hops: uint, distance: uint } uint): A tuple containing the swap result, or an error code.
    (swap-optimal-path (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint)) (response { amount-out: uint, path: (list 20 principal), hops: uint, distance: uint } uint))

    ;; @desc Gets statistics about the routing graph.
    ;; @returns (response { nodes: uint, edges: uint } uint): A tuple containing the graph statistics, or an error code.
    (get-graph-stats) (response { nodes: uint, edges: uint } uint))

    ;; @desc Gets the index of a token in the graph.
    ;; @param token: The token principal to look up.
    ;; @returns (response (optional uint) uint): The token index, or none if not found.
    (get-token-index (token principal)) (response (optional uint) uint))

    ;; @desc Gets information about an edge between two tokens.
    ;; @param from-token: The source token.
    ;; @param to-token: The destination token.
    ;; @returns (response (optional { ... }) uint): A tuple containing the edge information, or none if not found.
    (get-edge-info (from-token principal) (to-token principal)) (response (optional { pool: principal, pool-type: (string-ascii 20), weight: uint, liquidity: uint, fee: uint, active: bool }) uint))

    ;; @desc Estimates the output amount for a swap.
    ;; @param token-in: The input token.
    ;; @param token-out: The output token.
    ;; @param amount-in: The amount of the input token.
    ;; @returns (response { path: (list 20 principal), distance: uint, hops: uint } uint): A tuple containing the estimated output and path, or an error code.
    (estimate-swap-output (token-in principal) (token-out principal) (amount-in uint)) (response { path: (list 20 principal), distance: uint, hops: uint } uint))
  )
)
