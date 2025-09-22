;; math-lib-advanced.clar
;; Advanced mathematical library with essential DeFi functions
;; Implements math-trait for standard interface

;; Standardized trait references
(use-trait math-trait .all-traits.math-trait)
(impl-trait .all-traits.math-trait)

;; Error codes
(define-constant ERR_INVALID_INPUT (err u1001))
(define-constant ERR_OVERFLOW (err u1002))
(define-constant ERR_UNDERFLOW (err u1003))
(define-constant ERR_PRECISION_LOSS (err u1004))

;; Fixed-point precision constants
(define-constant PRECISION u1000000000000000000) ;; 18 decimals (1e18)
(define-constant HALF_PRECISION u500000000000000000) ;; 0.5 * PRECISION
(define-constant TWO_PRECISION u2000000000000000000) ;; 2 * PRECISION

;; ======================
;; Basic Math Operations
;; ======================

(define-read-only (abs-int (x int))
  (if (< x 0) (* x -1) x))

(define-read-only (abs-uint (x uint))
  x)

(define-read-only (min (a uint) (b uint))
  (if (< a b) a b))

(define-read-only (max (a uint) (b uint))
  (if (> a b) a b))

(define-read-only (average (a uint) (b uint))
  (unwrap! (div-down (+ a b) u2) (err ERR_OVERFLOW)))

;; ======================
;; Safe Math Operations
;; ======================

(define-read-only (safe-add (a uint) (b uint))
  (let ((sum (+ a b)))
    (if (or (< sum a) (< sum b))
      (err ERR_OVERFLOW)
      (ok sum))))

(define-read-only (safe-sub (a uint) (b uint))
  (if (< a b)
    (err ERR_UNDERFLOW)
    (ok (- a b))))

(define-read-only (safe-mul (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (let ((result (/ (* a b) PRECISION)))
      (if (is-eq result u0)
        (err ERR_UNDERFLOW)
        (ok result)))))

(define-read-only (safe-div (a uint) (b uint))
  (if (is-eq b u0)
    (err ERR_INVALID_INPUT)
    (ok (/ (* a PRECISION) b))))

(define-read-only (div-down (a uint) (b uint))
  (safe-div a b))

(define-read-only (mul-down (a uint) (b uint))
  (safe-mul a b))

;; ======================
;; Square Root Functions
;; ======================

(define-read-only (sqrt (n uint))
  (if (or (is-eq n u0) (is-eq n u1))
    (ok n)
    (let ((guess (if (> n u1000000) u1000 u100)))
      (ok (sqrt-iter n guess)))))

(define-read-only (sqrt-integer (n uint))
  (if (or (is-eq n u0) (is-eq n u1))
    (ok n)
    (let ((guess (if (> n u1000000) u1000 u100)))
      (ok (sqrt-iter n guess)))))

(define-read-only (sqrt-fixed (x uint))
  (if (or (is-eq x u0) (is-eq x u1))
    (ok x)
    (let ((guess (unwrap! (div-down x u2) (err ERR_OVERFLOW))))
      (ok (sqrt-iter x guess)))))

(define-private (sqrt-iter (n uint) (guess uint))
  (let ((next-guess (average guess (unwrap! (div-down n guess) (err ERR_OVERFLOW)))))
    (if (or (is-eq guess next-guess) (<= (abs-uint (- guess next-guess)) u1))
      next-guess
      (sqrt-iter n next-guess))))

;; ======================
;; Math Trait Implementation
;; ======================

(define-public (add (a uint) (b uint))
  (safe-add a b))

(define-public (subtract (a uint) (b uint))
  (safe-sub a b))

(define-public (multiply (a uint) (b uint))
  (safe-mul a b))

(define-public (divide (a uint) (b uint))
  (safe-div a b))

(define-public (square-root (n uint))
  (sqrt n))

;; ======================
;; Exponential and Logarithmic Functions
;; ======================

(define-read-only (exp-fixed (x uint))
  (if (is-eq x u0)
    (ok PRECISION)  ;; e^0 = 1
    (let* ((negative (> x PRECISION))
           (x-abs (if negative (unwrap! (safe-sub (unwrap! (safe-mul u2 PRECISION) (err ERR_OVERFLOW)) x) (err ERR_UNDERFLOW)) x))
           (integer (unwrap! (div-down x-abs PRECISION) (err ERR_UNDERFLOW)))
           (fractional (unwrap! (safe-mod x-abs PRECISION) (err ERR_UNDERFLOW)))
           (exp-int (exp-integer integer))
           (exp-frac (exp-fractional fractional))
           (result (unwrap! (mul-down exp-int exp-frac) (err ERR_OVERFLOW))))
      (if negative
        (div-down PRECISION result)
        (ok result)))))

(define-read-only (exp-integer (n uint))
  (if (is-eq n u0)
    (ok PRECISION)
    (let* ((half (unwrap! (div-down n u2) (err ERR_UNDERFLOW)))
           (half-exp (unwrap! (exp-integer half) (err ERR_OVERFLOW))))
      (mul-down half-exp half-exp))))

(define-read-only (exp-fractional (x uint))
  (let ((term PRECISION)
        (sum PRECISION)
        (i u1))
    (fold (range u1 u21) sum
      (let* ((term (unwrap! (div-down (unwrap! (mul-down term x) (err ERR_OVERFLOW)) i) (err ERR_UNDERFLOW)))
             (new-sum (unwrap! (safe-add sum term) (err ERR_OVERFLOW))))
        (ok (tuple (new-sum) (unwrap! (safe-add i u1) (err ERR_OVERFLOW))))))))

(define-read-only (ln-fixed (x uint))
  (if (or (<= x u0))
    (err ERR_INVALID_INPUT)
    (if (is-eq x PRECISION)
      (ok u0)  ;; ln(1) = 0
      (let* ((log2 (ln2-iter x u0))
             (y (unwrap! (div-down x (unwrap! (pow-fixed u2 log2) (err ERR_OVERFLOW))) (err ERR_UNDERFLOW)))
             (z (unwrap! (safe-sub y PRECISION) (err ERR_UNDERFLOW)))
             (t (unwrap! (div-down z (unwrap! (safe-add y PRECISION) (err ERR_OVERFLOW))) (err ERR_UNDERFLOW)))
             (t-sq (unwrap! (mul-down t t) (err ERR_OVERFLOW)))
             (p (ln2-approx t t-sq u0 u0 u0)))
        (ok (unwrap! (safe-add (unwrap! (mul-down p (unwrap! (safe-mul u2 t) (err ERR_OVERFLOW))) (err ERR_OVERFLOW)) 
                              (unwrap! (mul-down log2 (unwrap! (ln2-fixed) (err ERR_OVERFLOW))) (err ERR_OVERFLOW))) 
                    (err ERR_OVERFLOW)))))))

(define-read-only (ln2-fixed)
  (ok LN2_FIXED))

(define-private (ln2-iter (x uint) (count uint))
  (if (<= x PRECISION)
    count
    (ln2-iter (unwrap! (div-down x u2) (err ERR_UNDERFLOW)) 
              (unwrap! (safe-add count PRECISION) (err ERR_OVERFLOW)))))

(define-private (ln2-approx (t uint) (t-sq uint) (n uint) (p uint) (i uint))
  (if (>= i u10)  ;; 10 iterations for good precision
    (ok p)
    (let* ((term (unwrap! (div-down (unwrap! (pow-fixed t-sq n) (err ERR_OVERFLOW)) 
                                   (unwrap! (safe-mul u2 (unwrap! (safe-add i u1) (err ERR_OVERFLOW))) (err ERR_OVERFLOW))) 
                         (err ERR_UNDERFLOW)))
           (new-p (if (is-eq (mod n u2) u0)
                     (unwrap! (safe-add p term) (err ERR_OVERFLOW))
                     (unwrap! (safe-sub p term) (err ERR_UNDERFLOW)))))
      (ln2-approx t t-sq 
                 (unwrap! (safe-add n PRECISION) (err ERR_OVERFLOW)) 
                 new-p 
                 (unwrap! (safe-add i PRECISION) (err ERR_OVERFLOW))))))

;; ======================
;; Power Function
;; ======================

(define-read-only (pow-fixed (base uint) (exp uint))
  (if (is-eq exp u0)
    (ok PRECISION) ;; x^0 = 1
    (if (is-eq exp PRECISION)
      (ok base)    ;; x^1 = x
      (if (is-eq (mod exp u2) u0)
        ;; Even exponent: x^2n = (x^2)^n
        (let ((x-squared (unwrap! (mul-down base base) (err ERR_OVERFLOW))))
          (pow-fixed x-squared (unwrap! (div-down exp u2) (err ERR_UNDERFLOW))))
        ;; Odd exponent: x^(2n+1) = x * (x^2)^n
        (let* ((x-squared (unwrap! (mul-down base base) (err ERR_OVERFLOW)))
               (exp-half (unwrap! (div-down (unwrap! (safe-sub exp PRECISION) (err ERR_UNDERFLOW)) u2) (err ERR_UNDERFLOW)))
               (pow-half (unwrap! (pow-fixed x-squared exp-half) (err ERR_OVERFLOW))))
          (mul-down base pow-half))))))



;; ======================
;; Exponential and Logarithmic Functions
;; ======================

(define-read-only (factorial (n uint))
  (if (or (is-eq n u0) (is-eq n u1))
    (ok PRECISION)
    (mul-down n (unwrap! (factorial (unwrap! (safe-sub n PRECISION) (err ERR_UNDERFLOW))) (err ERR_OVERFLOW))))
)

(define-private (exp-integer (n uint))
  (if (is-eq n u0)
    (ok PRECISION)
    (let* (
      (half (unwrap! (div-down n u2) (err ERR_UNDERFLOW)))
      (half-exp (unwrap! (exp-integer half) (err ERR_OVERFLOW)))
      (square (unwrap! (mul-down half-exp half-exp) (err ERR_OVERFLOW)))
    )
      (if (is-eq (mod n u2) u0)
        (ok square)
        (mul-down square E_FIXED)
      )
    )
  )
)

(define-private (exp-fractional (x uint))
  (let* (
    (x-sq (unwrap! (mul-down x x) (err ERR_OVERFLOW)))
    (x-cu (unwrap! (mul-down x-sq x) (err ERR_OVERFLOW)))
    (t1 (unwrap! (safe-add (unwrap! (div-down x-cu (unwrap! (factorial u3) (err ERR_UNDERFLOW))) (err ERR_UNDERFLOW))
                          (unwrap! (safe-add x (unwrap! (div-down x-sq u2) (err ERR_UNDERFLOW))) (err ERR_OVERFLOW))) (err ERR_OVERFLOW)))
  )
    (ok (unwrap! (safe-add PRECISION t1) (err ERR_OVERFLOW)))
  )
)

(define-read-only (exp-fixed (x uint))
  (if (is-eq x u0)
    (ok PRECISION)  ;; e^0 = 1
    (let* (
      (negative (if (> x PRECISION) true false))
      (x-abs (if negative (unwrap! (safe-sub (unwrap! (safe-mul u2 PRECISION) (err ERR_OVERFLOW)) x) (err ERR_UNDERFLOW)) x))
      (integer (unwrap! (div-down x-abs PRECISION) (err ERR_UNDERFLOW)))
      (fractional (unwrap! (safe-mod x-abs PRECISION) (err ERR_UNDERFLOW)))
      (exp-int (exp-integer integer))
      (exp-frac (exp-fractional fractional))
      (result (unwrap! (mul-down exp-int exp-frac) (err ERR_OVERFLOW)))
    )
      (if negative
        (div-down PRECISION result)
        (ok result)
      )
    )
  )
)

(define-private (ln2-iter (x uint) (count uint))
  (if (<= x PRECISION)
    count
    (ln2-iter (unwrap! (div-down x u2) (err ERR_UNDERFLOW)) 
              (unwrap! (safe-add count PRECISION) (err ERR_OVERFLOW)))))

(define-private (ln2-approx (t uint) (t-sq uint) (n uint) (p uint) (i uint))
  (if (>= i u10)  ;; 10 iterations for good precision
    (ok p)
    (let* ((term (unwrap! (div-down (unwrap! (pow-fixed t-sq n) (err ERR_OVERFLOW)) 
                                   (unwrap! (safe-mul u2 (unwrap! (safe-add i u1) (err ERR_OVERFLOW))) (err ERR_OVERFLOW))) 
                         (err ERR_UNDERFLOW)))
           (new-p (if (is-eq (mod n u2) u0)
                     (unwrap! (safe-add p term) (err ERR_OVERFLOW))
                     (unwrap! (safe-sub p term) (err ERR_UNDERFLOW)))))
      (ln2-approx t t-sq 
                 (unwrap! (safe-add n PRECISION) (err ERR_OVERFLOW)) 
                 new-p 
                 (unwrap! (safe-add i PRECISION) (err ERR_OVERFLOW))))))

(define-read-only (ln-fixed (x uint))
  (if (or (<= x u0))
    (err ERR_INVALID_INPUT)
    (if (is-eq x PRECISION)
      (ok u0)  ;; ln(1) = 0
      (let* ((log2 (ln2-iter x u0))
             (y (unwrap! (div-down x (unwrap! (pow-fixed u2 log2) (err ERR_OVERFLOW))) (err ERR_UNDERFLOW)))
             (z (unwrap! (safe-sub y PRECISION) (err ERR_UNDERFLOW)))
             (t (unwrap! (div-down z (unwrap! (safe-add y PRECISION) (err ERR_OVERFLOW))) (err ERR_UNDERFLOW)))
             (t-sq (unwrap! (mul-down t t) (err ERR_OVERFLOW)))
             (p (ln2-approx t t-sq u0 u0 u0)))
        (ok (unwrap! (safe-add (unwrap! (mul-down p (unwrap! (safe-mul u2 t) (err ERR_OVERFLOW))) (err ERR_OVERFLOW)) 
                              (unwrap! (mul-down log2 (unwrap! (ln2-fixed) (err ERR_OVERFLOW))) (err ERR_OVERFLOW))) 
                    (err ERR_OVERFLOW)))))))

;; ======================
;; Power Function
;; ======================

(define-read-only (pow-fixed (base uint) (exp uint))
  (if (is-eq exp u0)
    (ok PRECISION) ;; x^0 = 1
    (if (is-eq exp PRECISION)
      (ok base)    ;; x^1 = x
      (if (is-eq (mod exp u2) u0)
        ;; Even exponent: x^2n = (x^2)^n
        (let ((x-squared (unwrap! (mul-down base base) (err ERR_OVERFLOW))))
          (pow-fixed x-squared (unwrap! (div-down exp u2) (err ERR_UNDERFLOW))))
        ;; Odd exponent: x^(2n+1) = x * (x^2)^n
        (let* ((x-squared (unwrap! (mul-down base base) (err ERR_OVERFLOW)))
               (exp-half (unwrap! (div-down (unwrap! (safe-sub exp PRECISION) (err ERR_UNDERFLOW)) u2) (err ERR_UNDERFLOW)))
               (pow-half (unwrap! (pow-fixed x-squared exp-half) (err ERR_OVERFLOW))))
          (mul-down base pow-half))))))




;; ======================
;; Constants
;; ======================

(define-constant E_FIXED 2718281828459045235)  ;; e * 1e18
(define-constant LN2_FIXED 6931471805599453094)  ;; ln(2) * 1e18

(define-constant AUDIT_REGISTRY (concat CONTRACT_OWNER .audit-registry))

(define-public (validate-mathematical-constants)
)
