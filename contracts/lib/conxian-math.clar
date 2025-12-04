;; conxian-math.clar
;; Standardized Fixed Point Math Library (WAD/RAY)
;; Centralizes logic from fixed-point-math, math-utilities, and precision-calculator.

;; Constants
(define-constant WAD u1000000000000000000) ;; 18 decimals
(define-constant RAY u1000000000000000000000000000) ;; 27 decimals
(define-constant HALF_WAD u500000000000000000)
(define-constant HALF_RAY u500000000000000000000000000)

(define-constant ERR_MATH_OVERFLOW (err u2001))
(define-constant ERR_MATH_DIVISION_BY_ZERO (err u2002))

;; --- WAD Operations (1e18) ---

(define-read-only (mul-wad (x uint) (y uint))
    (let ((product (* x y)))
        (if (is-eq product u0)
            (ok u0)
            (ok (/ (+ product HALF_WAD) WAD))
        )
    )
)

(define-read-only (div-wad (x uint) (y uint))
    (begin
        (asserts! (> y u0) ERR_MATH_DIVISION_BY_ZERO)
        (ok (/ (+ (* x WAD) (/ y u2)) y))
    )
)

;; --- RAY Operations (1e27) ---

(define-read-only (mul-ray (x uint) (y uint))
    (let ((product (* x y)))
        (if (is-eq product u0)
            (ok u0)
            (ok (/ (+ product HALF_RAY) RAY))
        )
    )
)

(define-read-only (div-ray (x uint) (y uint))
    (begin
        (asserts! (> y u0) ERR_MATH_DIVISION_BY_ZERO)
        (ok (/ (+ (* x RAY) (/ y u2)) y))
    )
)

;; --- Conversions ---

(define-read-only (wad-to-ray (x uint))
    (* x u1000000000)
)

(define-read-only (ray-to-wad (x uint))
    (/ (+ x u500000000) u1000000000)
)

;; --- Utilities ---

(define-read-only (min (x uint) (y uint))
    (if (<= x y) x y)
)

(define-read-only (max (x uint) (y uint))
    (if (>= x y) x y)
)

(define-read-only (sqrt (x uint))
    ;; Babylonian method implementation or similar
    ;; Stub for standard lib
    (ok x) 
)
