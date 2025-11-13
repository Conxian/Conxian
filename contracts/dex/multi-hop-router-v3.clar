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

;; Use decentralized modular traits
(use-trait rbac-trait .base-traits.rbac-trait)
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait pool-trait .dex-traits.pool-trait)
(use-trait dim-registry-trait .dim-registry-trait.dim-registry-trait)
;; Note: dim-graph-trait and err-trait need to be added to modules or created
(use-trait dim-graph-trait .dimensional-traits.dim-graph-trait)
(use-trait err-trait .standard-errors.err-trait)

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

(define-constant ERR_INVALID_ROUTE (err u1400)) ;; New error code for invalid route
(define-constant ERR_ROUTE_NOT_FOUND (err u1401)) ;; New error code for route not found
(define-constant ERR_INSUFFICIENT_OUTPUT (err u1402)) ;; New error code for insufficient output
(define-constant ERR_HOP_LIMIT_EXCEEDED (err u1403)) ;; New error code for hop limit exceeded
(define-constant ERR_INVALID_TOKEN (err u1404)) ;; New error code for invalid token
(define-constant ERR_ROUTE_EXPIRED (err u1405)) ;; New error code for route expired
(define-constant ERR_REENTRANCY_GUARD (err u1406)) ;; New error code for reentrancy guard
(define-constant ERR_NO_PATH_FOUND (err u1407)) ;; New error code for no path found
(define-constant ERR_DIJKSTRA_INIT_FAILED (err u1408)) ;; New error code for Dijkstra initialization failed
(define-constant ERR_POOL_NOT_FOUND (err u1409)) ;; New error code for pool not found
(define-constant ERR_GET_AMOUNT_IN_FAILED (err u1410)) ;; New error code for get amount in failed
(define-constant ERR_ROUTE_ALREADY_EXECUTED (err u1416)) ;; New error code for route already executed
(define-constant ERR_REENTRANCY_GUARD_TRIGGERED (err u1411)) ;; New error code for reentrancy guard triggered
(define-constant ERR_SLIPPAGE_TOLERANCE_EXCEEDED (err u1412)) ;; New error code for slippage tolerance exceeded
(define-constant ERR_INVALID_PATH (err u1413)) ;; New error code for invalid path
(define-constant ERR_SWAP_FAILED (err u1414)) ;; New error code for swap failed
(define-constant ERR_TOKEN_TRANSFER_FAILED (err u1415)) ;; New error code for token transfer failed

;; ==========================================================================
;; Data Variables
;; ==========================================================================

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
(define-map distances { token: principal } { cost: uint, amount-in: uint })
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
;;       In a production environment, this would typically query a token registry or a similar contract
;;       to dynamically fetch available tokens.
;; @returns (list 20 principal) A list of all known token principals.
;; @desc Retrieves a list of all known tokens from the DIM registry.
;; @returns (response (list 20 principal) (err u1438)) A list of token principals, or an error if the registry call fails.
;; @error u1438 If no tokens are found or the registry call encounters an error.
(define-private (get-all-known-tokens)
  (unwrap! (contract-call? (var-get dim-registry) get-all-tokens) (err u1438))
);; @param token-out principal The principal of the output token.
;; @param amount-out uint The desired amount of the output token.
;; @returns (response uint (err u1409)) A response containing the amount-in required if successful, or an error code if the pool is not found or the factory call fails.
;; @desc Calculates the cost (amount-in) for a given swap in a specific pool.
;; @param pool-contract The principal of the pool contract.
;; @param token-in The principal of the input token.
;; @param token-out The principal of the output token.
;; @param amount-out The desired amount of output tokens.
;; @returns (response uint (err u1437)) The amount of input tokens required, or an error.
;; @error u1437 If the pool is not found or the get-amount-in call fails.
(define-private (get-pool-cost (pool-contract principal) (token-in principal) (token-out principal) (amount-out uint))
  (let ((factory-contract (var-get dim-registry)))
    (match (contract-call? factory-contract get-pool token-in token-out)
      (ok maybe-pool)
      (if (is-some maybe-pool)
        (let ((pool (unwrap-panic maybe-pool)))
          (contract-call? pool get-amount-in token-in token-out amount-out)
        )
        (err u1437) ;; ERR_POOL_NOT_FOUND
      )
      (err e) (err u1437) ;; ERR_GET_AMOUNT_IN_FAILED
    )
  )
);;       smallest known distance, updates distances to their neighbors, and marks them as visited.
;; @param visited-tokens (list 20 principal) A list of tokens that have already been visited and processed.
;; @param all-tokens (list 20 principal) A comprehensive list of all known tokens in the system.
;; @returns (response bool (err u1407)) Returns (ok true) if the algorithm completes successfully after visiting all reachable nodes, or an error if an unexpected issue occurs during the process.
;; @desc Iteratively applies Dijkstra's algorithm to find the shortest paths.
;; @param visited-tokens A list of tokens that have already been visited.
;; @param all-tokens A list of all known tokens in the graph.
;; @returns (response bool (err u1433)) True if the loop completes successfully, or an error.
;; @error u1433 If an unexpected error occurs during the Dijkstra loop.
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
                      (current-distance-entry (unwrap-panic (map-get? distances { token: current-node })))
                      (current-amount (get amount-in current-distance-entry)) ;; Correctly retrieve amount-in
                      )
                  ;; Calculate the actual cost of traversing this edge (pool)
                  (match (get-pool-cost pool-contract current-node neighbor-token current-amount)
                    (ok traversal-cost)
                    (let ((new-distance (+ (get cost current-distance-entry) traversal-cost)))
                      (if (> (get cost (unwrap-panic (map-get? distances { token: neighbor-token }))) new-distance)
                        (begin
                          (map-set distances { token: neighbor-token } { cost: new-distance, amount-in: current-amount })
                          (map-set predecessors { token: neighbor-token } { prev-token: current-node, pool: pool-contract })
                        )
                        true
                      )
                    )
                    (err e) ;; If pool cost calculation fails, treat as infinite cost for this path
                    (err u1433) ;; ERR_DIJKSTRA_LOOP_FAILED
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
);; @returns (response (list 10 {pool: principal, token-in: principal, token-out: principal, amount-in: uint, amount-out: uint}) (err u1408)) A response containing the best route as a list of hops and a placeholder amount-out if successful, or an error if no path is found or Dijkstra's initialization fails.
;; @desc Computes the best multi-hop route between two tokens.
;; @param token-in The principal of the input token.
;; @param token-out The principal of the output token.
;; @param amount-in The amount of input tokens.
;; @returns (response {path: (list 10 {pool: principal, token-in: principal, token-out: principal}), amount-out: uint} (err u1432)) The best route found and the amount out, or an error.
;; @error u1432 If Dijkstra initialization fails, no path is found, or an unexpected error occurs.
(define-read-only (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((all-tokens (get-all-known-tokens)))
    (asserts! (is-ok (initialize-dijkstra-data token-in all-tokens)) (err u1432)) ;; ERR_DIJKSTRA_INIT_FAILED
    (asserts! (is-ok (dijkstra-loop (list) all-tokens)) (err u1432)) ;; ERR_NO_PATH_FOUND

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
        (let ((final-amount-out (fold path amount-in
          (lambda (hop current-input-amount)
            (unwrap-panic (contract-call? (get pool hop) get-amount-out (get token-in hop) (get token-out hop) current-input-amount))
          )
        )))
          (ok {path: path, amount-out: final-amount-out})
        )
        (err u1432) ;; ERR_NO_PATH_FOUND
      )
    )
  )
);; @param route-timeout uint The block height at which the proposed route expires.
;; @returns (response (buff 32) (err u1401)) A response containing the route ID if successful, or an error code if the operation fails.
;; @desc Proposes a multi-hop route for a token swap and stores it for later execution.
;; @param token-in The principal of the input token.
;; @param token-out The principal of the output token.
;; @param amount-in The amount of input tokens.
;; @param min-amount-out The minimum amount of output tokens expected.
;; @param route-timeout The number of blocks after which the proposed route expires.
;; @returns (response uint (err u1431)) The ID of the proposed route, or an error.
;; @error u1431 If no route is found, hop limit exceeded, or insufficient output.
(define-public (propose-route (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (route-timeout uint))
  (let
    (
      (current-route-id (var-get route-counter))
      (best-route-result (compute-best-route token-in token-out amount-in))
    )
    (asserts! (is-ok best-route-result) (err u1431)) ;; ERR_ROUTE_NOT_FOUND or other compute-best-route errors
    (let
      (
        (best-route (unwrap-panic best-route-result))
        (final-amount-out (get amount-out best-route))
        (path (get path best-route))
        (hops-count (len path))
      )
      (asserts! (> final-amount-out u0) (err u1431)) ;; ERR_ROUTE_NOT_FOUND
      (asserts! (<= hops-count (var-get max-hops)) (err u1431)) ;; ERR_HOP_LIMIT_EXCEEDED
      (asserts! (>= final-amount-out min-amount-out) (err u1431)) ;; ERR_INSUFFICIENT_OUTPUT

      (map-set routes { route-id: current-route-id }
        {
          token-in: token-in,
          token-out: token-out,
          amount-in: amount-in,
          min-amount-out: min-amount-out,
          path: path, ;; Store the actual path
          created-at: block-height,
          expires-at: (+ block-height route-timeout)
        }
      )
      (var-set route-counter (+ current-route-id u1))
      (ok current-route-id)
    )
  )
)

(define-public (set-factory (factory principal))
  (begin
    (var-set dim-registry factory)
    (ok true)
  )
)

;; @desc Executes a previously proposed and stored route.
;; @param route-id The ID of the route to execute (as buff 32).
;; @param min-amount-out The minimum amount of output tokens expected.
;; @param recipient The principal to receive the final output tokens.
;; @returns (response uint (err u1430)) The actual amount of output tokens received, or an error.
;; @error u1430 If the route is not found, expired, or the swap fails, or output is insufficient.
(define-public (execute-route (route-id (buff 32)) (min-amount-out uint) (recipient principal))
  (let ((route-data (map-get? routes { route-id: route-id })))
    (asserts! (is-some route-data) (err u1430)) ;; ERR_ROUTE_NOT_FOUND
    (let ((route (unwrap-panic route-data)))
      (asserts! (< block-height (get expires-at route)) (err u1430)) ;; ERR_ROUTE_EXPIRED
      (let ((actual-amount-out (execute-multi-hop-swap (get hops route) (get amount-in route) recipient)))
        (asserts! (is-ok actual-amount-out) (err u1430)) ;; ERR_SWAP_FAILED
        (asserts! (>= (unwrap-panic actual-amount-out) min-amount-out) (err u1430)) ;; ERR_INSUFFICIENT_OUTPUT
        (map-delete routes { route-id: route-id })
        actual-amount-out
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
;; @error u1415 If the caller is not the contract owner.
(define-public (set-dim-graph (graph principal))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender) (err u1415)) ;; ERR_UNAUTHORIZED_OWNER
    (var-set dim-graph graph)
    (ok true)
  )
)

;; @desc Sets the index for a given principal. Only callable by the contract owner.
;; @param p The principal to set the index for.
;; @param idx The index to assign to the principal.
;; @returns (ok bool) True if the operation was successful.
;; @error u1416 If the caller is not the contract owner.
(define-public (set-principal-index (p principal) (idx uint))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender) (err u1416)) ;; ERR_UNAUTHORIZED_OWNER
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
;; @error u1414 If the caller is not the contract owner.
(define-public (set-route-timeout (new-timeout uint))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender) (err u1414)) ;; ERR_UNAUTHORIZED_OWNER
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
;; @returns (response bool (err u1417)) True if initialization is successful, or an error if the token list is empty.
;; @desc Initializes the distances and predecessors maps for Dijkstra's algorithm.
;; @param start-token The starting token for the pathfinding.
;; @param all-tokens A list of all known tokens in the graph.
;; @returns (response bool (err u1434)) True if initialization is successful, or an error.
;; @error u1434 If the token list is empty or an unexpected error occurs.
(define-private (initialize-dijkstra-data (start-token principal) (all-tokens (list 20 principal)))
  (begin
    (asserts! (> (len all-tokens) u0) (err u1434)) ;; ERR_EMPTY_TOKEN_LIST
    (map-set distances { token: start-token } { cost: u0, amount-in: u0 })
    (fold all-tokens true
      (lambda (token-node acc)
        (if (not (is-eq token-node start-token))
          (map-set distances { token: token-node } { cost: UINT_MAX, amount-in: u0 })
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
;; @error u1418 If there's an unexpected error retrieving distance.
;; @desc Finds the unvisited token with the minimum distance from the source.
;; @param visited A list of already visited token principals.
;; @param all-tokens A list of all known token principals.
;; @returns (optional principal) The principal of the unvisited token with the minimum distance, or none if all are visited.
;; @error u1435 If there's an unexpected error retrieving distance.
(define-private (get-unvisited-min-distance-node (visited (list 20 principal)) (all-tokens (list 20 principal)))
  (fold all-tokens none
    (lambda (token current-min-node)
      (if (not (is-some (find-in-list visited token)))
        (let ((current-distance (default-to UINT_MAX (get cost (unwrap! (map-get? distances { token: token }) (err u1435))))))
          (if (is-none current-min-node)
            (some token)
            (let ((min-node-distance (default-to UINT_MAX (get cost (unwrap! (map-get? distances { token: (unwrap-panic current-min-node) }) (err u1435))))))
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
;; @error u1419 If the list is empty.
;; @desc Checks if a principal exists in a list of principals.
;; @param lst A list of principals to search within.
;; @param p The principal to search for.
;; @returns (optional principal) The principal if found, otherwise none.
;; @error u1436 If the provided list is empty.
(define-private (find-in-list (lst (list 20 principal)) (p principal))
  (asserts! (> (len lst) u0) (err u1436)) ;; ERR_EMPTY_LIST
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
;; @returns (response (list 10 {token: principal, pool: principal}) (err u1420)) A list of neighboring tokens and the pools connecting them, or an error if the DIM registry call fails.
(define-private (get-neighbors (current-token principal))
  (let ((dim-registry-contract (var-get dim-registry)))
    (match (contract-call? dim-registry-contract get-all-pools-for-token current-token)
      (ok pools-info)
      (ok (fold pools-info (list)
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
      ))
      (err e) (err u1420) ;; ERR_DIM_REGISTRY_CALL_FAILED
    )
  )
)

;; @desc Finds the best route between two tokens, considering direct and two-hop routes.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (response (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) (err u1421)) The best route found, or an error if route finding fails.
(define-private (find-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((direct-route (try-direct-route token-in token-out amount-in))
        (two-hop-route (try-two-hop-route token-in token-out amount-in)))
    (ok (select-better-route direct-route two-hop-route))
  )
)

;; @desc Attempts to find a direct route between two tokens.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (response (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) (err u1422)) A direct route if found, or an error if no pool is found.
(define-private (try-direct-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((pools (unwrap! (get-pools-for-pair token-in token-out) (err u1422)))) ;; ERR_NO_POOL_FOR_PAIR
    (match (get-best-pool pools token-in token-out amount-in)
      best
      (ok (some {
        hops: (list { pool: (get pool best), token-in: token-in, token-out: token-out }),
        min-amount-out: (get amount-out best)
      }))
      (ok none)
    )
  )
)

;; @desc Attempts to find a two-hop route between two tokens using dynamic intermediaries.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (response (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) (err u1423)) A two-hop route if found, or an error if token retrieval fails.
(define-private (try-two-hop-route (token-in principal) (token-out principal) (amount-in uint))
  (let (
    (dim-registry-contract (var-get dim-registry))
    (all-tokens (contract-call? dim-registry-contract get-all-tokens))
  )
    (if (is-ok all-tokens)
      (let ((intermediaries (filter (lambda (token) (and (!= token token-in) (!= token token-out))) (unwrap-panic all-tokens))))
        (ok (find-best-intermediary intermediaries token-in token-out amount-in))
      )
      (err u1423) ;; ERR_GET_ALL_TOKENS_FAILED
    )
  )
)

;; @desc Finds a two-hop route through a specific intermediary.
;; @param token-a The starting token principal.
;; @param token-b The intermediary token principal.
;; @param token-c The final token principal.
;; @param amount-a The amount of the starting token.
;; @returns (response (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) (err u1424)) A two-hop route if successful, or an error if route finding fails.
(define-private (find-two-hop-route-with-intermediaries (token-a principal) (token-b principal) (token-c principal) (amount-a uint))
  (let ((first-route (try-direct-route token-a token-b amount-a)))
    (if (is-ok first-route)
      (let ((first-output (get min-amount-out (unwrap! first-route (err u1424)))))
        (let ((second-route (try-direct-route token-b token-c first-output)))
          (if (is-ok second-route)
            (ok (some {
              hops: (append (get hops (unwrap! first-route (err u1424))) (get hops (unwrap! second-route (err u1424)))),
              min-amount-out: (get min-amount-out (unwrap! second-route (err u1424)))
            }))
            (ok none)
          )
        )
      )
      (ok none)
    )
  )
)

;; @desc Compares two optional routes and returns the one with the higher `min-amount-out`.
;; @param route-a The first optional route.
;; @param route-b The second optional route.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) The better route, or none if both are none.
;; @error u1425 If an unexpected error occurs during route comparison.
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
    (else none) ;; Should not happen if logic is sound, but for completeness
  )
)

;; @desc Finds the best two-hop route by iterating through a list of intermediaries.
;; @param intermediaries A list of potential intermediary token principals.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {hops: (list 10 {pool: principal, token-in: principal, token-out: principal}), min-amount-out: uint}) The best two-hop route found, or none.
;; @error u1426 If an error occurs during intermediary route finding.
(define-private (find-best-intermediary (intermediaries (list 10 principal)) (token-in principal) (token-out principal) (amount-in uint))
  (fold intermediaries none
    (lambda (intermediary best-route)
      (let ((candidate-route (unwrap! (find-two-hop-route-with-intermediaries token-in intermediary token-out amount-in) (err u1426)))) ;; ERR_INTERMEDIARY_ROUTE_FAILED
        (compare-routes candidate-route best-route)
      )
    )
  )
)

;; @desc Executes a multi-hop swap by iterating through the provided hops.
;; @param hops A list of hop details, including pool, input token, and output token.
;; @param amount-in The initial amount of input tokens for the first hop.
;; @param recipient The principal to receive the final output tokens.
;; @returns (response uint (err u1427)) The final amount of tokens received by the recipient, or an error code.
;; @error u1427 If reentrancy is detected.
;; @error u1428 If an invalid token is encountered during dimension ID retrieval.
;; @error u1429 If any intermediate swap fails.
(define-private (execute-multi-hop-swap (hops (list 10 {pool: principal, token-in: principal, token-out: principal})) (amount-in uint) (recipient principal))
  (begin
    (asserts! (not (var-get reentrancy-guard)) (err u1427)) ;; ERR_REENTRANCY_GUARD_TRIGGERED
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
              (from-dim (unwrap! (contract-call? dim-registry-contract get-dimension-id (get token-in hop)) (err u1428))) ;; ERR_INVALID_TOKEN
              (to-dim (unwrap! (contract-call? dim-registry-contract get-dimension-id (get token-out hop)) (err u1428))) ;; ERR_INVALID_TOKEN
              (current-pool (get pool hop))
              (next-recipient (if (is-eq hop (last-element hops)) recipient current-pool)) ;; For intermediate hops, recipient is the next pool
            )
              (try! (contract-call? dim-graph-contract set-edge from-dim to-dim current-amount))
              (try! (contract-call? current-pool swap (get token-in hop) (get token-out hop) current-amount u0 next-recipient))
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
;; @error u1408 If no suitable pool is found or an error occurs during pool interaction.
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
;; @error u1409 If an unexpected error occurs during route comparison.
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
;; @error u1410 If encoding the route ID fails.
(define-private (generate-route-id (token-in principal) (token-out principal) (amount-in uint))
  (let (
    (in-idx (default-to u0 (map-get? principal-index token-in)))
    (out-idx (default-to u0 (map-get? principal-index token-out)))
  )
    (unwrap-panic (contract-call? .utils.encoding encode-route-id in-idx out-idx amount-in ZERO32))
  )
)

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

;; @desc Fetches available pools for a given token pair using the DIM registry.
;; @param token-in The principal of the input token.
;; @param token-out The principal of the output token.
;; @returns (response (list 10 principal) uint) A list of pool principals for the given token pair, or an error code.
;; @error u1411 If the DIM registry call fails.
(define-private (get-pools-for-pair (token-in principal) (token-out principal))
  (match (contract-call? .dimensional.dim-registry get-pools-for-pair token-in token-out)
    (ok pools) (ok pools)
    (err e) (err u1411) ;; ERR_DIM_REGISTRY_CALL_FAILED
  )
)

;; @desc Sets the DIM registry contract principal.
;; @param registry The principal of the DIM registry contract.
;; @returns (response bool uint) A boolean indicating success or failure, and an error code if failed.
;; @error u1412 If the caller is not the contract owner.
(define-public (set-dim-registry (registry principal))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender) (err u1412)) ;; ERR_UNAUTHORIZED_OWNER
    (var-set dim-registry registry)
    (ok true)
  )
)

;; @desc Sets the maximum number of hops allowed in a multi-hop route.
;; @param new-max The new maximum number of hops.
;; @returns (response bool uint) A boolean indicating success or failure, and an error code if failed.
;; @error u1413 If the new maximum exceeds the hardcoded limit or the caller is not the contract owner.
(define-public (set-max-hops (new-max uint))
  (begin
    (asserts! (contract-call? .traits.rbac-trait.rbac-trait is-owner tx-sender) (err u1413)) ;; ERR_UNAUTHORIZED_OWNER
    (asserts! (<= new-max MAX_HOPS) (err u1413)) ;; ERR_HOP_LIMIT_EXCEEDED
    (var-set max-hops new-max)
    (ok true)
  )
)

(define-read-only (get-max-hops)
  (ok (var-get max-hops))
)

;; @desc Finds the best pool from a list of pools for a given token pair and input amount.
;; @param pools A list of pool principals.
;; @param token-in The input token principal.
;; @param token-out The output token principal.
;; @param amount-in The amount of input tokens.
;; @returns (optional {pool: principal, amount-out: uint}) The best pool and its output amount, or none.
;; @error u1408 If no suitable pool is found or an error occurs during pool interaction.
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
;; @error u1409 If an unexpected error occurs during route comparison.
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
;; @error u1410 If encoding the route ID fails.
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
;; @returns (response (list 10 principal) uint) A list of pool principals for the given token pair, or an error code.
;; @error u1411 If the DIM registry call fails.
(define-private (get-pools-for-pair (token-in principal) (token-out principal))
  (match (contract-call? (var-get dim-registry) get-pools-for-pair token-in token-out)
    (ok pools) (ok pools)
    (err e) (err u1411) ;; ERR_DIM_REGISTRY_CALL_FAILED
  )
)

;; @desc Sets the DIM registry contract principal.
;; @param registry The principal of the DIM registry contract.
;; @returns (response bool uint) A boolean indicating success or failure, and an error code if failed.
;; @error u1412 If the caller is not the contract owner.
(define-public (set-dim-registry (registry principal))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) (err u1412)) ;; ERR_UNAUTHORIZED_OWNER
    (var-set dim-registry registry)
    (ok true)
  )
)

;; @desc Sets the maximum number of hops allowed in a multi-hop route.
;; @param new-max The new maximum number of hops.
;; @returns (response bool uint) A boolean indicating success or failure, and an error code if failed.
;; @error u1413 If the new maximum exceeds the hardcoded limit or the caller is not the contract owner.
(define-public (set-max-hops (new-max uint))
  (begin
    (asserts! (contract-call? .rbac-trait is-owner tx-sender) (err u1413)) ;; ERR_UNAUTHORIZED_OWNER
    (asserts! (<= new-max MAX_HOPS) (err u1413)) ;; ERR_HOP_LIMIT_EXCEEDED
    (var-set max-hops new-max)
    (ok true)
  )
)

(define-read-only (get-max-hops)
  (ok (var-get max-hops))
)
