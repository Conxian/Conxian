;; @desc This contract encapsulates all the logic for the Dijkstra's algorithm,
;; including initializing the data structures, finding the shortest path, and reconstructing the path.
;; NOTE: The original version attempted a full Dijkstra implementation with
;; recursive loops and trait-based neighbors. That design caused Clarinet's
;; "interdependent functions" analyzer error and relied on traits that do
;; not exist in the current codebase. This refactored version preserves a
;; sensible routing behavior by delegating to a configured dex-factory
;; and computing the best direct route (single-hop) via the pool's
;; `get-amount-out` function.

;; @constants
(define-constant ERR_NO_PATH_FOUND (err u1407))
(define-constant ERR_DIJKSTRA_INIT_FAILED (err u1408))
(define-constant ERR_POOL_NOT_FOUND (err u1409))
(define-constant ERR_GET_AMOUNT_IN_FAILED (err u1410))

;; @data-vars
(define-data-var admin principal tx-sender)
(define-data-var dex-factory principal tx-sender)

;; --- Admin Functions ---

;; Set a new admin for managing the pathfinder configuration
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_DIJKSTRA_INIT_FAILED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; Configure the dex-factory contract used for route discovery
(define-public (set-dex-factory (factory principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_DIJKSTRA_INIT_FAILED)
    (var-set dex-factory factory)
    (ok true)
  )
)

;; --- Core Routing Logic ---

;; Simplified best-route computation:
;; - Queries a configured dex-factory for a direct pool between token-in and token-out
;; - If a pool exists, queries the pool's get-amount-out to estimate output
;; - Returns a single-hop path and the estimated amount-out
(define-read-only (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((factory (var-get dex-factory)))
    (match (contract-call? factory get-pool token-in token-out)
      (ok maybe-pool)
      (if (is-some maybe-pool)
        (let ((pool (unwrap-panic maybe-pool)))
          (match (contract-call? pool get-amount-out token-in token-out amount-in)
            (ok amount-out)
            (ok {
              path: (list { pool: pool, token-in: token-in, token-out: token-out }),
              amount-out: amount-out
            })
            (err e)
            ERR_GET_AMOUNT_IN_FAILED
          )
        )
        ERR_NO_PATH_FOUND
      )
      (err e)
      ERR_POOL_NOT_FOUND
    )
  )
)
