
;; Oracle Aggregator - Minimal trait-compliant implementation

(use-trait oracle-aggregator-trait .all-traits.oracle-aggregator-trait)
(impl-trait oracle-aggregator-trait)
(define-constant ERR_UNAUTHORIZED (err u401))

(define-data-var admin principal tx-sender)
(define-map feed-counts { token: principal } { count: uint })

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (add-oracle-feed (token principal) (feed principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((entry (map-get? feed-counts { token: token })))
      (match entry
        e (map-set feed-counts { token: token } { count: (+ (get count e) u1) })
        (map-set feed-counts { token: token } { count: u1 })
      )
    )
    (ok true)
  )
)

(define-public (remove-oracle-feed (token principal) (feed principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((entry (map-get? feed-counts { token: token })))
      (match entry
        e (map-set feed-counts { token: token } { count: (if (> (get count e) u0) (- (get count e) u1) u0) })
        (ok true)
      )
    )
    (ok true)
  )
)

(define-read-only (get-feed-count (token principal))
  (match (map-get? feed-counts { token: token })
    e (ok (get count e))
    (ok u0)
  )
)

(define-read-only (get-aggregated-price (token principal))
  

;; Minimal stub: returns zero; replace with TWAP aggregation in Phase 2
  (ok u0)
)