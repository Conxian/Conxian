;; ===========================================
;; MULTI-HOP ROUTER V3
;; ===========================================
;; Advanced routing engine for optimal path finding across multiple DEX pools
;;
;; This contract implements multi-hop routing with support for:
;; - Multiple pool types (concentrated, stable, weighted)
;; - Slippage protection and price impact calculations
;; - Atomic execution with rollback on failure
;; - Route optimization for best prices

;; Use centralized traits
(use-trait rbac-trait .rbac-trait.rbac-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait pool-trait .all-traits.pool-trait)
(use-trait dim-registry-trait .all-traits.dim-registry-trait)
(use-trait dim-graph-trait .all-traits.dim-graph-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================

(define-constant MAX_HOPS u5)
(define-constant MAX_SLIPPAGE u1000) ;; 10% max slippage
(define-constant ROUTE_TIMEOUT u100) ;; blocks
;; 32-byte zero salt for deterministic placeholder route IDs
(define-constant ZERO32 0x0000000000000000000000000000000000000000000000000000000000000000)

;; ===========================================
;; ERROR CODES
;; ===========================================

(define-constant ERR_INVALID_ROUTE (err u7001))
(define-constant ERR_ROUTE_NOT_FOUND (err u7002))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u7003))
(define-constant ERR_HOP_LIMIT_EXCEEDED (err u7004))
(define-constant ERR_INVALID_TOKEN (err u7005))
(define-constant ERR_ROUTE_EXPIRED (err u7006))
(define-constant ERR_REENTRANCY_GUARD (err u7007))
(define-constant ERR_NO_PATH_FOUND (err u7008))
(define-constant ERR_DIJKSTRA_INIT_FAILED (err u7009))
(define-constant ERR_POOL_NOT_FOUND (err u7010))
(define-constant ERR_GET_AMOUNT_IN_FAILED (err u7011))

;; ===========================================
;; DATA VARIABLES
;; ===========================================

(define-data-var route-counter uint u0)
(define-data-var max-hops uint MAX_HOPS)
;; Configurable route timeout (defaults to constant)
(define-data-var route-timeout uint ROUTE_TIMEOUT)
(define-data-var reentrancy-guard bool false)

;; Principal index mapping (deterministic encoding without direct principal serialization)
(define-map principal-index principal uint)

;; Owner for administrative controls
;; (define-data-var contract-owner principal tx-sender) ; Removed as RBAC trait handles ownership

(define-data-var dim-registry principal tx-sender)
(define-data-var dim-graph principal tx-sender)

;; Dijkstra's related data maps
(define-map distances { token: principal } { cost: uint })
(define-map predecessors { token: principal } { prev-token: principal, pool: principal })
(define-constant UINT_MAX u170141183460469231731687303715884105727) ;; Represents infinity for distances

;; ===========================================
;; DATA MAPS
;; ===========================================

;; Store computed routes
(define-map routes
  { route-id: (buff 32) }
  {
    token-in: principal,
    token-out: principal,
    amount-in: uint,
    min-amount-out: uint,
    hops: (list 10 {pool: principal, token-in: principal, token-out: principal}),
    created-at: uint,
    expires-at: uint
  }
)

;; ===========================================
;; ROUTE COMPUTATION
;; ===========================================

;; @desc Retrieves a list of all known token principals in the system.
;;       Currently, this function returns a hardcoded list for demonstration and testing purposes.
;;       In a production environment, this would typically query a token registry or a similar contract
;;       to dynamically fetch available tokens.
;; @returns (list 20 principal) A list of all known token principals.
(define-private (get-all-known-tokens)
  ;; Placeholder: In a real system, this would query the dim-registry or a similar contract
  ;; For now, return a hardcoded list for demonstration/testing purposes.
  (list
    .contracts.mock-usda-token
    .contracts.mock-stx-token
    .contracts.mock-wbtc-token
  )
)

;; @desc Calculates the cost of traversing a pool, specifically the amount-in required for a certain amount-out.
;;       This function queries the `dim-registry` to find the appropriate pool contract for the given token pair
;;       and then calls the `get-amount-in` function on that pool to determine the swap cost.
;; @param pool-contract principal The principal of the pool contract to query.
;; @param token-in principal The principal of the input token.
;; @param token-out principal The principal of the output token.
;; @param amount-out uint The desired amount of the output token.
;; @returns (response uint (err u7010)) A response containing the amount-in required if successful, or an error code if the pool is not found or the factory call fails.
(define-private (get-pool-cost (pool-contract principal) (token-in principal) (token-out principal) (amount-out uint))
  (let ((factory-contract (var-get dim-registry)))
    (match (contract-call? factory-contract get-pool token-in token-out)
      (ok maybe-pool)
      (if (is-some maybe-pool)
        (let ((pool (unwrap-panic maybe-pool)))
          (contract-call? <pool-trait>pool get-amount-in token-in token-out amount-out)
        )
        (err ERR_POOL_NOT_FOUND)
      )
      (err e) (err ERR_GET_AMOUNT_IN_FAILED) ;; If factory call fails
    )
  )
)

;; @desc The main recursive loop for Dijkstra's algorithm, which iteratively finds the shortest paths
;;       from a source node to all other nodes in the graph. It processes unvisited nodes with the
;;       smallest known distance, updates distances to their neighbors, and marks them as visited.
;; @param visited-tokens (list 20 principal) A list of tokens that have already been visited and processed.
;; @param all-tokens (list 20 principal) A comprehensive list of all known tokens in the system.
;; @returns (response bool uint) Returns (ok true) if the algorithm completes successfully after visiting all reachable nodes, or an error if an unexpected issue occurs during the process.
(define-private (dijkstra-loop (visited-tokens (list 20 principal)) (all-tokens (list 20 principal)))
  (let ((current-node-option (get-unvisited-min-distance-node visited-tokens all-tokens)))
    (if (is-none current-node-option)
      (ok true) ;; All reachable nodes visited
      (let ((current-node (unwrap-panic current-node-option)))
        (begin
          (var-set visited-tokens (append visited-tokens current-node))
          (let ((neighbors (get-neighbors current-node)))
            (fold neighbors (ok true)
              (lambda (neighbor-info acc)
                (let ((neighbor-token (get token neighbor-info))
                      (pool-contract (get pool neighbor-info))
                      (current-distance (unwrap-panic (map-get? distances { token: current-node }))))
                  ;; Calculate the actual cost of traversing this edge (pool)
                  (match (get-pool-cost pool-contract current-node neighbor-token u1) ;; Assuming 1 unit of neighbor-token for now
                    (ok traversal-cost)
                    (let ((new-distance (+ (get cost current-distance) traversal-cost)))
                      (if (> (get cost (unwrap-panic (map-get? distances { token: neighbor-token }))) new-distance)
                        (begin
                          (map-set distances { token: neighbor-token } { cost: new-distance })
                          (map-set predecessors { token: neighbor-token } { prev-token: current-node, pool: pool-contract })
                        )
                        true
                      )
                    )
                    (err e) ;; If pool cost calculation fails, treat as infinite cost for this path
                    true
                  )
                  acc
                )
              )
            )
          )
          (dijkstra-loop visited-tokens all-tokens)
        )
      )
    )
  )
)

;; @desc Finds the optimal route between a specified input token and an output token, considering a given input amount.
;;       This function utilizes Dijkstra's algorithm to compute the shortest path based on pool costs.
;;       It initializes Dijkstra's data structures, runs the main algorithm loop, and then reconstructs the path.
;; @param token-in principal The principal of the input token for the swap.
;; @param token-out principal The principal of the desired output token.
;; @param amount-in uint The amount of the input token to be swapped.
;; @returns (response (list 10 {pool: principal, token-in: principal, token-out: principal, amount-in: uint, amount-out: uint}) (err u7008)) A response containing the best route as a list of hops and a placeholder amount-out if successful, or an error if no path is found or Dijkstra's initialization fails.
(define-read-only (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((all-tokens (get-all-known-tokens)))
    (asserts! (is-ok (initialize-dijkstra-data token-in all-tokens)) (err ERR_DIJKSTRA_INIT_FAILED))
    (asserts! (is-ok (dijkstra-loop (list) all-tokens)) (err ERR_NO_PATH_FOUND))

    ;; Path reconstruction
    (let ((path (list)))
      (let ((current-token token-out))
        (while (and (not (is-eq current-token token-in)) (is-some (map-get? predecessors { token: current-token })))
          (let ((prev-info (unwrap-panic (map-get? predecessors { token: current-token }))))
            (var-set path (cons {pool: (get pool prev-info), token-in: (get prev-token prev-info), token-out: current-token} path))
            (var-set current-token (get prev-token prev-info))
          )
        )
      )
      (if (is-eq current-token token-in)
        (ok path u0) ;; u0 is a placeholder for amount-out, will be calculated later
        (err ERR_NO_PATH_FOUND)
      )
    )
  )
)

;; ===========================================
;; ROUTE EXECUTION
;; ===========================================

;; @desc Executes a previously computed multi-hop route.
;; @param route-id The ID of the route to execute.
;; @param recipient The principal to receive the output tokens.
;; @returns (ok uint) The amount of tokens received by the recipient.
;; @events (print (ok uint))
(define-public (execute-route (route-id (buff 32)) (recipient principal))
  (let ((route (unwrap! (map-get? routes { route-id: route-id }) ERR_INVALID_ROUTE)))
    (begin
      ;; Check route hasn't expired
      (asserts! (< block-height (get expires-at route)) ERR_ROUTE_EXPIRED)

      ;; Execute the multi-hop swap
      (let ((result (execute-multi-hop-swap (get hops route) (get amount-in route) recipient)))
        (let ((final-amount (unwrap! result ERR_INSUFFICIENT_OUTPUT)))

          ;; Check minimum output
          (asserts! (>= final-amount (get min-amount-out route)) ERR_INSUFFICIENT_OUTPUT)

          ;; Clean up route after execution
          (map-delete routes { route-id: route-id })

          (ok final-amount)
        )
      )
    )
  )
)

;; ===========================================
;; ROUTE STATISTICS
;; ===========================================

;; @desc Retrieves statistics for a given route ID.
;; @param route-id The ID of the route.
;; @returns (ok (tuple (hops uint) (estimated-out uint) (expires-at uint))) Route statistics.
(define-read-only (get-route-stats (route-id (buff 32)))
  (match (map-get? routes { route-id: route-id })
    route (ok (tuple
                (hops (len (get hops route)))
                (estimated-out (get min-amount-out route))
                (expires-at (get expires-at route))))
    (err ERR_INVALID_ROUTE)
  )
)

;; ===========================================
;; ADMIN FUNCTIONS
;; ===========================================

;; (define-public (set-owner (new-owner principal))
;;   (begin
;;     (asserts! (contract-call? .rbac-trait is-owner tx-sender) ERR_INVALID_ROUTE)
;;     (var-set contract-owner new-owner)
;;     (ok true)
;;   )
;; ) ; Removed as RBAC trait handles ownership and this function is now redundant

;; @desc Sets the principal of the DIM graph contract. Only callable by the contract owner.
;; @param graph The principal of the DIM graph contract.
;; @returns (ok bool) True if the operation was successful.
(define-public (set-dim-graph (graph principal))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) ERR_INVALID_ROUTE)
    (var-set dim-graph graph)
    (ok true)
  )
)

;; @desc Sets the index for a given principal. Only callable by the contract owner.
;; @param p The principal to set the index for.
;; @param idx The index to assign to the principal.
;; @returns (ok bool) True if the operation was successful.
(define-public (set-principal-index (p principal) (idx uint))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) ERR_INVALID_ROUTE)
    (map-set principal-index p idx)
    (ok true)
  )
)

;; @desc Sets the maximum number of hops allowed for a route. Only callable by the contract owner.
;; @param new-max The new maximum number of hops.
;; @returns (ok bool) True if the operation was successful.
(define-public (set-max-hops (new-max uint))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) ERR_INVALID_ROUTE)
    (var-set max-hops new-max)
    (ok true)
  )
)

;; @desc Sets the route timeout in block heights. Only callable by the contract owner.
;; @param new-timeout The new route timeout in block heights.
;; @returns (ok bool) True if the operation was successful.
(define-public (set-route-timeout (new-timeout uint))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) ERR_INVALID_ROUTE)
    (var-set route-timeout new-timeout)
    (ok true)
  )
)

;; @desc Retrieves the index for a given principal.
;; @param p The principal to retrieve the index for.
;; @returns (ok uint) The index of the principal, or u0 if not found.
(define-read-only (get-principal-index (p principal))
  (ok (default-to u0 (map-get? principal-index p)))
)

;; ===========================================
;; INTERNAL FUNCTIONS
;; ===========================================

;; @desc Initializes the Dijkstra algorithm data structures.
;; @param start-token The starting token for the route.
;; @param all-tokens A list of all known token principals.
;; @returns (ok bool) True if initialization is successful.
(define-private (initialize-dijkstra-data (start-token principal) (all-tokens (list 20 principal)))
  (begin
    (map-set distances { token: start-token } { cost: u0 })
    (fold all-tokens true
      (lambda (token-node acc)
        (if (not (is-eq token-node start-token))
          (map-set distances { token: token-node } { cost: UINT_MAX })
          true
        )
      )
    )
    (ok true)
  )
)

;; @desc Finds the unvisited token with the minimum distance.
;; @param visited (list 20 principal) A list of already visited token principals.
;; @param all-tokens (list 20 principal) A list of all known token principals.
;; @returns (optional principal) The principal of the unvisited token with the minimum distance, or none if all are visited.
(define-private (get-unvisited-min-distance-node (visited (list 20 principal)) (all-tokens (list 20 principal)))
  (fold all-tokens none
    (lambda (token current-min-node)
      (if (not (is-some (find-in-list visited token)))
        (let ((current-distance (default-to UINT_MAX (get cost (map-get? distances { token: token })))))
          (if (is-none current-min-node)
            (some token)
            (let ((min-node-distance (default-to UINT_MAX (get cost (map-get? distances { token: (unwrap-panic current-min-node) })))))
              (if (< current-distance min-node-distance)
                (some token)
                current-min-node
              )
            )
          )
        )
        current-min-node
      )
    )
  )
)

;; @desc Helper to check if a principal exists in a list.
;; @param lst (list 20 principal) The list to search.
;; @param p principal The principal to find.
;; @returns (optional principal) The principal if found, otherwise none.
(define-private (find-in-list (lst (list 20 principal)) (p principal))
  (fold lst none
    (lambda (item acc)
      (if (is-eq item p)
        (some p)
        acc
      )
    )
  )
)

;; @desc Gets all direct neighbors (tokens) reachable from a given token via available pools.
;; @param current-token principal The token for which to find neighbors.
;; @returns (list 10 {token: principal, pool: principal}) A list of neighboring tokens and the pools connecting them.
(define-private (get-neighbors (current-token principal))
  (let ((dim-registry-contract (var-get dim-registry)))
    (match (contract-call? dim-registry-contract get-all-pools-for-token current-token)
      (ok pools-info)
      (fold pools-info (list)
        (lambda (pool-info acc)
          (let ((pool-contract (get pool-contract pool-info))
                (token-x (get token-x pool-info))
                (token-y (get token-y pool-info)))
            (if (is-eq current-token token-x)
              (append acc (list {token: token-y, pool: pool-contract}))
              (append acc (list {token: token-x, pool: pool-contract}))
            )
          )
        )
      )
      (err e) (list) ;; Return empty list on error
    )
  )
)

;; @desc Finds the best route between two tokens, considering direct and two-hop routes.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) The best route found, or none.
(define-private (find-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((direct-route (try-direct-route token-in token-out amount-in))
        (two-hop-route (try-two-hop-route token-in token-out amount-in)))
    (select-better-route direct-route two-hop-route)
  )
)

;; @desc Attempts to find a direct route between two tokens.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) A direct route if found, or none.
(define-private (try-direct-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((pools (get-pools-for-pair token-in token-out)))
    (match (get-best-pool pools token-in token-out amount-in)
      best
      (some {
        hops: (list { pool: (get pool best), token-in: token-in, token-out: token-out }),
        min-amount-out: (get amount-out best)
      })
      none
    )
  )
)

;; @desc Attempts to find a two-hop route between two tokens using dynamic intermediaries.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) A two-hop route if found, or none.
(define-private (try-two-hop-route (token-in principal) (token-out principal) (amount-in uint))
  (let (
    (dim-registry-contract (var-get dim-registry))
    (all-tokens (contract-call? dim-registry-contract get-all-tokens))
  )
    (if (is-ok all-tokens)
      (let ((intermediaries (filter (lambda (token) (and (!= token token-in) (!= token token-out))) (unwrap-panic all-tokens))))
        (find-best-intermediary intermediaries token-in token-out amount-in)
      )
      none ;; Handle error if get-all-tokens fails
    )
  )
)

;; @desc Finds a two-hop route through a specific intermediary.
;; @param token-a The starting token principal.
;; @param token-b The intermediary token principal.
;; @param token-c The final token principal.
;; @param amount-a The amount of the starting token.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) A two-hop route if successful, or none.
(define-private (find-two-hop-route-with-intermediaries (token-a principal) (token-b principal) (token-c principal) (amount-a uint))
  (let ((first-route (try-direct-route token-a token-b amount-a)))
    (if (is-some first-route)
      (let ((first-output (get min-amount-out (unwrap-panic first-route))))
        (let ((second-route (try-direct-route token-b token-c first-output)))
          (if (is-some second-route)
            (some {
              hops: (append (get hops (unwrap-panic first-route)) (get hops (unwrap-panic second-route))),
              min-amount-out: (get min-amount-out (unwrap-panic second-route))
            })
            none
          )
        )
      )
      none
    )
  )
)

;; @desc Compares two optional routes and returns the one with the higher `min-amount-out`.
;; @param route-a The first optional route.
;; @param route-b The second optional route.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) The better route, or none if both are none.
(define-private (compare-routes (route-a (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint})) (route-b (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint})))
  (match (list route-a route-b)
    ((list (some r-a) (some r-b))
      (if (> (get min-amount-out r-a) (get min-amount-out r-b))
        route-a
        route-b
      )
    )
    ((list (some r-a) none) route-a)
    ((list none (some r-b)) route-b)
    (else none)
  )
)

;; @desc Finds the best two-hop route by iterating through a list of intermediaries.
;; @param intermediaries A list of potential intermediary token principals.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) The best two-hop route found, or none.
(define-private (find-best-intermediary (intermediaries (list 10 principal)) (token-in principal) (token-out principal) (amount-in uint))
  (fold intermediaries none
    (lambda (intermediary best-route)
      (let ((candidate-route (find-two-hop-route-with-intermediaries token-in intermediary token-out amount-in)))
        (compare-routes candidate-route best-route)
      )
    )
  )
)

;; @desc Executes a multi-hop swap by iterating through the provided hops.
;; @param hops A list of hop details, including pool, input token, and output token.
;; @param amount-in The initial amount of input tokens for the first hop.
;; @param recipient The principal to receive the final output tokens.
;; @returns (ok uint) The final amount of tokens received by the recipient.
;; @events (print (ok uint))
(define-private (execute-multi-hop-swap (hops (list 10 {pool: principal, token-in: principal, token-out: principal})) (amount-in uint) (recipient principal))
  (begin
    (asserts! (not (var-get reentrancy-guard)) (err u7007)) ;; ERR_REENTRANCY_GUARD
    (var-set reentrancy-guard true)
    (let (
      (dim-graph-contract (var-get dim-graph))
      (dim-registry-contract (var-get dim-registry))
    )
      (let ((result (fold hops (ok amount-in)
        (lambda (hop result)
          (match result
            (ok current-amount)
            (let (
              (from-dim (unwrap! (contract-call? dim-registry-contract get-dimension-id (get token-in hop)) (err ERR_INVALID_TOKEN)))
              (to-dim (unwrap! (contract-call? dim-registry-contract get-dimension-id (get token-out hop)) (err ERR_INVALID_TOKEN)))
            )
              (try! (contract-call? dim-graph-contract set-edge from-dim to-dim current-amount))
              (contract-call? (get pool hop) swap (get token-in hop) (get token-out hop) current-amount u0 recipient)
            )
            err-result
            err-result
          )
        )
      )))
      (var-set reentrancy-guard false)
      result
    ))
  )
)

;; @desc Finds the best pool from a list of pools for a given token pair and input amount.
;; @param pools A list of pool principals.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {pool: principal, amount-out: uint}) The best pool and its output amount, or none.
(define-private (get-best-pool (pools (list 10 principal)) (token-in principal) (token-out principal) (amount-in uint))
  (fold pools none
    (lambda (pool current-best)
      (let ((maybe-amount (contract-call? pool get-amount-out token-in token-out amount-in)))
        (match maybe-amount
          (ok amount-out)
          (if (or (is-none current-best) (> amount-out (get amount-out (unwrap-panic current-best))))
            (some {
              pool: pool,
              amount-out: amount-out
            })
            current-best)
          (err e)
          current-best
        )
      )
    )
  )
)

;; @desc Selects the better of two optional routes based on the `min-amount-out`.
;; @param current The current best route (optional).
;; @param candidate A candidate route to compare (optional).
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) The route with the higher `min-amount-out`.
(define-private (select-better-route (current (optional (tuple (hops (list 10 {pool: principal, token-in: principal, token-out: principal})) (min-amount-out uint)))) (candidate (optional (tuple (hops (list 10 {pool: principal, token-in: principal, token-out: principal})) (min-amount-out uint)))))
  (if (is-none candidate)
      current
      (if (is-none current)
          candidate
          (if (>
                (get min-amount-out (unwrap-panic candidate))
                (get min-amount-out (unwrap-panic current)))
              candidate
              current)))
)

;; @desc Generates a unique route ID based on input and output tokens and amount.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (buff 32) A unique route ID.
(define-private (generate-route-id (token-in principal) (token-out principal) (amount-in uint))
  (let (
    (in-idx (default-to u0 (map-get? principal-index token-in)))
    (out-idx (default-to u0 (map-get? principal-index token-out)))
  )
    (unwrap-panic (contract-call? .utils-encoding encode-route-id in-idx out-idx amount-in ZERO32))
  )
)

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

;; @desc Fetches available pools for a given token pair using the DIM registry.
;; @param token-in The principal of the input token.
;; @param token-out The principal of the output token.
;; @returns (list 10 principal) A list of pool principals for the given token pair.
(define-private (get-pools-for-pair (token-in principal) (token-out principal))
  (match (contract-call? (var-get dim-registry) get-pools-for-pair token-in token-out)
    (ok pools) pools
    (err e) (list)
  )
)

;; @desc Sets the DIM registry contract principal.
;; @param registry The principal of the DIM registry contract.
;; @returns (response bool uint) A boolean indicating success or failure, and an error code if failed.
(define-public (set-dim-registry (registry principal))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) ERR_INVALID_ROUTE)
    (var-set dim-registry registry)
    (ok true)
  )
)

(define-public (set-max-hops (new-max uint))
  (begin
    (asserts! (<= new-max MAX_HOPS) ERR_HOP_LIMIT_EXCEEDED)
    (var-set max-hops new-max)
    (ok true)
  )
)

(define-read-only (get-max-hops)
  (ok (var-get max-hops))
)