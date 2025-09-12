;; standard-constants-trait.clar
;; Defines standard constants and interfaces for the Conxian protocol

(define-trait standard-constants-trait
  (
    ;; Precision and mathematical constants (18 decimals)
    (get-precision) (response uint uint)
    (get-basis-points) (response uint uint)
    
    ;; Common time constants (in blocks, assuming ~1 block per minute)
    (get-blocks-per-minute) (response uint uint)
    (get-blocks-per-hour) (response uint uint)
    (get-blocks-per-day) (response uint uint)
    (get-blocks-per-week) (response uint uint)
    (get-blocks-per-year) (response uint uint)
    
    ;; Common percentage values (in basis points)
    (get-max-bps) (response uint uint)
    (get-one-hundred-percent) (response uint uint)
    (get-fifty-percent) (response uint uint)
    (get-zero) (response uint uint)
    
    ;; Common precision values
    (get-precision-18) (response uint uint)
    (get-precision-8) (response uint uint)
    (get-precision-6) (response uint uint)
  )
)

;; Standard implementation of the constants trait
(define-constant PRECISION_18 u1000000000000000000)  ;; 18 decimals
(define-constant PRECISION_8  u100000000)            ;; 8 decimals
(define-constant PRECISION_6  u1000000)              ;; 6 decimals
(define-constant BASIS_POINTS u10000)                ;; 100.00%

;; Time constants (assuming ~1 block per minute)
(define-constant BLOCKS_PER_MINUTE u1
(define-constant BLOCKS_PER_HOUR (* BLOCKS_PER_MINUTE u60))
(define-constant BLOCKS_PER_DAY (* BLOCKS_PER_HOUR u24))
(define-constant BLOCKS_PER_WEEK (* BLOCKS_PER_DAY u7))
(define-constant BLOCKS_PER_YEAR (* BLOCKS_PER_DAY u365))

;; Common percentage values
(define-constant ZERO u0)
(define-constant FIFTY_PERCENT u5000)                ;; 50.00%
(define-constant ONE_HUNDRED_PERCENT u10000)         ;; 100.00%
