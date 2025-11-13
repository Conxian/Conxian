;; ===========================================
;; ORACLE & RISK TRAITS MODULE
;; ===========================================
;; Price feeds and risk management traits
;; Critical for financial stability and accuracy

;; ===========================================
;; ORACLE AGGREGATOR TRAIT
;; ===========================================
(define-trait oracle-aggregator-v2-trait
  (
    (get-price ((string-ascii 32)) (response uint uint))
    (get-volatility () (response uint uint))
    (update-price ((string-ascii 32) uint) (response bool uint))
    (get-all-prices () (response (list 20 {asset: (string-ascii 32), price: uint}) uint))
  )
)

;; ===========================================
;; RISK TRAIT
;; ===========================================
(define-trait risk-trait
  (
    (set-max-ltv (uint) (response bool uint))
    (set-liquidation-threshold (uint) (response bool uint))
    (get-max-ltv () (response uint uint))
    (get-liquidation-threshold () (response uint uint))
    (calculate-liquidation-price (uint uint bool) (response uint uint))
  )
)

;; ===========================================
;; LIQUIDATION TRAIT
;; ===========================================
(define-trait liquidation-trait
  (
    (liquidate-position (principal uint uint) (response bool uint))
    (calculate-liquidation-price (uint uint bool) (response uint uint))
    (get-liquidation-reward (uint) (response uint uint))
  )
)
