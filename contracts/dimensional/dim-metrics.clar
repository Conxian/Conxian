;; dim-metrics.clar
;; Dimensional Metrics Aggregation
;; Responsibilities:
;; - Store per-dimension KPIs (TVL, Utilization, Default Rate)
;; - Metric values will be pushed by keepers periodically.

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u101))
(define-constant ERR_INVALID_METRIC (err u102))
(define-constant ERR_DIMENSION_DISABLED (err u103))

;; Metric type constants
(define-constant METRIC_TVL u0)
(define-constant METRIC_UTILIZATION u1)
(define-constant METRIC_DEFAULT_RATE u2)

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var writer-principal principal tx-sender)

;; ===== Data Maps =====
;; Stores metric values for each dimension
(define-map metrics 
  {dim-id: uint, metric-id: uint} 
  {value: uint, last-updated: uint}
)

;; Track enabled dimensions
(define-map dimension-enabled 
  {dim-id: uint} 
  {enabled: bool}
)

;; ===== Owner Functions =====
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-writer-principal (new-writer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set writer-principal new-writer)
    (ok true)
  )
)

(define-public (enable-dimension (dim-id uint) (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set dimension-enabled
      {dim-id: dim-id}
      {enabled: enabled}
    )
    (ok true)
  )
)

;; ===== Writer Functions =====
;; @desc Records a new metric value for a dimension.
;; @param dim-id: The dimension ID.
;; @param metric-id: The metric ID (e.g., u0 for TVL, u1 for Utilization, u2 for Default Rate).
;; @param value: The value of the metric.
;; @returns (response bool uint)
(define-public (record-metric (dim-id uint) (metric-id uint) (value uint))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) ERR_UNAUTHORIZED)
    (asserts! (<= metric-id u2) ERR_INVALID_METRIC)
    (asserts! (is-dimension-enabled dim-id) ERR_DIMENSION_DISABLED)
    
    (map-set metrics
      {dim-id: dim-id, metric-id: metric-id}
      {value: value, last-updated: block-height}
    )
    (ok true)
  )
)

;; Batch update multiple metrics for a dimension
(define-public (record-metrics (dim-id uint) (updates (list 10 {metric-id: uint, value: uint})))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) ERR_UNAUTHORIZED)
    (asserts! (is-dimension-enabled dim-id) ERR_DIMENSION_DISABLED)
    
    (fold record-metric-iter updates (ok dim-id))
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-metric (dim-id uint) (metric-id uint))
  (map-get? metrics {dim-id: dim-id, metric-id: metric-id})
)

(define-read-only (is-dimension-enabled (dim-id uint))
  (default-to true (get enabled (map-get? dimension-enabled {dim-id: dim-id})))
)

;; ===== Private Functions =====
(define-private (record-metric-iter 
  (update {metric-id: uint, value: uint}) 
  (prev-result (response uint uint))
)
  (let (
    (dim-id (try! prev-result))
  )
    (asserts! (<= (get metric-id update) u2) ERR_INVALID_METRIC)
    (map-set metrics
      {dim-id: dim-id, metric-id: (get metric-id update)}
      {value: (get value update), last-updated: block-height}
    )
    (ok dim-id)
  )
)