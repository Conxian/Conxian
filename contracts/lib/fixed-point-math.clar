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
;; Multiply two 18-decimal fixed-point numbers, round down
(define-read-only (mul-down (a uint) (b uint))
  (/ (* a b) ONE_18))

;; Multiply two 18-decimal fixed-point numbers, round up
(define-read-only (mul-up (a uint) (b uint))
  (let ((product (* a b)))
    (if (is-eq (mod product ONE_18) u0)
      (/ product ONE_18)
      (+ (/ product ONE_18) u1))))

;; === DIVISION FUNCTIONS ===
;; Divide two 18-decimal fixed-point numbers, round down
(define-read-only (div-down (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (ok (/ (* a ONE_18) b))))

;; Divide two 18-decimal fixed-point numbers, round up
(define-read-only (div-up (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (let ((numerator (* a ONE_18)))
      (if (is-eq (mod numerator b) u0)
        (ok (/ numerator b))
        (ok (+ (/ numerator b) u1))))))

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
  (if (> t ONE_18)
    b ;; Clamp t to 1.0
    (+ a (mul-down (- b a) t))))

;; === SQUARE ROOT FUNCTION ===
;; Calculate square root using the Babylonian method (Heron's method)
(define-read-only (sqrt-fixed (x uint))
  (if (or (is-eq x u0) (is-eq x u1))
    x
    (let (
      (z (div (+ (div x u2) u1) u2))  ;; Initial guess
      (y x))
      (while (< z y)
        (let ((new-z (div (+ (div x z) z) u2)))
          (set! y z)
          (set! z new-z)))
      z)))

;; === GEOMETRIC MEAN ===
;; Calculate geometric mean of two numbers: sqrt(a * b)
(define-read-only (geometric-mean (a uint) (b uint))
  (sqrt-fixed (mul-down a b)))

;; === HARMONIC MEAN ===
;; Calculate harmonic mean: 2 / (1/a + 1/b) = 2ab / (a + b)
(define-read-only (harmonic-mean (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (div-down (mul-down (* u2 ONE_18) (mul-down a b)) (+ a b))))

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
