;; mock-metrics.clar
;; An enhanced mock contract for testing the yield optimizer.
;; Allows setting metric values for specific strategies.

(define-map metric-store { strategy: principal, metric-id: uint } { value: uint, last-updated: uint })

(define-public (set-metric (strategy principal) (metric-id uint) (value uint))
  (begin
    (map-set metric-store
      { strategy: strategy, metric-id: metric-id }
      { value: value, last-updated: block-height }
    )
    (ok true)
  )
)

;; The yield-optimizer will call this function.
;; The `asset` parameter is part of a potential generic metrics-trait,
;; but in this mock, we only care about the strategy.
(define-read-only (get-metric (strategy principal) (metric-id uint))
  (map-get? metric-store { strategy: strategy, metric-id: metric-id })
)
