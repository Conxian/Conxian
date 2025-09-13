;; standard-constants.clar
;; Implementation of standard constants for the Conxian protocol

(use-trait std-constants 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.standard-constants-trait.standard-constants-trait)

(define-constant PRECISION_18 u1000000000000000000)  ;; 18 decimals
(define-constant PRECISION_8  u100000000)            ;; 8 decimals
(define-constant PRECISION_6  u1000000)              ;; 6 decimals
(define-constant BASIS_POINTS u10000)                ;; 100.00%

;; Time constants (assuming ~1 block per minute)
(define-constant BLOCKS_PER_MINUTE u1)
(define-constant BLOCKS_PER_HOUR (* BLOCKS_PER_MINUTE u60))
(define-constant BLOCKS_PER_DAY (* BLOCKS_PER_HOUR u24))
(define-constant BLOCKS_PER_WEEK (* BLOCKS_PER_DAY u7))
(define-constant BLOCKS_PER_YEAR (* BLOCKS_PER_DAY u365))

;; Common percentage values
(define-constant ZERO u0)
(define-constant FIFTY_PERCENT u5000)                ;; 50.00%
(define-constant ONE_HUNDRED_PERCENT u10000)         ;; 100.00%

(impl-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSR.standard-constants-trait.standard-constants-trait)

(define-public (get-precision)
  (ok PRECISION_18))

(define-public (get-basis-points)
  (ok BASIS_POINTS))

(define-public (get-blocks-per-minute)
  (ok BLOCKS_PER_MINUTE))

(define-public (get-blocks-per-hour)
  (ok BLOCKS_PER_HOUR))

(define-public (get-blocks-per-day)
  (ok BLOCKS_PER_DAY))

(define-public (get-blocks-per-week)
  (ok BLOCKS_PER_WEEK))

(define-public (get-blocks-per-year)
  (ok BLOCKS_PER_YEAR))

(define-public (get-max-bps)
  (ok BASIS_POINTS))

(define-public (get-one-hundred-percent)
  (ok ONE_HUNDRED_PERCENT))

(define-public (get-fifty-percent)
  (ok FIFTY_PERCENT))

(define-public (get-zero)
  (ok ZERO))

(define-public (get-precision-18)
  (ok PRECISION_18))

(define-public (get-precision-8)
  (ok PRECISION_8))

(define-public (get-precision-6)
  (ok PRECISION_6))





