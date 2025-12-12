;; ============================================================
;; MATH UTILITIES (v3.9.0+)
;; ============================================================
;; @desc Shared math functions for the Conxian protocol.

;; @constants
;; @var PRECISION: The precision used for fixed-point arithmetic.
(define-constant PRECISION u1000000)
;; @var PERCENTAGE_PRECISION: The precision used for percentage calculations.
(define-constant PERCENTAGE_PRECISION u10000)

;; @desc Safely multiplies two unsigned integers.
;; @param a: The first number.
;; @param b: The second number.
;; @returns (response uint uint): The product of the two numbers, or an error code if an overflow occurs.
(define-read-only (safe-mul (a uint) (b uint))
  (if (is-eq b u0)
      (ok u0)
      (let ((max-factor (/ u340282366920938463463374607431768211455 b)))
        (if (<= a max-factor)
            (ok (* a b))
            (err u2000)  ;; ERR_OVERFLOW
        )
      )
  )
)

;; @desc Safely divides two unsigned integers.
;; @param a: The numerator.
;; @param b: The denominator.
;; @returns (response uint uint): The quotient of the two numbers, or an error code if the denominator is zero.
(define-read-only (safe-div (a uint) (b uint))
  (if (is-eq b u0)
      (err u2002)  ;; ERR_DIVISION_BY_ZERO
      (ok (/ a b))
  )
)

;; @desc Calculates a percentage of a value.
;; @param value: The value to calculate the percentage of.
;; @param percentage: The percentage to calculate.
;; @returns (response uint uint): The calculated percentage, or an error code.
(define-read-only (calculate-percentage (value uint) (percentage uint))
  (let ((multiplier (try! (safe-mul value percentage))))
    (try! (safe-div multiplier PERCENTAGE_PRECISION))
  )
)

;; @desc Calculates the leverage of a position.
;; @param collateral: The collateral of the position.
;; @param position-size: The size of the position.
;; @returns (response uint uint): The leverage of the position, or an error code.
(define-read-only (calculate-leverage (collateral uint) (position-size uint))
  (if (is-eq collateral u0)
      (ok u0)
      (try! (safe-div (* position-size PERCENTAGE_PRECISION) collateral))
  )
)

;; @desc Calculates the liquidation price of a position.
;; @param entry-price: The entry price of the position.
;; @param leverage: The leverage of the position.
;; @param is-long: A boolean indicating if the position is long or short.
;; @param maintenance-margin: The maintenance margin of the position.
;; @returns (response uint uint): The liquidation price of the position, or an error code.
(define-read-only (calculate-liquidation-price (entry-price uint) (leverage uint) (is-long bool) (maintenance-margin uint))
  (let (
        (margin-ratio (try! (safe-div maintenance-margin PERCENTAGE_PRECISION)))
        (leverage-ratio (try! (safe-div PERCENTAGE_PRECISION leverage)))
       )
    (let (
          (product (try! (safe-mul leverage-ratio margin-ratio)))
          (adjustment (try! (safe-div product PERCENTAGE_PRECISION)))
          (base PERCENTAGE_PRECISION)
          (factor (if is-long
                      (+ base adjustment)
                      (- base adjustment)))
          (scaled-price (try! (safe-mul entry-price factor)))
         )
      (try! (safe-div scaled-price PERCENTAGE_PRECISION))
    )
  )
)
