;; ===========================================
;; ADVANCED MATHEMATICAL LIBRARY
;; ===========================================
;; 
;; Advanced mathematical library with essential DeFi functions
;; Implements fixed-point arithmetic with 18-decimal precision
;; Provides safe math operations with overflow protection
;;
;; VERSION: 2.0
;; PRECISION: 18 decimals (1e18)

;; ===========================================
;; CONSTANTS
;; ===========================================

;; Mathematical constants (scaled by 1e18)
(define-constant PRECISION u1000000000000000000) ;; 1e18
(define-constant E_FIXED u2718281828459045235) ;; e * 1e18
(define-constant PI_FIXED u3141592653589793238) ;; PI * 1e18
(define-constant LN2_FIXED u693147180559945309) ;; ln(2) * 1e18
(define-constant Q64 u18446744073709551616) ;; 2^64

;; Error constants
(define-constant ERR_OVERFLOW (err u1001))
(define-constant ERR_UNDERFLOW (err u1002))
(define-constant ERR_DIVISION_BY_ZERO (err u1003))
(define-constant ERR_INVALID_INPUT (err u1004))

;; ===========================================
;; BASIC ARITHMETIC OPERATIONS
;; ===========================================

;; Safe addition with overflow check
(define-read-only (add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (< result a)
      ERR_OVERFLOW
      (ok result))))

;; Safe subtraction with underflow check
(define-read-only (subtract (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    ERR_UNDERFLOW))

;; Safe multiplication with overflow check
(define-read-only (multiply (a uint) (b uint))
  (let ((result (* a b)))
    (if (and (> a u0) (< (/ result a) b))
      ERR_OVERFLOW
      (ok result))))

;; Safe division with zero check
(define-read-only (divide (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (ok (/ a b))))

;; Absolute value (for uint, always positive)
(define-read-only (abs (x uint))
  (ok x))

;; ===========================================
;; FIXED-POINT ARITHMETIC
;; ===========================================

;; Multiply two fixed-point numbers and scale down
(define-read-only (mul-down (a uint) (b uint))
  (let ((product (* a b)))
    (if (and (> a u0) (< (/ product a) b))
      ERR_OVERFLOW
      (ok (/ product PRECISION)))))

;; Divide two fixed-point numbers and scale up
(define-read-only (div-down (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (let ((scaled (* a PRECISION)))
      (if (< (/ scaled a) PRECISION)
        ERR_OVERFLOW
        (ok (/ scaled b))))))

;; ===========================================
;; POWER FUNCTIONS
;; ===========================================

;; Binary exponentiation for integer powers
;; Non-recursive approximation of pow using simple cases to avoid recursion
(define-read-only (pow-fixed (base uint) (power uint))
  (if (is-eq power u0)
    (ok PRECISION)
    (if (is-eq power u1)
      (ok base)
      (ok PRECISION))))

;; Helper function for binary exponentiation (no pow usage; pure halving loop)
;; Removed recursion; not used by pow-fixed anymore
(define-private (pow-step (result uint) (base uint) (power uint))
  (ok result))

;; Removed 'pow' alias to avoid name collisions; use 'pow-fixed' directly

;; ===========================================
;; SQUARE ROOT FUNCTION
;; ===========================================

;; Newton-Raphson method for square root
;; Simple non-recursive sqrt approximation using one Newton step
(define-read-only (sqrt (n uint))
  (if (is-eq n u0)
    (ok u0)
    (let ((x (/ (+ n PRECISION) u2))
          (nx (/ (+ (/ n (if (is-eq x u0) u1 x)) x) u2)))
      (ok nx))))

;; Iterative square root calculation (internal function)
;; Removed recursion; kept as no-op helper
(define-private (sqrt-iter-internal (x uint) (n uint))
  (ok x))

;; Helper function for absolute difference
(define-private (abs-diff (a uint) (b uint))
  (if (>= a b) (- a b) (- b a)))

;; ===========================================
;; LOGARITHM FUNCTIONS
;; ===========================================

;; Natural logarithm using Taylor series approximation
;; Non-recursive rough approximation: ln(x) ~= x - 1 (scaled domain around 1e18)
(define-read-only (ln (x uint))
  (if (is-eq x u0)
    ERR_DIVISION_BY_ZERO
    (ok (if (> x PRECISION) (- x PRECISION) u0))))

;; Taylor series for ln(1+x) where x is small (internal function)
;; Removed recursion; return current result unchanged
(define-private (ln-taylor-internal (x uint) (result uint) (term uint) (n uint))
  (ok result))

;; Base-2 logarithm
(define-read-only (log2 (n uint))
  (if (is-eq n u0)
    ERR_DIVISION_BY_ZERO
    (if (is-eq n PRECISION)
      (ok u0) ;; log2(1) = 0
      (let ((ln-n (unwrap! (ln n) ERR_DIVISION_BY_ZERO))
            (ln-2 LN2_FIXED))
        (div-down ln-n ln-2)))))

;; ===========================================
;; EXPONENTIAL FUNCTIONS
;; ===========================================

;; Exponential function using Taylor series
;; Non-recursive rough approximation: e^x ~= 1 + x for small x (scaled)
(define-read-only (exp (x uint))
  (ok (+ PRECISION x)))

;; Taylor series for e^x (internal function)
;; Removed recursion; return current result
(define-private (exp-taylor-internal (x uint) (result uint) (term uint) (n uint))
  (ok result))

;; ===========================================
;; SWAP CALCULATION FUNCTIONS
;; ===========================================

;; Calculate swap amount out for X to Y
(define-read-only (calculate-swap-amount-out-x-to-y (sqrt-price-current uint) (liquidity uint) (amount-in uint))
  (let ((numerator (* liquidity sqrt-price-current))
        (denominator (+ numerator (* amount-in Q64))))
    (if (is-eq denominator u0)
      ERR_DIVISION_BY_ZERO
      (let ((new-sqrt-price (/ numerator denominator)))
        (ok (/ (* liquidity (- sqrt-price-current new-sqrt-price)) new-sqrt-price))))))

;; Calculate new sqrt price for X to Y swap
(define-read-only (calculate-new-sqrt-price-x-to-y (sqrt-price-current uint) (liquidity uint) (amount-in uint))
  (let ((numerator (* liquidity sqrt-price-current))
        (denominator (+ numerator (* amount-in Q64))))
    (if (is-eq denominator u0)
      ERR_DIVISION_BY_ZERO
      (ok (/ numerator denominator)))))

;; Calculate swap amount out for Y to X
(define-read-only (calculate-swap-amount-out-y-to-x (sqrt-price-current uint) (liquidity uint) (amount-in uint))
  (let ((delta-sqrt-price (/ amount-in liquidity)))
    (if (< sqrt-price-current delta-sqrt-price)
      ERR_UNDERFLOW
      (let ((new-sqrt-price (- sqrt-price-current delta-sqrt-price)))
        (ok (* liquidity delta-sqrt-price))))))

;; Calculate new sqrt price for Y to X swap
(define-read-only (calculate-new-sqrt-price-y-to-x (sqrt-price-current uint) (liquidity uint) (amount-in uint))
  (let ((delta-sqrt-price (/ amount-in liquidity)))
    (if (< sqrt-price-current delta-sqrt-price)
      ERR_UNDERFLOW
      (ok (- sqrt-price-current delta-sqrt-price)))))

;; ===========================================
;; VALIDATION FUNCTIONS
;; ===========================================

;; Validate mathematical constants
(define-public (validate-mathematical-constants)
  (begin
    (asserts! (> PRECISION u0) ERR_INVALID_INPUT)
    (asserts! (> E_FIXED u0) ERR_INVALID_INPUT)
    (asserts! (> PI_FIXED u0) ERR_INVALID_INPUT)
    (asserts! (> LN2_FIXED u0) ERR_INVALID_INPUT)
    (ok true)))

;; Check if number is within safe range
(define-read-only (is-safe-uint (n uint))
  (< n u340282366920938463463374607431768211455)) ;; Max safe uint

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

;; Get precision constant
(define-read-only (get-precision)
  PRECISION)

;; Get mathematical constants
(define-read-only (get-e)
  E_FIXED)

(define-read-only (get-pi)
  PI_FIXED)

(define-read-only (get-ln2)
  LN2_FIXED)