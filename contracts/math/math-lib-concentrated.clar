;; Enhanced Math Library for Concentrated Liquidity
;; Provides advanced mathematical functions for tick calculations and price conversions
;; Supports high-precision calculations for DeFi applications

;; Constants - using valid uint values instead of hex buffers
(define-constant Q96 u79228162514264337593543950336) ;; 2^96 as uint
(define-constant Q128 u340282366920938463463374607431768211455) ;; 2^128 - 1 as uint
(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)
(define-constant MIN_SQRT_RATIO u4295128739) ;; sqrt(0.000000000000000001)
(define-constant MAX_SQRT_RATIO u18446744073709551615) ;; sqrt(2^128 - 1) - 1, approximately 2^64 - 1

;; Error constants
(define-constant ERR_INVALID_INPUT (err u4001))
(define-constant ERR_OVERFLOW (err u4002))
(define-constant ERR_TICK_OUT_OF_BOUNDS (err u4003))
(define-constant ERR_DIVISION_BY_ZERO (err u4004))

;; Math functions
(define-read-only (mul-div (a uint) (b uint) (denominator uint))
  ;; Multiply a * b and divide by denominator with overflow protection
  (let ((result (* a b)))
    (asserts! (> denominator u0) ERR_DIVISION_BY_ZERO)
    (asserts! (or (is-eq a u0) (is-eq (/ result a) b)) ERR_OVERFLOW)
    (ok (/ result denominator))))

(define-read-only (mul-div-rounding-up (a uint) (b uint) (denominator uint))
  ;; Multiply a * b and divide by denominator, rounding up
  (asserts! (> denominator u0) ERR_DIVISION_BY_ZERO)
  (let ((result (* a b)))
    (let ((quotient (/ result denominator))
          (remainder (mod result denominator)))
      (ok (if (> remainder u0) (+ quotient u1) quotient)))))

;; get-sqrt-ratio-at-tick
;; Calculates the sqrt price at a given tick.
;; This function is critical for concentrated liquidity, determining the price boundaries of a position.
(define-read-only (get-sqrt-ratio-at-tick (tick int))
  (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) ERR_TICK_OUT_OF_BOUNDS)
  ;; Simplified implementation: linear approximation for demonstration
  (let ((tick-uint (to-uint (abs tick)))
        (base-ratio (/ Q96 u1000)))
    (ok (if (>= tick 0)
      (+ Q96 (* base-ratio tick-uint))
      (- Q96 (* base-ratio tick-uint))))))

;; @desc Get the tick for a given sqrt-ratio
;; @param sqrt-ratio The sqrt-ratio to convert to a tick
;; @returns (response int uint)
(define-read-only (get-tick-at-sqrt-ratio (sqrt-ratio uint))
  (asserts! (and (>= sqrt-ratio MIN_SQRT_RATIO) (<= sqrt-ratio MAX_SQRT_RATIO)) ERR_INVALID_INPUT)
  ;; Simplified implementation: reverse linear approximation
  (let ((diff (if (>= sqrt-ratio Q96)
                (- sqrt-ratio Q96)
                (- Q96 sqrt-ratio)))
        (base-ratio (/ Q96 u1000))
        (tick-magnitude (/ diff base-ratio)))
    (ok (if (>= sqrt-ratio Q96)
      (to-int tick-magnitude)
      (- 0 (to-int tick-magnitude))))))

(define-private (round-tick (tick int) (tick-spacing int))
  ;; Round tick to nearest valid tick spacing
  (let ((rounded (/ tick tick-spacing)))
    (* rounded tick-spacing)))

(define-read-only (get-amount0-delta
  (sqrt-ratio-a uint)
  (sqrt-ratio-b uint)
  (liquidity uint)
  (round-up bool))
  ;; Calculate amount0 delta for given price range and liquidity
  (let ((sqrt-ratio-lower (min sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (max sqrt-ratio-a sqrt-ratio-b)))
    (if round-up
      (mul-div-rounding-up liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96)
      (mul-div liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96))))

(define-read-only (get-amount1-delta
  (sqrt-ratio-a uint)
  (sqrt-ratio-b uint)
  (liquidity uint)
  (round-up bool))
  ;; Calculate amount1 delta for given price range and liquidity
  (let ((sqrt-ratio-lower (min sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (max sqrt-ratio-a sqrt-ratio-b)))
    (if round-up
      (mul-div-rounding-up liquidity Q96 (- sqrt-ratio-upper sqrt-ratio-lower))
      (mul-div liquidity Q96 (- sqrt-ratio-upper sqrt-ratio-lower)))))

(define-read-only (get-next-sqrt-price-from-input
  (sqrt-price-x96 uint)
  (liquidity uint)
  (amount-in uint)
  (zero-for-one bool))
  ;; Calculate next sqrt price after input amount
  (let ((amount-in-with-fee (* amount-in u997)) ;; 0.3% fee
        (numerator (* amount-in-with-fee sqrt-price-x96))
        (denominator (+ (* liquidity u1000) amount-in-with-fee)))
    (ok (if zero-for-one
      (- sqrt-price-x96 (/ numerator denominator))
      (+ sqrt-price-x96 (/ numerator denominator))))))

(define-read-only (get-next-sqrt-price-from-output
  (sqrt-price-x96 uint)
  (liquidity uint)
  (amount-out uint)
  (zero-for-one bool))
  ;; Calculate next sqrt price after output amount
  (let ((amount-out-with-fee (* amount-out u1003)) ;; 0.3% fee
        (numerator (* amount-out-with-fee sqrt-price-x96))
        (denominator (- (* liquidity u1000) amount-out-with-fee)))
    (asserts! (> denominator u0) ERR_INVALID_INPUT)
    (ok (if zero-for-one
      (- sqrt-price-x96 (/ numerator denominator))
      (+ sqrt-price-x96 (/ numerator denominator))))))

;; Utility functions
(define-private (abs (x int))
  (if (< x 0) (- 0 x) x))

(define-private (min (a uint) (b uint))
  (if (< a b) a b))

(define-private (max (a uint) (b uint))
  (if (> a b) a b))

;; Advanced tick manipulation functions
(define-read-only (tick-to-price (tick int))
  ;; Convert tick to price (token1/token0)
  (match (get-sqrt-ratio-at-tick tick)
    success (ok (/ (* success success) Q128))
    error (err error)))

(define-read-only (price-to-tick (price uint))
  ;; Convert price to nearest tick - simplified implementation
  (let ((sqrt-price (sqrt-approx (* price Q128))))
    (get-tick-at-sqrt-ratio sqrt-price)))

(define-private (sqrt-approx (x uint))
  ;; Babylonian method for square root approximation
  (if (is-eq x u0)
    u0
    (let ((z (/ (+ x u1) u2)))
      (let ((y x))
        (if (< z y)
          (sqrt-iter z x u10)
          y)))))

(define-private (sqrt-iter (z uint) (x uint) (iterations uint))
  (if (is-eq iterations u0)
    z
    (let ((new-z (/ (+ z (/ x z)) u2)))
      (if (< new-z z)
        (sqrt-iter new-z x (- iterations u1))
        z))))

;; @desc Calculate the fee growth inside a tick range
;; @param tick-lower Lower tick boundary
;; @param tick-upper Upper tick boundary
;; @param tick-current Current tick
;; @param fee-growth-global0 Global fee growth for token0
;; @param fee-growth-global1 Global fee growth for token1
;; @returns (response (tuple (fee-growth-inside0 uint) (fee-growth-inside1 uint)) uint)
(define-read-only (get-fee-growth-inside
  (tick-lower int)
  (tick-upper int)
  (tick-current int)
  (fee-growth-global0 uint)
  (fee-growth-global1 uint))
  (match (get-fee-growth-below tick-lower fee-growth-global0 tick-current)
    fee-below0 (match (get-fee-growth-below tick-lower fee-growth-global1 tick-current)
      fee-below1 (match (get-fee-growth-above tick-upper fee-growth-global0 tick-current)
        fee-above0 (match (get-fee-growth-above tick-upper fee-growth-global1 tick-current)
          fee-above1 (ok (tuple
            (fee-growth-inside0 (- fee-growth-global0 (+ fee-below0 fee-above0)))
            (fee-growth-inside1 (- fee-growth-global1 (+ fee-below1 fee-above1)))))
          error1 (err error1))
        error0 (err error0))
      error-below1 (err error-below1))
    error-below0 (err error-below0)))

;; Helper functions for fee growth calculations
(define-private (get-lower-tick (tick int) (tick-spacing uint))
  (* (/ tick (to-int tick-spacing)) (to-int tick-spacing)))

(define-private (get-upper-tick (tick int) (tick-spacing uint))
  (* (+ (/ tick (to-int tick-spacing)) 1) (to-int tick-spacing)))

(define-private (get-fee-growth-outside (tick int))
  ;; Placeholder for actual implementation to retrieve fee growth outside a tick
  u0)

(define-private (get-current-tick)
  ;; Placeholder for actual implementation to retrieve the current tick
  i0)

(define-read-only (get-fee-growth-below (tick int) (fee-growth-global uint) (current-tick int))
  (let ((lower-tick (get-lower-tick tick u60))
        (fee-growth-outside (get-fee-growth-outside lower-tick)))
    (ok (if (>= tick current-tick)
      (- fee-growth-global fee-growth-outside)
      fee-growth-outside))))

(define-read-only (get-fee-growth-above (tick int) (fee-growth-global uint) (current-tick int))
  (let ((upper-tick (get-upper-tick tick u60))
        (fee-growth-outside (get-fee-growth-outside upper-tick)))
    (ok (if (< tick current-tick)
      (- fee-growth-global fee-growth-outside)
      fee-growth-outside))))