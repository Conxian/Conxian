;; Math utilities for concentrated liquidity

(define-constant Q64 u18446744073709551616)  ;; 2^64
(define-constant MAX_TICK 776363)  ;; Corresponds to sqrt(2^128)
(define-constant MIN_TICK (- MAX_TICK))

;; Calculate sqrt price from tick
(define-read-only (tick-to-sqrt-price (tick int))
  (if (>= tick 0)
    (pow (to-uint (pow 1.0001 (to-int tick))) 0.5)
    (pow (to-uint (pow 1.0001 (to-int (- tick)))) -0.5)
  ))

;; Calculate tick from sqrt price
(define-read-only (sqrt-price-to-tick (sqrt-price uint))
  (let (
      (log-sqrt (log2 (div (* sqrt-price sqrt-price) Q64)))
    )
    (to-int (div log-sqrt (log2 1.0001)))
  ))

;; Calculate liquidity amounts for given ticks
(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (amount-x uint) (amount-y uint))
  (let (
      (liquidity-x (if (<= sqrt-price-current sqrt-price-lower)
        u0
        (div amount-x (sub (sqrt-price-current) sqrt-price-lower))
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




