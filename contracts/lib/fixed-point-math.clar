;; fixed-point-math.clar
;; Precise fixed-point arithmetic utilities for DeFi calculations
;; Supports multiple precision levels and rounding modes

(define-constant ERR_OVERFLOW (err u2001))
(define-constant ERR_DIVISION_BY_ZERO (err u2002))
(define-constant ERR_INVALID_PRECISION (err u2003))

;; Precision constants
(define-constant ONE_18 u1000000000000000000) ;; 18 decimals
(define-constant ONE_8 u100000000) ;; 8 decimals
(define-constant ONE_6 u1000000) ;; 6 decimals

;; === MULTIPLICATION FUNCTIONS ===
;; Safe multiplication of two 18-decimal fixed-point numbers, rounding down.
;; Prevents overflow by decomposing the multiplication.
(define-read-only (mul-down (a uint) (b uint))
  (let ((b-whole (/ b ONE_18))
        (b-frac (mod b ONE_18)))
    (+ (* a b-whole) (/ (* a b-frac) ONE_18))))

;; Safe multiplication of two 18-decimal fixed-point numbers, rounding up.
;; Prevents overflow by decomposing the multiplication.
(define-read-only (mul-up (a uint) (b uint))
  (let ((b-whole (/ b ONE_18))
        (b-frac (mod b ONE_18)))
    (let ((term1 (* a b-whole))
          (term2-product (* a b-frac)))
      (let ((term2 (/ term2-product ONE_18))
            (rem (mod term2-product ONE_18)))
        (if (> rem u0)
          (+ term1 term2 u1)
          (+ term1 term2))))))

;; === DIVISION FUNCTIONS ===
;; Safe division of two 18-decimal fixed-point numbers, rounding down.
;; Prevents overflow by decomposing the division.
(define-read-only (div-down (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (ok (let ((a-whole (/ a b))
              (a-frac (mod a b)))
          (+ (* a-whole ONE_18) (/ (* a-frac ONE_18) b))))))

;; Safe division of two 18-decimal fixed-point numbers, rounding up.
;; Prevents overflow by decomposing the division.
(define-read-only (div-up (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (ok
      (let ((a-whole (/ a b))
            (a-frac (mod a b)))
        (let ((term1 (* a-whole ONE_18))
              (term2-product (* a-frac ONE_18)))
          (let ((term2 (/ term2-product b))
                (rem (mod term2-product b)))
            (if (> rem u0)
              (+ term1 term2 u1)
              (+ term1 term2))))))))

;; === PRECISION CONVERSION ===
;; Convert from 18-decimal to 8-decimal precision
(define-read-only (to-8-decimal (value uint))
  (/ value u10000000000)) ;; Divide by 10^10

;; Convert from 8-decimal to 18-decimal precision
(define-read-only (from-8-decimal (value uint))
  (* value u10000000000)) ;; Multiply by 10^10

;; Convert from 18-decimal to 6-decimal precision
(define-read-only (to-6-decimal (value uint))
  (/ value u1000000000000)) ;; Divide by 10^12

;; Convert from 6-decimal to 18-decimal precision
(define-read-only (from-6-decimal (value uint))
  (* value u1000000000000)) ;; Multiply by 10^12

;; === ROUNDING FUNCTIONS ===
;; Round to nearest integer (18-decimal to whole number)
(define-read-only (round-fixed (value uint))
  (let ((integer-part (/ value ONE_18))
        (fractional-part (mod value ONE_18)))
    (if (>= fractional-part (/ ONE_18 u2))
      (+ integer-part u1)
      integer-part)))

;; Floor function (remove fractional part)
(define-read-only (floor-fixed (value uint))
  (/ value ONE_18))

;; Ceiling function (round up if any fractional part)
(define-read-only (ceil-fixed (value uint))
  (let ((integer-part (/ value ONE_18))
        (fractional-part (mod value ONE_18)))
    (if (> fractional-part u0)
      (+ integer-part u1)
      integer-part)))

;; === COMPARISON FUNCTIONS ===
(define-read-only (eq-fixed (a uint) (b uint))
  (is-eq a b))

(define-read-only (lt-fixed (a uint) (b uint))
  (< a b))

(define-read-only (lte-fixed (a uint) (b uint))
  (<= a b))

(define-read-only (gt-fixed (a uint) (b uint))
  (> a b))

(define-read-only (gte-fixed (a uint) (b uint))
  (>= a b))

;; === PERCENTAGE CALCULATIONS ===
;; Calculate percentage of a value (both in 18-decimal)
(define-read-only (percentage (value uint) (percent uint))
  (mul-down value percent))

;; Calculate basis points (1 bp = 0.01% = 0.0001 = 1e14 in 18-decimal)
(define-read-only (basis-points (value uint) (bp uint))
  (mul-down value (/ (* bp ONE_18) u10000)))

;; === INTERPOLATION ===
;; Linear interpolation between two values
;; t should be between 0 and 1 (in 18-decimal fixed point)
(define-read-only (lerp (a uint) (b uint) (t uint))
  (if (>= t ONE_18)
    b ;; Clamp t to 1.0
    (if (is-eq a b)
      a ;; If a and b are equal, no need to interpolate
      (if (or (is-eq t u0) (is-eq a u0) (is-eq b u0))
        a ;; If t is 0 or any of the values is 0, return a
        (let ((diff (- b a)))
          (if (or (is-eq diff u0) (is-eq t u0))
            a
            (let ((term (mul-down diff t)))
              (if (>= term (- b a)) b (+ a term)))))))))

;; === SQUARE ROOT FUNCTION ===
;; Helper function for Babylonian method with iteration
(define-private (sqrt-iter (x uint) (y uint) (z uint) (iterations uint))
  (if (or (>= iterations u10) (>= z y))  ;; Limit iterations to prevent stack overflow
    z
    (let ((new-z (match (div-down (+ (match (div-down x z) (ok v) v) z) u2) (ok v) v)))
      (if (>= new-z y)
        z
        (sqrt-iter x z new-z (+ iterations u1))))))

;; Calculate square root using the Babylonian method (Heron's method)
(define-read-only (sqrt-fixed (x uint))
  (if (or (is-eq x u0) (is-eq x u1))
    (ok x)
    (let ((initial-guess (match (div-down (+ (match (div-down x u2) (ok v) v) u1) u2) (ok v) v)))
      (let ((result (sqrt-iter x x initial-guess u0)))
        (ok result)))))

;; === GEOMETRIC MEAN ===
;; Calculate geometric mean of two numbers: sqrt(a * b)
(define-read-only (geometric-mean (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (match (sqrt-fixed (mul-down a b))
      result (ok result)
      error error)))

;; === HARMONIC MEAN ===
;; Calculate harmonic mean: 2 / (1/a + 1/b) = 2ab / (a + b)
(define-read-only (harmonic-mean (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (match (div-down (mul-down (* u2 ONE_18) (mul-down a b)) (+ a b))
      result (ok result)
      error error)))

;; === COMPOUND INTEREST ===
;; Calculate compound interest: principal * (1 + rate)^periods
;; Rate and result in 18-decimal fixed point
(define-read-only (compound-interest (principal uint) (rate uint) (periods uint))
  (let ((rate-plus-one (+ ONE_18 rate)))
    (match (contract-call? .math-lib-advanced pow-fixed rate-plus-one (from-6-decimal periods))
      powered-rate (ok (mul-down principal powered-rate))
      error error)))

;; === ABSOLUTE VALUE AND DIFFERENCE ===
(define-read-only (abs-diff (a uint) (b uint))
  (if (>= a b) 
    (- a b) 
    (- b a)))

;; === AVERAGING FUNCTIONS ===
;; Simple arithmetic mean
(define-read-only (average (a uint) (b uint))
  (/ (+ a b) u2))

;; Weighted average
(define-read-only (weighted-average (a uint) (b uint) (weight-a uint) (weight-b uint))
  (let ((total-weight (+ weight-a weight-b)))
    (if (is-eq total-weight u0)
      u0
      (/ (+ (mul-down a weight-a) (mul-down b weight-b)) total-weight))))

;; === CLAMPING ===
;; Ensure value is within bounds
(define-read-only (clamp (value uint) (min-val uint) (max-val uint))
  (if (< value min-val)
    min-val
    (if (> value max-val)
      max-val
      value)))

;; === SCALING ===
;; Scale a value from one range to another
(define-read-only (scale-range (value uint) (old-min uint) (old-max uint) (new-min uint) (new-max uint))
  (let ((old-range (- old-max old-min))
        (new-range (- new-max new-min)))
    (if (is-eq old-range u0)
      new-min
      (let ((norm (unwrap! (div-down (- value old-min) old-range) u2002)))
        (+ new-min (mul-down norm new-range))))))

;; === SAFE MATH OPERATIONS ===
;; Safe addition with overflow check
(define-read-only (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (< result a) ;; Overflow occurred
      ERR_OVERFLOW
      (ok result))))

;; Safe subtraction with underflow check
(define-read-only (safe-sub (a uint) (b uint))
  (if (< a b)
    (ok u0) ;; Return 0 instead of underflowing
    (ok (- a b))))

;; Safe multiplication with overflow check
(define-read-only (safe-mul (a uint) (b uint))
  (if (is-eq a u0)
    (ok u0)
    (let ((result (* a b)))
      (if (not (is-eq (/ result a) b)) ;; Overflow check
        ERR_OVERFLOW
        (ok result)))))
