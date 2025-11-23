;; Risk Management Traits

;; ===========================================
;; RISK MANAGER TRAIT
;; ===========================================
(define-trait risk-manager-trait
  (
    (assess-position-risk (uint) (response {
      health-factor: uint,
      liquidation-price: uint,
      risk-level: (string-ascii 20)
    } uint))
    
    (set-risk-parameters (uint uint uint) (response bool uint))
    (set-liquidation-rewards (uint uint) (response bool uint))
    (set-insurance-fund (principal) (response bool uint))
  )
)

;; ===========================================
;; LIQUIDATION ENGINE TRAIT
;; ===========================================
(define-trait liquidation-trait
  (
    (liquidate-position (principal uint) (response bool uint))
    (check-liquidation-eligibility (uint) (response bool uint))
    (get-liquidation-bonus () (response uint uint))
  )
)

;; ===========================================
;; RISK ORACLE TRAIT
;; ===========================================
(define-trait risk-oracle-trait
  (
    (get-volatility (principal) (response uint uint))
    (get-var (principal uint) (response uint uint))
    (update-risk-metrics (principal uint uint) (response bool uint))
  )
)

;; ===========================================
;; FUNDING CALCULATOR TRAIT (Perps)
;; ===========================================
(define-trait funding-trait
  (
    (calculate-funding-rate (principal) (response int uint))
    (apply-funding-payment (principal uint) (response int uint))
    (get-cumulative-funding (principal) (response int uint))
  )
)
