;; Math & Utilities Traits

;; ===========================================
;; MATH TRAIT (Basic Operations)
;; ===========================================
(define-trait math-trait
  (
    (safe-add (uint uint) (response uint uint))
    (safe-sub (uint uint) (response uint uint))
    (safe-mul (uint uint) (response uint uint))
    (safe-div (uint uint) (response uint uint))
  )
)

;; ===========================================
;; FIXED POINT MATH TRAIT (Q64.64 Precision)
;; ===========================================
(define-trait fixed-point-math-trait
  (
    (to-fixed (uint) (response uint uint))
    (from-fixed (uint) (response uint uint))
    (mul-fixed (uint uint) (response uint uint))
    (div-fixed (uint uint) (response uint uint))
  )
)

;; ===========================================
;; FINANCE METRICS TRAIT
;; ===========================================
(define-trait finance-metrics-trait
  (
    (calculate-apy (uint uint uint) (response uint uint))
    (calculate-apr (uint uint) (response uint uint))
    (calculate-sharpe-ratio (uint uint uint) (response int uint))
  )
)

;; ===========================================
;; UTILS TRAIT  
;; ===========================================
(define-trait utils-trait
  (
    (is-contract-owner (principal) (response bool uint))
    (get-block-height () (response uint uint))
    (uint-to-string (uint) (response (string-ascii 20) uint))
    (principal-to-string (principal) (response (string-ascii 41) uint))
  )
)

;; ===========================================
;; ENCODING TRAIT (Deterministic Hashing)
;; ===========================================
(define-trait encoding-trait
  (
    (encode-tuple ((tuple (dummy: bool))) (response (buff 1024) uint))
    (hash-data ((buff 1024)) (response (buff 32) uint))
  )
)
