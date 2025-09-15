;; math-lib-advanced.clar
;; Advanced mathematical library with essential DeFi functions
;; Standalone implementation without dependencies

(define-constant ERR_INVALID_INPUT (err u1001))
(define-constant ERR_OVERFLOW (err u1002))
(define-constant ERR_UNDERFLOW (err u1003))
(define-constant ERR_PRECISION_LOSS (err u1004))

;; Fixed-point precision constant
(define-constant PRECISION u1000000000000000000) ;; 18 decimals (1e18)

;; Mathematical constants in 18-decimal fixed point
(define-constant E_FIXED u2718281828459045235) ;; e ~ 2.718281828459045235

;; === SAFE MATH ===
(define-private (mul-down (a uint) (b uint))
  (/ (* a b) PRECISION))

(define-private (div-down (a uint) (b uint))
  (if (is-eq b u0)
    u0 ;; Return 0 for division by zero - caller should check result
    (/ (* a PRECISION) b)))

;; === ABS ===
(define-private (abs (x int))
  (if (< x 0)
    (* x -1)
    x
  )
)

(define-private (abs (x uint))
  x
)

;; === INTEGER SQUARE ROOT ===
(define-private (sqrt-iter (n uint) (guess uint) (prev-guess uint))
  (if (or (is-eq guess prev-guess) (<= (abs (- guess prev-guess)) u1))
    guess
    (sqrt-iter n (average guess (/ n guess)) guess)
  )
)

(define-read-only (sqrt-integer (n uint))
  (if (is-eq n u0)
    (ok u0)
    (ok (sqrt-iter n (max u1 (/ n u2)) n))
  )
)

;; === MIN/MAX ===
(define-read-only (min (a uint) (b uint))
  (if (< a b)
    (ok a)
    (ok b)))

(define-read-only (max (a uint) (b uint))
  (if (> a b)
    (ok a)
    (ok b)))