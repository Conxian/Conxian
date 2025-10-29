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
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait pool-trait .all-traits.pool-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================

(define-constant MAX_HOPS u5)
(define-constant MAX_SLIPPAGE u1000) ;; 10% max slippage
(define-constant ROUTE_TIMEOUT u100) ;; blocks

;; ===========================================
;; ERROR CODES
;; ===========================================

(define-constant ERR_INVALID_ROUTE (err u7001))
(define-constant ERR_ROUTE_NOT_FOUND (err u7002))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u7003))
(define-constant ERR_HOP_LIMIT_EXCEEDED (err u7004))
(define-constant ERR_INVALID_TOKEN (err u7005))
(define-constant ERR_ROUTE_EXPIRED (err u7006))

;; ===========================================
;; DATA VARIABLES
;; ===========================================

(define-data-var route-counter uint u0)
(define-data-var max-hops uint MAX_HOPS)

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

(define-read-only (compute-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((route-id (generate-route-id token-in token-out amount-in)))
    ;; For now, implement basic 2-hop routing through common intermediaries
    ;; In production, this would use Dijkstra's algorithm
    (let ((best-route (find-best-route token-in token-out amount-in)))
      (if (is-some best-route)
        (let ((route (unwrap-panic best-route)))
          (map-set routes
            { route-id: route-id }
            {
              token-in: token-in,
              token-out: token-out,
              amount-in: amount-in,
              min-amount-out: (get min-amount-out route),
              hops: (get hops route),
              created-at: block-height,
              expires-at: (+ block-height ROUTE_TIMEOUT)
            }
          )
          (ok (tuple (route-id route-id) (hops (len (get hops route)))))
        )
        (err ERR_ROUTE_NOT_FOUND)
      )
    )
  )
)

;; ===========================================
;; ROUTE EXECUTION
;; ===========================================

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
;; INTERNAL FUNCTIONS
;; ===========================================

(define-private (find-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((direct-route (try-direct-route token-in token-out amount-in))
        (two-hop-route (try-two-hop-route token-in token-out amount-in)))
    (select-better-route direct-route two-hop-route)
  )
)

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

(define-private (try-two-hop-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((intermediaries (list
          (as-contract tx-sender)
          'SP2H8PY27SEZ03MWRKS5XABZYQN17ETGQS3527SA5
          .contracts.mock-usda-token
        )))
    (find-best-intermediary intermediaries token-in token-out amount-in)
  )
)

(define-private (find-best-intermediary (intermediaries (list 10 principal)) (token-in principal) (token-out principal) (amount-in uint))
  (fold intermediaries none
    (lambda (intermediary best-route)
      (let ((first-route (try-direct-route token-in intermediary amount-in)))
        (if (is-some first-route)
          (let ((first (unwrap-panic first-route))
                (first-output (get min-amount-out (unwrap-panic first-route)))
                (second-route (try-direct-route intermediary token-out first-output)))
            (if (is-some second-route)
              (let ((second (unwrap-panic second-route))
                    (combined-hops (append (get hops first) (get hops second))))
                (let ((candidate (some {
                                  hops: combined-hops,
                                  min-amount-out: (get min-amount-out second)
                                })))
                  (if (is-some best-route)
                    (if (> (get min-amount-out (unwrap-panic candidate)) (get min-amount-out (unwrap-panic best-route)))
                      candidate
                      best-route)
                    candidate)
                )
              )
              best-route)
          )
          best-route)
      )
    )
)

(define-private (execute-multi-hop-swap (hops (list 10 {pool: principal, token-in: principal, token-out: principal})) (amount-in uint) (recipient principal))
  (fold hops (ok amount-in)
    (lambda (hop result)
      (match result
        (ok current-amount)
        (contract-call? (get pool hop) swap (get token-in hop) (get token-out hop) current-amount u0 recipient)
        err-result
        err-result
      )
    )
  )
)

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
          (err _)
          current-best
        )
      )
    )
  )
)

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

(define-private (generate-route-id (token-in principal) (token-out principal) (amount-in uint))
  (sha256 (concat
    (concat (principal-to-buff-33 token-in) (principal-to-buff-33 token-out))
    (to-consensus-buff? amount-in)
  ))
)

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

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