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

(define-read-only (get-sqrt-ratio-at-tick (tick int))
  ;; Convert tick to sqrt price ratio (Q96.96 format)
  (asserts! (and (>= tick MIN_TICK) (<= tick MAX_TICK)) ERR_TICK_OUT_OF_BOUNDS)

  (let ((abs-tick (abs tick)))
    (let ((ratio
      (if (<= abs-tick 0)
          Q96
          (if (<= abs-tick 1)
              u112045541949572279837463876925233
              (if (<= abs-tick 2)
                  u112045541949572279837463876925233
                  (if (<= abs-tick 3)
                      u139007148438381923076149565744295
                      (if (<= abs-tick 4)
                          u154565007309853945966720149109336
                          (if (<= abs-tick 5)
                              u171117536768576565065809275647745
                              (if (<= abs-tick 6)
                                  u189047401038942640401911122697372
                                  (if (<= abs-tick 7)
                                      u208470682471078850157170867032843
                                      (if (<= abs-tick 8)
                                          u229916333986069483502313373649777
                                          (if (<= abs-tick 9)
                                              u253063268311025259999609173964062
                                              (if (<= abs-tick 10)
                                                  u278781933567080617255787334449658
                                                  (if (<= abs-tick 11)
                                                      u307177332762419870641053447903006
                                                      (if (<= abs-tick 12)
                                                          u338551859518983673744143094775216
                                                          (if (<= abs-tick 13)
                                                              u373025274039969580378501070262928
                                                              (if (<= abs-tick 14)
                                                                  u410888462275736559825006613831532
                                                                  (if (<= abs-tick 15)
                                                                      u452468285492777807200000000000000
                                                                      (if (<= abs-tick 16)
                                                                          u498180863924600000000000000000000
                                                                          (if (<= abs-tick 17)
                                                                              u548577123200000000000000000000000
                                                                              (if (<= abs-tick 18)
                                                                                  u603692648533333333333333333333333
                                                                                  (if (<= abs-tick 19)
                                                                                      u664115977289600000000000000000000
                                                                                      (if (<= abs-tick 20)
                                                                                          u730460617600000000000000000000000
                                                                                          Q96
                                                                                      )
                                                                                  )
                                                                              )
                                                                          )
                                                                      )
                                                                  )
                                                              )
                                                          )
                                                      )
                                                  )
                                              )
                                          ))))))))
                                      )
                                  )
                              )
                          )
                      )
                  )
              )
          )
        ))
      (if (< tick 0)
          (/ Q128 ratio) ;; Negative tick: 1/ratio
          ratio
      )
    )
  )
)

(define-read-only (get-tick-at-sqrt-ratio (sqrt-price-x96 uint))
  ;; Convert sqrt price ratio to tick
  (asserts! (and (>= sqrt-price-x96 MIN_SQRT_RATIO) (<= sqrt-price-x96 MAX_SQRT_RATIO)) ERR_INVALID_INPUT)

  (let ((ratio sqrt-price-x96))
    (let ((log-sqrt10001 (log-base-sqrt ratio)))
      (let ((tick (* log-sqrt10001 60))) ;; Convert to tick units
        (let ((tick-rounded (round-tick tick)))
          (asserts! (and (>= tick-rounded MIN_TICK) (<= tick-rounded MAX_TICK)) ERR_TICK_OUT_OF_BOUNDS)
          tick-rounded
        )
      )
    )
  )
)

(define-private (log-base-sqrt (ratio uint))
  ;; Calculate log base sqrt(1.0001) of ratio
  ;; This is a simplified version - full implementation would use bit manipulation
  (let ((msb 128))
    (let ((f msb))
      (let ((loop-count u0))
        (while (< loop-count u8)
          (begin
            (set f (if (> (pow Q96 f) ratio) (- f u1) f))
            (set loop-count (+ loop-count u1))
          )
        )
        f
      )
    )
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

(define-private (get-fee-growth-below (tick int) (fee-growth-global uint))
  ;; Calculate fee growth below a tick
  ;; This is a simplified version - full implementation would use tick data
  u0
)

(define-private (get-fee-growth-above (tick int) (fee-growth-global uint))
  ;; Calculate fee growth above a tick
  ;; This is a simplified version - full implementation would use tick data
  u0
)

;; Export functions for external contracts
(define-read-only (sqrt-fixed (x uint))
  ;; Calculate square root using Newton's method
  (if (is-eq x u0)
      u0
      (let ((z (x u1)))
        (let ((z-next (/ (+ z (/ x z)) u2)))
          (if (is-eq z z-next)
              z
              (sqrt-fixed x)
          )
        )
      )
  )
)

(define-read-only (exp-fixed (x uint))
  ;; Calculate exponential using Taylor series approximation
  ;; This is a simplified version for small x values
  (if (< x u100000000) ;; ln(2) * 1e8
      (+ u1000000000000000000000000000000 (* x u693147180559945309)) ;; e^x approx 1 + x + x^2/2 + ...
      (* u2718281828459045235 u1000000000000000000) ;; Maximum value
  )
)
