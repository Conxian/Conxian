;; Math & Utilities Traits

;; ===========================================
;; MATH TRAIT (Basic Operations)
;; ===========================================
(define-trait math-trait (
  (safe-add
    (uint uint)
    (response uint uint)
  )
  (safe-sub
    (uint uint)
    (response uint uint)
  )
  (safe-mul
    (uint uint)
    (response uint uint)
  )
  (safe-div
    (uint uint)
    (response uint uint)
  )
  (safe-mod
    (uint uint)
    (response uint uint)
  )
  (safe-pow
    (uint uint)
    (response uint uint)
  )
))

;; ===========================================
;; FIXED POINT MATH V2 TRAIT (Advanced Q96/Q128 for Concentrated Liquidity)
;; ===========================================
(define-trait math-fixed-point-v2-trait (
  (fixed-point-pow-rational-i
    (uint uint int uint)
    (response uint uint)
  )
  (fixed-point-log-rational-i
    (uint uint (response uint uint) uint)
    (response int uint)
  )
  (fixed-point-sqrt
    (uint)
    (response uint uint)
  )
  (fixed-point-exp
    (uint)
    (response uint uint)
  )
  (fixed-point-ln
    (uint)
    (response uint uint)
  )
))

;; ===========================================
;; FIXED POINT MATH TRAIT (Q64.64 Precision)
;; ===========================================
(define-trait fixed-point-math-trait (
  (to-fixed
    (uint)
    (response uint uint)
  )
  (from-fixed
    (uint)
    (response uint uint)
  )
  (mul-fixed
    (uint uint)
    (response uint uint)
  )
  (div-fixed
    (uint uint)
    (response uint uint)
  )
  (add-fixed
    (uint uint)
    (response uint uint)
  )
  (sub-fixed
    (uint uint)
    (response uint uint)
  )
  (sqrt-fixed
    (uint)
    (response uint uint)
  )
))

;; ===========================================
;; FINANCE METRICS TRAIT
;; ===========================================
(define-trait finance-metrics-trait (
  (calculate-apy
    (uint uint uint)
    (response uint uint)
  )
  (calculate-apr
    (uint uint)
    (response uint uint)
  )
  (calculate-sharpe-ratio
    (uint uint uint)
    (response int uint)
  )
  (calculate-volatility
    (uint uint)
    (response uint uint)
  )
  (calculate-compound-interest
    (uint uint uint)
    (response uint uint)
  )
))

;; ===========================================
;; UTILS TRAIT  
;; ===========================================
(define-trait utils-trait (
  (is-contract-owner
    (principal)
    (response bool uint)
  )
  (get-block-height
    ()
    (response uint uint)
  )
  (uint-to-string
    (uint)
    (response (string-ascii 20) uint)
  )
  (principal-to-string
    (principal)
    (response (string-ascii 41) uint)
  )
  (validate-address
    (principal)
    (response bool uint)
  )
  (min
    (uint uint)
    (response uint uint)
  )
  (max
    (uint uint)
    (response uint uint)
  )
))

;; ===========================================
;; ENCODING TRAIT (Deterministic Hashing)
;; ===========================================
(define-trait encoding-trait (
  (encode-tuple
    ({ dummy: bool })
    (response (buff 1024) uint)
  )
  (hash-data
    ((buff 1024))
    (response (buff 32) uint)
  )
  (encode-uint
    (uint)
    (response (buff 16) uint)
  )
  (encode-principal
    (principal)
    (response (buff 64) uint)
  )
))
