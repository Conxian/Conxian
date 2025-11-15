

;; rebalancing-rules.clar

;; Defines rules and thresholds for liquidity rebalancing

;; Traits

;; Constants(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_THRESHOLD (err u101))

;; Data Variables(define-data-var contract-owner principal tx-sender)
(define-data-var utilization-threshold-high uint u90000000) 

;; 90% utilization (90 * 10^6)
(define-data-var utilization-threshold-low uint u70000000)  

;; 70% utilization (70 * 10^6)
(define-data-var yield-rate-deviation-threshold uint u5000000) 

;; 5% deviation (5 * 10^6)
(define-data-var risk-score-threshold uint u70000000) 

;; 70% risk score

;; Public Functions(define-public (set-utilization-thresholds (high-threshold uint) (low-threshold uint))  (begin    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)    (asserts! (> high-threshold low-threshold) ERR_INVALID_THRESHOLD)    (var-set utilization-threshold-high high-threshold)    (var-set utilization-threshold-low low-threshold)    (ok true)  ))
(define-public (set-yield-rate-deviation-threshold (threshold uint))  (begin    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)    (var-set yield-rate-deviation-threshold threshold)    (ok true)  ))
(define-public (set-risk-score-threshold (threshold uint))  (begin    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)    (var-set risk-score-threshold threshold)    (ok true)  ))

;; Read-only Functions(define-read-only (get-utilization-thresholds)  (ok { high: (var-get utilization-threshold-high), low: (var-get utilization-threshold-low) }))
(define-read-only (get-yield-rate-deviation-threshold)  (ok (var-get yield-rate-deviation-threshold)))
(define-read-only (get-risk-score-threshold)  (ok (var-get risk-score-threshold)))
