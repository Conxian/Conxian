;; dim-metrics.clar
;; Dimensional Metrics Aggregation
;; Responsibilities:
;; - Store per-dimension KPIs (TVL, Utilization, Default Rate)
;;
;; Metric values will be pushed by keepers periodically.

(define-constant ERR_UNAUTHORIZED u101)

(define-data-var contract-owner principal tx-sender)
(define-data-var writer-principal principal tx-sender)

;; The metric-id can be used to represent different types of metrics, for example:
;; u0: TVL (Total Value Locked)
;; u1: Utilization
;; u2: Default Rate
(define-map metric {dim-id: uint, metric-id: uint} {value: uint, last-updated: uint})

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-writer-principal (new-writer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set writer-principal new-writer)
    (ok true)))

(define-read-only (get-metric (dim-id uint) (metric-id uint))
  (map-get? metric {dim-id: dim-id, metric-id: metric-id}))

;; @desc Records a new metric value for a dimension.
;; @param dim-id: The dimension ID.
;; @param met-id: The metric ID (e.g., u0 for TVL).
;; @param val: The value of the metric.
;; @returns (response bool uint)
(define-public (record-metric (dim-id uint) (met-id uint) (val uint))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) (err ERR_UNAUTHORIZED))
    (map-set metric
      {dim-id: dim-id, metric-id: met-id}
      {value: val, last-updated: block-height})
    (ok true)))



