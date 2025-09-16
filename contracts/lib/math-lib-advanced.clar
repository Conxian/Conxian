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
(define-read-only (mul-down (a uint) (b uint))
  (if (or (is-eq a u0) (is-eq b u0))
    (ok u0)
    (let ((result (/ (* a b) PRECISION)))
      (if (is-eq result u0)
        (err ERR_UNDERFLOW)
        (ok result)
      )
    )
  )
)

(define-read-only (div-down (a uint) (b uint))
  (if (is-eq b u0)
    (err ERR_INVALID_INPUT)
    (ok (/ (* a PRECISION) b)))
)

;; Alias for div-down to maintain compatibility
(define-read-only (safe-div (a uint) (b uint))
  (div-down a b)
)

;; === ABS ===
(define-read-only (abs (x int))
  (if (< x 0)
    (* x -1)
    x
  )
)

(define-read-only (abs (x uint))
  x
)

;; === INTEGER SQUARE ROOT (Newton's method) ===
(define-read-only (sqrt-integer (n uint))
  (if (is-eq n u0)
    (ok u0)
    (let ((initial-guess (max u1 (unwrap! (div-down n u2) (err ERR_OVERFLOW)))))
      (ok (sqrt-iter n initial-guess u0))
    )
  )
)

(define-private (sqrt-iter (n uint) (guess uint) (prev-guess uint))
  (if (or (is-eq guess prev-guess) (<= (abs (- guess prev-guess)) u1))
    guess
    (let ((next-guess (average guess (unwrap! (div-down n guess) (err ERR_OVERFLOW)))))
      (sqrt-iter n next-guess guess)
    )
  )
)

;; === UTILITY FUNCTIONS ===
(define-read-only (average (a uint) (b uint))
  (unwrap! (safe-div (+ a b) u2) (err ERR_OVERFLOW))
)

(define-read-only (min (a uint) (b uint))
  (if (< a b) a b))

(define-read-only (max (a uint) (b uint))
  (if (> a b) a b))