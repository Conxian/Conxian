;; ============================================================
;; MATH UTILITIES (v3.9.0+)
;; ============================================================
;; Shared math functions for the Conxian protocol

(define-constant PRECISION u1000000)
(define-constant PERCENTAGE_PRECISION u10000)

(define-read-only (safe-mul (a uint) (b uint))
  (if (<= a (div u340282366920938463463374607431768211455 b))
      (ok (* a b))
      (err u1001)  ;; MATH_OVERFLOW
  )
)

(define-read-only (safe-div (a uint) (b uint))
  (if (is-eq b u0)
      (err u1002)  ;; DIVISION_BY_ZERO
      (ok (/ a b))
  )
)

(define-read-only (calculate-percentage (value uint) (percentage uint))
  (let (
    { multiplier: (try! (safe-mul value percentage)) }
    (try! (safe-div multiplier PERCENTAGE_PRECISION))
  ))
)

(define-read-only (calculate-leverage (collateral uint) (position-size uint))
  (if (is-eq collateral u0)
      (ok u0)
      (try! (safe-div (* position-size PERCENTAGE_PRECISION) collateral))
  )
)

(define-read-only (calculate-liquidation-price (entry-price uint) (leverage uint) (is-long bool) (maintenance-margin uint))
  (let (
    { 
      margin-ratio: (try! (safe-div maintenance-margin PERCENTAGE_PRECISION))
      leverage-ratio: (try! (safe-div u1000000 leverage))  ;; 100% / leverage
      price-factor: (if is-long 
                     (try! (safe-add u1000000 (try! (safe-mul leverage-ratio margin-ratio))))
                     (try! (safe-sub u1000000 (try! (safe-mul leverage-ratio margin-ratio))))
                   )
    }
    (try! (safe-mul entry-price price-factor))
  )
)
