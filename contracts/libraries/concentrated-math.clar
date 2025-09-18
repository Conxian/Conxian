;; Math utilities for concentrated liquidity
;; Uses fixed-point arithmetic with Q64 precision

(define-constant Q64 u18446744073709551616)  ;; 2^64
(define-constant MAX_TICK 776363)  ;; Corresponds to sqrt(2^128)
(define-constant MIN_TICK (- MAX_TICK))
(define-constant TICK_BASE u10000)  ;; 1.0001 in fixed-point with 4 decimals

;; Calculate sqrt price from tick using fixed-point arithmetic
(define-read-only (tick-to-sqrt-price (tick int))
  (if (>= tick 0)
    (sqrt (pow TICK_BASE (to-uint tick)))
    (div Q64 (sqrt (pow TICK_BASE (to-uint (- tick)))))
  ))

;; Calculate tick from sqrt price using fixed-point arithmetic
(define-read-only (sqrt-price-to-tick (sqrt-price uint))
  (let (
      (log-sqrt (log2 (div (* sqrt-price sqrt-price) Q64)))
      (log-tick-base (log2 TICK_BASE))
    )
    (to-int (div (* log-sqrt Q64) log-tick-base))
  ))

;; Calculate liquidity amounts for given ticks
(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (amount-x uint) (amount-y uint))
  (let (
      (liquidity-x (if (<= sqrt-price-current sqrt-price-lower)
        u0
        (div (mul amount-x sqrt-price-current) (sub sqrt-price-current sqrt-price-lower))
      ))
      (liquidity-y (if (>= sqrt-price-current sqrt-price-upper)
        u0
        (div amount-y (sub sqrt-price-upper sqrt-price-current))
      ))
    )
    (if (< sqrt-price-current sqrt-price-upper)
      (min liquidity-x liquidity-y)
      liquidity-x
    )
  ))

;; Fee calculation
(define-read-only (calculate-fee (liquidity uint) (fee-rate uint) (time-in-seconds uint))
  (div (* liquidity fee-rate time-in-seconds) u1000000)
)





