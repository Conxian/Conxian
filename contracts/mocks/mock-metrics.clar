;; mock-metrics.clar
;; An enhanced mock contract for testing the yield optimizer.
;; Allows setting metric values for specific strategies.

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_METRIC (err u1001))

;; Metric type constants
(define-constant METRIC_APY u0)
(define-constant METRIC_TVL u1)
(define-constant METRIC_RISK_SCORE u2)

;; ===== Data Maps =====
(define-map metric-store 
  { strategy: principal, metric-id: uint } 
  { value: uint, last-updated: uint }
)

;; ===== Public Functions =====

;; @desc Sets a specific metric for a given strategy.
;; @param strategy (principal) The principal of the strategy.
;; @param metric-id (uint) The ID of the metric to set (e.g., u0 for APY).
;; @param value (uint) The value of the metric.
;; @return (response bool uint) Returns (ok true) if successful.
(define-public (set-metric (strategy principal) (metric-id uint) (value uint))
  (begin
    (map-set metric-store
      { strategy: strategy, metric-id: metric-id }
      { value: value, last-updated: block-height }
    )
    
    (print {
      event: "metric-updated",
      strategy: strategy,
      metric-id: metric-id,
      value: value,
      block: block-height
    })
    
    (ok true)
  )
)

;; ===== Read-Only Functions =====

;; @desc Retrieves a specific metric for a given strategy.
;; @param strategy (principal) The principal of the strategy.
;; @param metric-id (uint) The ID of the metric to retrieve (e.g., u0 for APY).
;; @return (response { value: uint, last-updated: uint } uint) Returns the metric data if found.
(define-read-only (get-metric (strategy principal) (metric-id uint))
  (ok (map-get? metric-store { strategy: strategy, metric-id: metric-id }))
)

;; @desc Gets the current value of a metric for a strategy.
;; @param strategy (principal) The principal of the strategy.
;; @param metric-id (uint) The ID of the metric.
;; @return (response uint uint) Returns the metric value or u0 if not found.
(define-read-only (get-metric-value (strategy principal) (metric-id uint))
  (ok (default-to u0 
    (get value (map-get? metric-store { strategy: strategy, metric-id: metric-id }))
  ))
)