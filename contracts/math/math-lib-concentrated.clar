;; ===========================================
;; CONCENTRATED LIQUIDITY MATH LIBRARY
;; ===========================================
;;
;; Enhanced Math Library for Concentrated Liquidity
;; Provides advanced mathematical functions for tick calculations and price conversions
;; Supports high-precision calculations for DeFi applications
;;
;; VERSION: 2.0

;; ===========================================
;; CONSTANTS
;; ===========================================

;; Fixed-point constants
(define-constant Q96 u79228162514264337593543950336) ;; 2^96
(define-constant Q128 u340282366920938463463374607431768211455) ;; 2^128 - 1
(define-constant PRECISION u1000000000000000000) ;; 1e18

;; Tick range constants
(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)
(define-constant MIN_SQRT_RATIO u4295128739) ;; sqrt(0.000000000000000001)
(define-constant MAX_SQRT_RATIO u18446744073709551615) ;; Safe max value

;; Error constants
(define-constant ERR_INVALID_INPUT (err u4001))
(define-constant ERR_OVERFLOW (err u4002))
(define-constant ERR_TICK_OUT_OF_BOUNDS (err u4003))
(define-constant ERR_DIVISION_BY_ZERO (err u4004))

;; ===========================================
;; BASIC MATH FUNCTIONS
;; ===========================================

;; Safe multiplication and division
(define-read-only (mul-div (a uint) (b uint) (denominator uint))
  (asserts! (> denominator u0) ERR_DIVISION_BY_ZERO)
  (let ((result (* a b)))
    (asserts! (or (is-eq a u0) (is-eq (/ result a) b)) ERR_OVERFLOW)
    (ok (/ result denominator))))

;; Multiplication and division with rounding up
(define-read-only (mul-div-rounding-up (a uint) (b uint) (denominator uint))
  (asserts! (> denominator u0) ERR_DIVISION_BY_ZERO)
  (let ((result (* a b))
        (quotient (/ result denominator))
        (remainder (mod result denominator)))
    (ok (if (> remainder u0) (+ quotient u1) quotient))))

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

;; Absolute value for integers
(define-private (abs (x int))
  (if (< x 0) (- 0 x) x))

;; Minimum of two values
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Maximum of two values
(define-private (max (a uint) (b uint))
  (if (> a b) a b))

;; ===========================================
;; SQUARE ROOT FUNCTIONS (ITERATIVE)
;; ===========================================

(define-constant SQRT-ITERATIONS (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15))

(define-private (sqrt (n uint))
  (if (<= n 1)
    n
    (let (
      (initial (let ((candidate (>> n 1))) (if (> candidate u0) candidate u1)))
      (approx (fold SQRT-ITERATIONS initial
        (lambda (iteration guess)
          (let ((next (/ (+ guess (/ n guess)) u2)))
            (if (>= guess next)
              next
              guess)
          )
        )
      ))
    )
      approx
    )
  )
)

;; Helper for absolute difference
(define-private (abs-diff (a uint) (b uint))
  (if (>= a b) (- a b) (- b a)))

;; ===========================================
;; TICK AND PRICE CONVERSION FUNCTIONS
;; ===========================================

;; Calculate sqrt ratio at a given tick
(define-read-only (get-sqrt-ratio-at-tick (tick int))
  (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) ERR_TICK_OUT_OF_BOUNDS)
  
  ;; Simplified implementation using linear approximation
  (let ((tick-uint (to-uint (abs tick)))
        (base-ratio (/ Q96 u1000000))) ;; Base scaling factor
    (ok (if (>= tick 0)
      (+ Q96 (* base-ratio tick-uint))
      (if (> Q96 (* base-ratio tick-uint))
        (- Q96 (* base-ratio tick-uint))
        MIN_SQRT_RATIO)))))

;; Get tick for a given sqrt ratio
(define-read-only (get-tick-at-sqrt-ratio (sqrt-ratio uint))
  (asserts! (and (>= sqrt-ratio MIN_SQRT_RATIO) (<= sqrt-ratio MAX_SQRT_RATIO)) ERR_INVALID_INPUT)
  
  ;; Simplified reverse calculation
  (let ((base-ratio (/ Q96 u1000000)))
    (if (>= sqrt-ratio Q96)
      (let ((diff (- sqrt-ratio Q96)))
        (ok (to-int (/ diff base-ratio))))
      (let ((diff (- Q96 sqrt-ratio)))
        (ok (- 0 (to-int (/ diff base-ratio))))))))

;; Convert tick to price (token1/token0)
(define-read-only (tick-to-price (tick int))
  (match (get-sqrt-ratio-at-tick tick)
    sqrt-ratio (ok (/ (* sqrt-ratio sqrt-ratio) Q128))
    error error))

;; Convert price to nearest tick
(define-read-only (price-to-tick (price uint))
  (let ((sqrt-price-result (sqrt (* price Q128))))
    (match sqrt-price-result
      sqrt-price (get-tick-at-sqrt-ratio sqrt-price)
      error error)))

;; ===========================================
;; LIQUIDITY CALCULATION FUNCTIONS
;; ===========================================

;; Calculate amount0 delta for given price range and liquidity
(define-read-only (get-amount0-delta
  (sqrt-ratio-a uint)
  (sqrt-ratio-b uint)
  (liquidity uint)
  (round-up bool))
  
  (let ((sqrt-ratio-lower (min sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (max sqrt-ratio-a sqrt-ratio-b)))
    (if round-up
      (mul-div-rounding-up liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96)
      (mul-div liquidity (- sqrt-ratio-upper sqrt-ratio-lower) Q96))))

;; Calculate amount1 delta for given price range and liquidity
(define-read-only (get-amount1-delta
  (sqrt-ratio-a uint)
  (sqrt-ratio-b uint)
  (liquidity uint)
  (round-up bool))
  
  (let ((sqrt-ratio-lower (min sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (max sqrt-ratio-a sqrt-ratio-b)))
    (if round-up
      (mul-div-rounding-up liquidity Q96 (- sqrt-ratio-upper sqrt-ratio-lower))
      (mul-div liquidity Q96 (- sqrt-ratio-upper sqrt-ratio-lower)))))

;; ===========================================
;; SWAP CALCULATION FUNCTIONS
;; ===========================================

;; Calculate next sqrt price from input amount
(define-read-only (get-next-sqrt-price-from-input
  (sqrt-price-x96 uint)
  (liquidity uint)
  (amount-in uint)
  (zero-for-one bool))
  
  (asserts! (> liquidity u0) ERR_DIVISION_BY_ZERO)
  (asserts! (> sqrt-price-x96 u0) ERR_DIVISION_BY_ZERO)
  
  (let ((amount-in-with-fee (* amount-in u997))) ;; 0.3% fee (997/1000)
    (if zero-for-one
      ;; Swapping token0 for token1 (price decreases)
      (let ((numerator (* liquidity sqrt-price-x96))
            (denominator (+ (* liquidity u1000) amount-in-with-fee)))
        (ok (/ numerator denominator)))
      ;; Swapping token1 for token0 (price increases)
      (let ((delta-sqrt-price (/ amount-in-with-fee liquidity)))
        (ok (+ sqrt-price-x96 delta-sqrt-price))))))

;; Calculate next sqrt price from output amount
(define-read-only (get-next-sqrt-price-from-output
  (sqrt-price-x96 uint)
  (liquidity uint)
  (amount-out uint)
  (zero-for-one bool))
  
  (asserts! (> liquidity u0) ERR_DIVISION_BY_ZERO)
  (asserts! (> sqrt-price-x96 u0) ERR_DIVISION_BY_ZERO)
  
  (let ((amount-out-with-fee (* amount-out u1003))) ;; Add 0.3% fee
    (if zero-for-one
      ;; Swapping token0 for token1
      (let ((delta-sqrt-price (/ amount-out-with-fee liquidity)))
        (if (> sqrt-price-x96 delta-sqrt-price)
          (ok (- sqrt-price-x96 delta-sqrt-price))
          ERR_INVALID_INPUT))
      ;; Swapping token1 for token0
      (let ((delta-sqrt-price (/ amount-out-with-fee liquidity)))
        (ok (+ sqrt-price-x96 delta-sqrt-price))))))

;; ===========================================
;; FEE CALCULATION FUNCTIONS
;; ===========================================

;; Calculate fee growth inside a tick range
(define-read-only (get-fee-growth-inside
  (tick-lower int)
  (tick-upper int)
  (tick-current int)
  (fee-growth-global0 uint)
  (fee-growth-global1 uint))
  
  (let ((fee-below0 (unwrap! (get-fee-growth-below tick-lower fee-growth-global0 tick-current) ERR_INVALID_INPUT))
        (fee-below1 (unwrap! (get-fee-growth-below tick-lower fee-growth-global1 tick-current) ERR_INVALID_INPUT))
        (fee-above0 (unwrap! (get-fee-growth-above tick-upper fee-growth-global0 tick-current) ERR_INVALID_INPUT))
        (fee-above1 (unwrap! (get-fee-growth-above tick-upper fee-growth-global1 tick-current) ERR_INVALID_INPUT)))
    
    (ok {
      fee-growth-inside0: (- fee-growth-global0 (+ fee-below0 fee-above0)),
      fee-growth-inside1: (- fee-growth-global1 (+ fee-below1 fee-above1))
    })))

;; Get fee growth below a tick
(define-read-only (get-fee-growth-below (tick int) (fee-growth-global uint) (current-tick int))
  (let ((fee-growth-outside (get-fee-growth-outside tick)))
    (ok (if (>= tick current-tick)
      (- fee-growth-global fee-growth-outside)
      fee-growth-outside))))

;; Get fee growth above a tick
(define-read-only (get-fee-growth-above (tick int) (fee-growth-global uint) (current-tick int))
  (let ((fee-growth-outside (get-fee-growth-outside tick)))
    (ok (if (< tick current-tick)
      (- fee-growth-global fee-growth-outside)
      fee-growth-outside))))

;; ===========================================
;; HELPER FUNCTIONS
;; ===========================================

;; Get fee growth outside a tick (placeholder implementation)
(define-private (get-fee-growth-outside (tick int))
  u0) ;; In production, this would query tick data

;; Round tick to nearest valid tick spacing
(define-private (round-tick (tick int) (tick-spacing int))
  (* (/ tick tick-spacing) tick-spacing))

;; Get lower tick boundary
(define-private (get-lower-tick (tick int) (tick-spacing uint))
  (* (/ tick (to-int tick-spacing)) (to-int tick-spacing)))

;; Get upper tick boundary
(define-private (get-upper-tick (tick int) (tick-spacing uint))
  (* (+ (/ tick (to-int tick-spacing)) 1) (to-int tick-spacing)))

;; ===========================================
;; VALIDATION FUNCTIONS
;; ===========================================

;; Validate tick is within bounds
(define-read-only (is-valid-tick (tick int))
  (and (>= tick MIN_TICK) (<= tick MAX_TICK)))

;; Validate sqrt price is within bounds
(define-read-only (is-valid-sqrt-price (sqrt-price uint))
  (and (>= sqrt-price MIN_SQRT_RATIO) (<= sqrt-price MAX_SQRT_RATIO)))

;; Get constants for external use
(define-read-only (get-constants)
  {
    q96: Q96,
    q128: Q128,
    min-tick: MIN_TICK,
    max-tick: MAX_TICK,
    min-sqrt-ratio: MIN_SQRT_RATIO,
    max-sqrt-ratio: MAX_SQRT_RATIO
  })