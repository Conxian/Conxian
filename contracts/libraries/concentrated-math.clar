;; @desc Math utilities for concentrated liquidity.
;; This library provides functions for calculating square root prices from ticks and vice versa,
;; as well as calculating liquidity amounts for given price ranges.

;; @uses .math-lib-advanced

;; @constants
;; @var Q64: 2^64, used for fixed-point arithmetic.
(define-constant Q64 u18446744073709551616)
;; @var MAX_TICK: Corresponds to sqrt(2^128).
(define-constant MAX_TICK 776363)
;; @var MIN_TICK: The minimum tick value.
(define-constant MIN_TICK (- MAX_TICK))
;; @var TICK_BASE: 1.0001 in fixed-point with 4 decimals.
(define-constant TICK_BASE u10000)
;; @var MATH_CONTRACT: The contract for the math library.
(define-constant MATH_CONTRACT .math-lib-advanced)

;; @errors
;; @var ERR_INVALID_TICK: The provided tick is invalid.
(define-constant ERR_INVALID_TICK (err u2001))
;; @var ERR_INVALID_SQRT_PRICE: The provided square root price is invalid.
(define-constant ERR_INVALID_SQRT_PRICE (err u2002))
;; @var ERR_MATH_OVERFLOW: A math overflow occurred.
(define-constant ERR_MATH_OVERFLOW (err u2003))

;; @desc Calculate the square root price from a tick using fixed-point arithmetic.
;; @param tick: The tick to convert.
;; @returns (response uint uint): The square root price, or an error code.
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

;; @desc Calculate the tick from a square root price using fixed-point arithmetic.
;; @param sqrt-price: The square root price to convert.
;; @returns (response int uint): The tick, or an error code.
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

;; @desc Calculate the liquidity for given amounts and price ranges.
;; @param sqrt-price-current: The current square root price.
;; @param sqrt-price-lower: The lower bound of the price range.
;; @param sqrt-price-upper: The upper bound of the price range.
;; @param amount-x: The amount of token X.
;; @param amount-y: The amount of token Y.
;; @returns (response uint uint): The liquidity, or an error code.
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

;; @desc Calculate the fee.
;; @param liquidity: The liquidity.
;; @param fee-rate: The fee rate.
;; @param time-in-seconds: The time in seconds.
;; @returns (response uint uint): The fee, or an error code.
(define-read-only (calculate-fee (liquidity uint) (fee-rate uint) (time-in-seconds uint))
  (ok (/ (* (* liquidity fee-rate) time-in-seconds) u1000000))
)
