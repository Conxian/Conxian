;; ===========================================
;; DEX TRAITS MODULE
;; ===========================================
;; Decentralized exchange specific traits
;; Optimized for high-frequency trading operations

;; ===========================================
;; SIP-010 FT TRAIT
;; ===========================================
(define-trait sip-010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (transfer-from (uint principal principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; ===========================================
;; POOL TRAIT
;; ===========================================
(define-trait pool-trait
  (
    (swap (principal principal uint uint) (response uint uint))
    (add-liquidity (uint uint uint uint) (response uint uint))
    (remove-liquidity (uint) (response { amount0: uint, amount1: uint } uint))
    (get-reserves () (response { reserve0: uint, reserve1: uint } uint))
    (get-pool-info () (response {
      token0: principal,
      token1: principal,
      fee: uint,
      total-liquidity: uint
    } uint))
  )
)

;; ===========================================
;; FACTORY TRAIT
;; ===========================================
(define-trait factory-trait
  (
    (create-pool (principal principal uint) (response principal uint))
    (get-pool (principal principal) (response (optional principal) uint))
    (get-all-pools () (response (list 100 principal) uint))
  )
)

;; ===========================================
;; FINANCE METRICS TRAIT
;; ===========================================
(define-trait finance-metrics-trait
  (
    (get-tvl () (response uint uint))
    (get-volume ((string-ascii 32)) (response uint uint))
    (get-fees-collected () (response uint uint))
    (get-utilization-rate () (response uint uint))
  )
)
