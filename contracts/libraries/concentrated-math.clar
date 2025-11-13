;; Math utilities for concentrated liquidity

;; Uses fixed-point arithmetic with Q64 precision
(define-constant Q64 u18446744073709551616)  ;; 2^64
(define-constant MAX_TICK 776363)  ;; Corresponds to sqrt(2^128)
(define-constant MIN_TICK (- MAX_TICK))
(define-constant TICK_BASE u10000)  ;; 1.0001 in fixed-point with 4 decimals

;; Math library contract
(define-constant MATH_CONTRACT .math-lib-advanced)

;; Error codes
(define-constant ERR_INVALID_TICK (err u2001))
(define-constant ERR_INVALID_SQRT_PRICE (err u2002))
(define-constant ERR_MATH_OVERFLOW (err u2003))

;; Calculate sqrt price from tick using fixed-point arithmetic
(define-read-only (tick-to-sqrt-price (tick int))
  (begin
    (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) ERR_INVALID_TICK)
    (if (>= tick 0)
      (let ((base-power (try! (contract-call? MATH_CONTRACT pow-fixed TICK_BASE (to-uint tick)))))
        (contract-call? MATH_CONTRACT sqrt base-power))
      (let ((base-power (try! (contract-call? MATH_CONTRACT pow-fixed TICK_BASE (to-uint (- tick))))))
        (let ((sqrt-result (try! (contract-call? MATH_CONTRACT sqrt base-power))))
          (ok (/ Q64 sqrt-result))))
    )
  )
)

;; Calculate tick from sqrt price using fixed-point arithmetic
(define-read-only (sqrt-price-to-tick (sqrt-price uint))
  (begin
    (asserts! (> sqrt-price u0) ERR_INVALID_SQRT_PRICE)
    (let ((price-squared (try! (contract-call? MATH_CONTRACT multiply sqrt-price sqrt-price)))
          (ratio (/ price-squared Q64))
          (log-sqrt (try! (contract-call? MATH_CONTRACT log2 ratio)))
          (log-tick-base (try! (contract-call? MATH_CONTRACT log2 TICK_BASE))))
      (ok (to-int (/ (* log-sqrt Q64) log-tick-base)))
    )
  )
)

;; Calculate liquidity amounts for given ticks
(define-read-only (get-liquidity-for-amounts 
    (sqrt-price-current uint) 
    (sqrt-price-lower uint) 
    (sqrt-price-upper uint) 
    (amount-x uint) 
    (amount-y uint))
  (begin
    (asserts! (< sqrt-price-lower sqrt-price-upper) ERR_INVALID_SQRT_PRICE)
    (let (
      (liquidity-x (if (<= sqrt-price-current sqrt-price-lower)
        u0
        (/ (* amount-x sqrt-price-current) (- sqrt-price-current sqrt-price-lower))
      ))
      (liquidity-y (if (>= sqrt-price-current sqrt-price-upper)
        u0
        (/ amount-y (- sqrt-price-upper sqrt-price-current))
      ))
    )
      (ok (if (< sqrt-price-current sqrt-price-upper)
        (if (< liquidity-x liquidity-y) liquidity-x liquidity-y)
        liquidity-x
      ))
    )
  )
)

;; Fee calculation
(define-read-only (calculate-fee (liquidity uint) (fee-rate uint) (time-in-seconds uint))
  (ok (/ (* (* liquidity fee-rate) time-in-seconds) u1000000))
)
