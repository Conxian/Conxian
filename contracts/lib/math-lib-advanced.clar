;; math-lib-advanced.clar
;; Advanced mathematical library with essential DeFi functions
;; Rewritten for correctness and precision.

(define-constant ERR_INVALID_INPUT (err u1001))
(define-constant ERR_OVERFLOW (err u1002))
(define-constant ERR_UNDERFLOW (err u1003))
(define-constant ERR_PRECISION_LOSS (err u1004))

;; Fixed-point precision constant
(define-constant PRECISION u1000000000000000000) ;; 18 decimals (1e18)

;; Mathematical constants in 18-decimal fixed point
(define-constant E_FIXED u2718281828459045235) ;; e ~ 2.718281828459045235

;; Using contract-call to the safer, corrected fixed-point-math library
(define-read-only (mul-down-safe (a uint) (b uint))
  (contract-call? .fixed-point-math mul-down a b))

(define-read-only (div-down-safe (a uint) (b uint))
  (unwrap-panic (contract-call? .fixed-point-math div-down a b)))

;; === NATURAL LOGARITHM - LEVEL 1 ===
;; Calculates ln(x) using a 10-term Taylor series expansion for ln(1+y)
;; where y = x - 1. This is accurate for x close to 1.
;; For broader ranges, a more advanced algorithm with range reduction would be needed.
(define-read-only (ln-fixed (x uint))
  (if (is-eq x u0) (err ERR_INVALID_INPUT) ;; ln(0) is undefined
    (begin
      (asserts! (< x (* u2 PRECISION)) (err ERR_INVALID_INPUT)) ;; Taylor series is only accurate for 0 < x < 2
      (if (is-eq x PRECISION) (ok u0) ;; ln(1) = 0
        (let
          (
            ;; Let y = x - 1. We need to handle both x > 1 and x < 1.
            (y (if (> x PRECISION) (- x PRECISION) (- PRECISION x)))
          (y2 (mul-down-safe y y))
          (y3 (mul-down-safe y2 y))
          (y4 (mul-down-safe y3 y))
          (y5 (mul-down-safe y4 y))
          (y6 (mul-down-safe y5 y))
          (y7 (mul-down-safe y6 y))
          (y8 (mul-down-safe y7 y))
          (y9 (mul-down-safe y8 y))
          (y10 (mul-down-safe y9 y))
        )
        (let
          (
            ;; Taylor series for ln(1+y) = y - y^2/2 + y^3/3 - y^4/4 + ...
            (series (+
              (- (+ y (/ y3 u3) (/ y5 u5) (/ y7 u7) (/ y9 u9))
                 (+ (/ y2 u2) (/ y4 u4) (/ y6 u6) (/ y8 u8) (/ y10 u10)))
            ))
          )
          ;; If x was less than 1, y was 1-x, so ln(x) = ln(1-y) = -series
          (if (> x PRECISION) (ok series) (ok (- u0 series)))
        )
      )
    )
  )
)

;; === EXPONENTIAL - LEVEL 1 ===
;; Calculates e^x using a 10-term Taylor series expansion.
;; Accurate for small values of x.
(define-read-only (exp-fixed (x uint))
  (if (is-eq x u0) (ok PRECISION) ;; exp(0) = 1
    (if (> x (* u5 PRECISION)) (err ERR_OVERFLOW) ;; Prevent overflow for large x
      (let
        (
          (x2 (mul-down-safe x x))
          (x3 (mul-down-safe x2 x))
          (x4 (mul-down-safe x3 x))
          (x5 (mul-down-safe x4 x))
          (x6 (mul-down-safe x5 x))
          (x7 (mul-down-safe x6 x))
          (x8 (mul-down-safe x7 x))
          (x9 (mul-down-safe x8 x))
        )
        (ok
          (+ PRECISION
             (+ x
                (+ (/ x2 u2)
                   (+ (/ x3 u6)
                      (+ (/ x4 u24)
                         (+ (/ x5 u120)
                            (+ (/ x6 u720)
                               (+ (/ x7 u5040)
                                  (+ (/ x8 u40320)
                                     (/ x9 u362880))))))))))
        )
      )
    )
  )
)

;; === POWER FUNCTION - LEVEL 2 ===
;; Calculates base^exponent using the identity a^b = exp(b * ln(a))
(define-read-only (pow-fixed (base uint) (exponent uint))
  (if (is-eq base u0)
    (if (is-eq exponent u0) (err ERR_INVALID_INPUT) (ok u0))
    (if (is-eq exponent u0) (ok PRECISION) ;; x^0 = 1
      (if (is-eq exponent PRECISION) (ok base) ;; x^1 = x
        ;; Use integer exponentiation for integer exponents for precision and efficiency
        (if (is-eq (mod exponent PRECISION) u0)
          (let ((exp-int (/ exponent PRECISION)))
            (pow-int-fixed base exp-int)
          )
          ;; Use ln/exp for fractional exponents
          (let ((ln-base (unwrap! (ln-fixed base) (err ERR_PRECISION_LOSS))))
            (exp-fixed (mul-down-safe ln-base exponent))
          )
        )
      )
    )
  )
)

;; Helper for integer exponentiation using binary exponentiation (exponentiation by squaring)
(define-private (pow-int-fixed (base uint) (exp uint))
  (let ((result (pow-int-iter base exp PRECISION)))
    (ok result)
  )
)

(define-private (pow-int-iter (base uint) (exp uint) (result uint))
  (if (is-eq exp u0) result
    (if (is-eq (mod exp u2) u1)
      (pow-int-iter (mul-down-safe base base) (/ exp u2) (mul-down-safe result base))
      (pow-int-iter (mul-down-safe base base) (/ exp u2) result)
    )
  )
)

;; === INTEGER SQUARE ROOT - LEVEL 1 ===
;; Calculates integer square root using Newton's method.
(define-read-only (sqrt-integer (n uint))
  (if (is-eq n u0) (ok u0)
    (let ((x0 (if (> n u1) (/ n u2) u1)))
      (if (is-eq x0 u0) (ok u1) ;; Avoid division by zero if n is 1
        (let ((x1 (/ (+ x0 (/ n x0)) u2)))
          (let ((x2 (/ (+ x1 (/ n x1)) u2)))
            (let ((x3 (/ (+ x2 (/ n x2)) u2)))
              (let ((x4 (/ (+ x3 (/ n x3)) u2)))
                (let ((x5 (/ (+ x4 (/ n x4)) u2)))
                  (let ((x6 (/ (+ x5 (/ n x5)) u2)))
                    (ok x6)
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; === BENCHMARKING FUNCTIONS ===
(define-read-only (benchmark-exp)
  (match (exp-fixed PRECISION) ;; exp(1) should be e
    result (ok (if (> result E_FIXED) (- result E_FIXED) (- E_FIXED result)))
    error error))

(define-read-only (benchmark-ln)
  (match (ln-fixed E_FIXED) ;; ln(e) should be 1
    result (ok (if (> result PRECISION) (- result PRECISION) (- PRECISION result)))
    error error))
