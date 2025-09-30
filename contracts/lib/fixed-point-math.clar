;; fixed-point-math.clar
;; Base fixed-point arithmetic utilities without external dependencies

(use-trait fixed-point-math-trait .all-traits.fixed-point-math-trait)

(define-constant ERR_OVERFLOW (err u2001))
(define-constant ERR_DIVISION_BY_ZERO (err u2002))
(define-constant ERR_INVALID_PRECISION (err u2003))

(impl-trait fixed-point-math-trait)

;; Precision constants
(define-constant ONE_18 u1000000000000000000) ;; 18 decimals
(define-constant ONE_8 u100000000) ;; 8 decimals
(define-constant ONE_6 u1000000) ;; 6 decimals


;; === MULTIPLICATION FUNCTIONS ===
(define-read-only (mul-down (a uint) (b uint))
  (let ((b-whole (/ b ONE_18))
        (b-frac (mod b ONE_18)))
    (+ (* a b-whole) (/ (* a b-frac) ONE_18))))

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
(define-read-only (div-down (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (ok (let ((a-whole (/ a b))
              (a-frac (mod a b)))
          (+ (* a-whole ONE_18) (/ (* a-frac ONE_18) b))))))

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
(define-read-only (to-8-decimal (value uint))
  (/ value u10000000000))

(define-read-only (from-8-decimal (value uint))
  (* value u10000000000))

(define-read-only (to-6-decimal (value uint))
  (/ value u1000000000000))

(define-read-only (from-6-decimal (value uint))
  (* value u1000000000000))

;; === ROUNDING FUNCTIONS ===
(define-read-only (round-fixed (value uint))
  (let ((integer-part (/ value ONE_18))
        (fractional-part (mod value ONE_18)))
    (if (>= fractional-part (/ ONE_18 u2))
      (+ integer-part u1)
      integer-part)))

(define-read-only (floor-fixed (value uint))
  (/ value ONE_18))

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
(define-read-only (percentage (value uint) (percent uint))
  (mul-down value percent))

(define-read-only (basis-points (value uint) (bp uint))
  (mul-down value (/ (* bp ONE_18) u10000)))

;; === INTERPOLATION ===
(define-read-only (lerp (a uint) (b uint) (t uint))
  (if (>= t ONE_18)
    b
    (if (is-eq a b)
      a
      (if (or (is-eq t u0) (is-eq a u0) (is-eq b u0))
        a
        (let ((diff (- b a)))
          (if (or (is-eq diff u0) (is-eq t u0))
            a
            (let ((term (mul-down diff t)))
              (if (>= term diff) b (+ a term)))))))))

;; === SQUARE ROOT HELPER ===
(define-private (compute-sqrt-iter (i uint) (acc {x: uint, z: uint, y: uint}))
  (let ((new-z (/ (+ (get z acc) (get y acc)) u2))
        (new-y (/ (get x acc) new-z)))
    {x: (get x acc), z: new-z, y: new-y}))

;; === SQUARE ROOT FUNCTION ===
(define-read-only (sqrt-fixed (x uint))
  (if (or (is-eq x u0) (is-eq x u1))
    (ok x)
    (let ((half-x (div-down x u2))
          (half-x-val (match half-x v v))
          (sum (+ half-x-val u1))
          (quarter (div-down sum u2))
          (initial-guess (match quarter v v)))
      (ok (get y (fold compute-sqrt-iter
                      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
                      {x: x, z: x, y: initial-guess}))))))

;; === HARMONIC MEAN ===
(define-read-only (harmonic-mean (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    u0
    (let ((numerator (* u2 (mul-down a b)))
          (denominator (+ a b)))
      (/ numerator denominator))))

;; === COMPOUND INTEREST ===
(define-read-only (compound-interest (principal uint) (rate uint) (periods uint))
  (let ((rate-plus-one (+ ONE_18 rate)))
    (match (contract-call? .math-lib-advanced pow-fixed rate-plus-one (from-6-decimal periods))
      powered-rate (ok (mul-down principal powered-rate))
      error (err u3001))))

;; === ABSOLUTE VALUE AND DIFFERENCE ===
(define-read-only (abs-diff (a uint) (b uint))
  (if (>= a b) 
    (- a b) 
    (- b a)))

;; === AVERAGING FUNCTIONS ===
(define-read-only (average (a uint) (b uint))
  (/ (+ a b) u2))

(define-read-only (weighted-average (a uint) (b uint) (weight-a uint) (weight-b uint))
  (let ((total-weight (+ weight-a weight-b)))
    (if (is-eq total-weight u0)
      u0
      (/ (+ (mul-down a weight-a) (mul-down b weight-b)) total-weight))))

;; === CLAMPING ===
(define-read-only (clamp (value uint) (min-val uint) (max-val uint))
  (if (< value min-val)
    min-val
    (if (> value max-val)
      max-val
      value)))

;; === SCALING ===
(define-read-only (scale (value uint) (old-min uint) (old-max uint) (new-min uint) (new-max uint))
  (let ((old-range (- old-max old-min))
        (new-range (- new-max new-min)))
    (if (is-eq old-range u0)
      new-min
      (match (div-down (- value old-min) old-range)
        norm (ok (+ new-min (mul-down norm new-range)))
        error error))))

;; === SAFE MATH OPERATIONS ===
(define-read-only (safe-add (a uint) (b uint))
  (let ((result (+ a b)))
    (if (< result a)
      ERR_OVERFLOW
      (ok result))))

(define-read-only (safe-sub (a uint) (b uint))
  (if (< a b)
    (ok u0)
    (ok (- a b))))

(define-read-only (safe-mul (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (let ((result (* a b)))
      (if (or (< result a) (< result b) (not (is-eq (/ result a) b)))
        ERR_OVERFLOW
        (ok result)))))

