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

;; Math functions
(define-read-only (mul-div (a uint) (b uint) (denominator uint))
  ;; Multiply a * b and divide by denominator with overflow protection
  (let ((result (* a b)))
    (asserts! (> denominator u0) ERR_INVALID_INPUT)
    (asserts! (>= result a) ERR_OVERFLOW) ;; Check for overflow
    (ok (/ result denominator))
  )
)

(define-read-only (mul-div-rounding-up (a uint) (b uint) (denominator uint))
  ;; Multiply a * b and divide by denominator, rounding up
  (let ((result (* a b)))
    (let ((quotient (/ result denominator)))
      (let ((remainder (- result (* quotient denominator))))
        (ok (if (> remainder u0) (+ quotient u1) quotient))
      )
    )
  )
)

;; get-sqrt-ratio-at-tick
;; Calculates the sqrt price at a given tick.
;; This function is critical for concentrated liquidity, determining the price boundaries of a position.
(define-read-only (get-sqrt-ratio-at-tick (tick int))
  (ok
    (let (
      (abs-tick (abs tick))
      (ratio-q96 (exp-fixed (* abs-tick (log-base-sqrt Q96))))
      )
      (if (>= tick u0)
        ratio-q96
        (/ Q96 ratio-q96)
      )
    )
  )
)

;; @desc Get the tick for a given sqrt-ratio
;; @param sqrt-ratio The sqrt-ratio to convert to a tick
;; @returns (response (int) (err uint))
(define-read-only (get-tick-at-sqrt-ratio (sqrt-ratio uint))
  (ok
    (if (<= sqrt-ratio MIN_SQRT_RATIO)
      MIN_TICK
      (if (>= sqrt-ratio MAX_SQRT_RATIO)
        MAX_TICK
        (begin
          (let
            (
              (ratio-q96 (div-u128 (mul-u128 sqrt-ratio sqrt-ratio) Q96))
              (log-ratio (log-base-sqrt ratio-q96))
            )
            (div-u128 log-ratio (log-base-sqrt Q96))
          )
        )
      )
    )
  )
)


(define-private (log-base-sqrt (ratio uint))
  ;; Calculate log base sqrt(1.0001) of ratio
  ;; This is a more precise implementation using an iterative approach
  (let
    (
      (result u0)
      (current-ratio Q96)
      (tick-spacing u60) ;; Assuming a tick spacing of 60 for now
    )
    (asserts! (> ratio u0) ERR_INVALID_INPUT)

    (if (>= ratio Q96)
      (begin
        (while (and (>= ratio current-ratio) (< result MAX_TICK))
          (begin
            (set current-ratio (mul-div-rounding-up current-ratio (pow u10001 u10000 tick-spacing) Q96))
            (set result (+ result tick-spacing))
          )
        )
        (set result (- result tick-spacing)) ;; Adjust for overshooting
      )
      (begin
        (while (and (< ratio current-ratio) (> result MIN_TICK))
          (begin
            (set current-ratio (mul-div-rounding-up current-ratio Q96 (pow u10001 u10000 tick-spacing)))
            (set result (- result tick-spacing))
          )
        )
      )
    )
    result
  )
)

(define-private (round-tick (tick int))
  ;; Round tick to nearest valid tick spacing
  (let ((rounded (/ tick 60)))
    (* rounded 60)
  )
)

(define-read-only (get-amount0-delta
  (sqrt-ratio-a uint)
  (sqrt-ratio-b uint)
  (liquidity uint)
  (round-up bool)
)
  ;; Calculate amount0 delta for given price range and liquidity
  (let ((sqrt-ratio-lower (min sqrt-ratio-a sqrt-ratio-b)))
    (let ((sqrt-ratio-upper (max sqrt-ratio-a sqrt-ratio-b)))
      (if round-up
          (mul-div-rounding-up liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96)
          (mul-div liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96)
      )
    )
  )
)

(define-read-only (get-amount1-delta
  (sqrt-ratio-a uint)
  (sqrt-ratio-b uint)
  (liquidity uint)
  (round-up bool)
)
  ;; Calculate amount1 delta for given price range and liquidity
  (let ((sqrt-ratio-lower (min sqrt-ratio-a sqrt-ratio-b)))
    (let ((sqrt-ratio-upper (max sqrt-ratio-a sqrt-ratio-b)))
      (if round-up
          (mul-div-rounding-up
            liquidity
            Q96
            (- sqrt-ratio-upper sqrt-ratio-lower)
          )
          (mul-div
            liquidity
            Q96
            (- sqrt-ratio-upper sqrt-ratio-lower)
          )
      )
    )
  )
)

(define-read-only (get-next-sqrt-price-from-input
  (sqrt-price-x96 uint)
  (liquidity uint)
  (amount-in uint)
  (zero-for-one bool)
)
  ;; Calculate next sqrt price after input amount
  (let ((sqrt-price (if zero-for-one sqrt-price-x96 (/ Q128 sqrt-price-x96))))
    (let ((amount-in-with-fee (* amount-in 997))) ;; 0.3% fee
      (let ((numerator (* amount-in-with-fee sqrt-price)))
        (let ((denominator (* amount-in-with-fee liquidity)))
          (let ((new-sqrt-price (+ sqrt-price (/ numerator (+ liquidity denominator)))))
            (if zero-for-one
                new-sqrt-price
                (/ Q128 new-sqrt-price)
            )
          )
        )
      )
    )
  )
)

(define-read-only (get-next-sqrt-price-from-output
  (sqrt-price-x96 uint)
  (liquidity uint)
  (amount-out uint)
  (zero-for-one bool)
)
  ;; Calculate next sqrt price after output amount
  (let ((sqrt-price (if zero-for-one sqrt-price-x96 (/ Q128 sqrt-price-x96))))
    (let ((amount-out-with-fee (* amount-out 1003))) ;; 0.3% fee
      (let ((new-sqrt-price (- sqrt-price (/ (* amount-out-with-fee sqrt-price) (- (* liquidity 1000) amount-out-with-fee)))))
        (if zero-for-one
            new-sqrt-price
            (/ Q128 new-sqrt-price)
        )
      )
    )
  )
)

;; Utility functions
(define-private (abs (x int))
  (if (< x 0) (- 0 x) x)
)

(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)

(define-private (pow (base uint) (exp uint))
  ;; Simplified power function
  (if (is-eq exp u0)
      u1
      (* base (pow base (- exp u1)))
  )
)

;; Advanced tick manipulation functions
(define-read-only (tick-to-price (tick int))
  ;; Convert tick to price (token1/token0)
  (let ((sqrt-ratio (get-sqrt-ratio-at-tick tick)))
    (/ (* sqrt-ratio sqrt-ratio) Q128)
  )
)

(define-read-only (price-to-tick (price uint))
  ;; Convert price to nearest tick
  (let ((sqrt-price (* (sqrt price) Q64)))
    (get-tick-at-sqrt-ratio sqrt-price)
  )
)

(define-read-only (get-fee-growth-inside
  (tick-lower int)
  (tick-upper int)
  (tick-current int)
  (fee-growth-global0 uint)
  (fee-growth-global1 uint)
)
  ;; Calculate fee growth inside tick range
  (let ((fee-growth-below0 (get-fee-growth-below tick-lower fee-growth-global0)))
    (let ((fee-growth-below1 (get-fee-growth-below tick-lower fee-growth-global1)))
      (let ((fee-growth-above0 (get-fee-growth-above tick-upper fee-growth-global0)))
        (let ((fee-growth-above1 (get-fee-growth-above tick-upper fee-growth-global1)))

          (tuple
            (fee-growth-inside0 (- fee-growth-global0 (+ fee-growth-below0 fee-growth-above0)))
            (fee-growth-inside1 (- fee-growth-global1 (+ fee-growth-below1 fee-growth-above1)))
          )
        )
      )
    )
  )
)

;; Helper functions for fee growth calculations
(define-private (get-lower-tick (tick int) (tick-spacing uint))
    (* (div tick (to-int tick-spacing)) (to-int tick-spacing))
)

(define-private (get-upper-tick (tick int) (tick-spacing uint))
    (* (+ (div tick (to-int tick-spacing)) u1) (to-int tick-spacing))
)

(define-private (get-fee-growth-outside (tick int))
    ;; Placeholder for actual implementation to retrieve fee growth outside a tick
    ;; This would typically involve reading from a map in the concentrated liquidity pool contract
    u0
)

(define-private (get-current-tick)
    ;; Placeholder for actual implementation to retrieve the current tick
    ;; This would typically involve reading from the concentrated liquidity pool contract
    u0
)

;; @desc Get the fee growth below a tick
;; @param tick The tick to calculate fee growth below
;; @param fee-growth-global The global fee growth
;; @param tick-spacing The tick spacing
;; @returns (uint) The fee growth below the tick
(define-read-only (get-fee-growth-below (tick int) (fee-growth-global uint) (tick-spacing uint))
    (let (
            (lower-tick (get-lower-tick tick tick-spacing))
            (fee-growth-outside (get-fee-growth-outside lower-tick))
        )
        (if (>= tick (get-current-tick))
            (- fee-growth-global fee-growth-outside)
            fee-growth-outside
        )
    )
)

;; @desc Get the fee growth above a tick
;; @param tick The tick to calculate fee growth above
;; @param fee-growth-global The global fee growth
;; @param tick-spacing The tick spacing
;; @returns (uint) The fee growth above the tick
(define-read-only (get-fee-growth-above (tick int) (fee-growth-global uint) (tick-spacing uint))
    (let (
            (upper-tick (get-upper-tick tick tick-spacing))
            (fee-growth-outside (get-fee-growth-outside upper-tick))
        )
        (if (< tick (get-current-tick))
            (- fee-growth-global fee-growth-outside)
            fee-growth-outside
        )
    )
)

;; Export functions for external contracts
;; @desc Calculates the square root of a fixed-point number (u128) using an iterative approach.
;; @param x The fixed-point number to calculate the square root of.
;; @returns (ok u128) The square root of x, or (err u128) if x is negative.
(define-public (sqrt-fixed (x uint)) 
  (ok
    (if (is-eq x u0)
      u0
      (begin
        (var (z uint) u0)
        (var (y uint) (div (+ x u1) u2))
        (while (and (not (is-eq (var-get y) u0)) (< (var-get y) (var-get z)))
          (begin
            (var-set z (var-get y))
            (var-set y (div (+ (div x (var-get y)) (var-get y)) u2))
          )
        )
        (var-get z)
      )
    )
  )
)

;; @desc Calculates the exponential of a fixed-point number (e^x) using a Taylor series approximation.
;; @param x The fixed-point number to calculate the exponential of.
;; @returns (ok u128) The exponential of x.
(define-public (exp-fixed (x uint))
  (ok
    (begin
      (var (result uint) Q96)
      (var (term uint) Q96)
      (var (i uint) u1)
      (while (not (is-eq (var-get term) u0))
        (begin
          (var-set term (div (mul (var-get term) x) (var-get i)))
          (var-set result (+ (var-get result) (var-get term)))
          (var-set i (+ (var-get i) u1))
        )
      )
      (var-get result)
    )
  )
)

