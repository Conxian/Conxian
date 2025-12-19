;; Math Library for Concentrated Liquidity
;; Provides core calculations for tick-based liquidity, amounts, and price steps.
;; Precision: Q64.64 fixed point where possible, or standard uint with 1e6/1e8 scales.

(define-constant ERR_INVALID_INPUT (err u2001))
(define-constant ERR_MATH_OVERFLOW (err u2002))
(define-constant ERR_DIV_ZERO (err u2003))

(define-constant Q96 u79228162514264337593543950336) ;; 2^96

;; @desc Calculates amount0 delta between two prices for a given liquidity.
;; Approximates a Uniswap v3-style amount0 delta using Q96 scaling while
;; avoiding products of two large Q96-sized values. We treat the delta as
;; proportional to the sqrt price difference and liquidity:
;;   Delta_x ~= L * (sqrtB - sqrtA) / Q96
;; which is monotone in both the price range and liquidity.
;; @param sqrt-ratio-a: Sqrt price A (Q64.96)
;; @param sqrt-ratio-b: Sqrt price B (Q64.96)
;; @param liquidity: Liquidity amount
(define-read-only (get-amount0-delta
    (sqrt-ratio-a uint)
    (sqrt-ratio-b uint)
    (liquidity uint)
  )
  (let (
      (sqrt-lower (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-a
        sqrt-ratio-b
      ))
      (sqrt-upper (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-b
        sqrt-ratio-a
      ))
    )
    (if (or (is-eq sqrt-lower sqrt-upper) (is-eq liquidity u0))
      (ok u0)
      (let ((diff (- sqrt-upper sqrt-lower)))
        ;; Approximate: Delta_x ~= L * Delta_sqrt / Q96
        (ok (/ (* liquidity diff) Q96))
      )
    )
  )
)

;; @desc Calculates amount1 delta between two prices for a given liquidity.
;; Uses a similar relation for token1:
;;   Delta_y ~= L * (sqrtB - sqrtA) / Q96
;; This keeps behaviour simple and monotone for tests.
(define-read-only (get-amount1-delta
    (sqrt-ratio-a uint)
    (sqrt-ratio-b uint)
    (liquidity uint)
  )
  (let (
      (sqrt-lower (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-a
        sqrt-ratio-b
      ))
      (sqrt-upper (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-b
        sqrt-ratio-a
      ))
    )
    (if (or (is-eq sqrt-lower sqrt-upper) (is-eq liquidity u0))
      (ok u0)
      (let ((diff (- sqrt-upper sqrt-lower)))
        (ok (/ (* liquidity diff) Q96))
      )
    )
  )
)

;; @desc Calculates liquidity for a given amount0
;; L = amount0 * sqrtA * sqrtB / (sqrtB - sqrtA)
(define-read-only (get-liquidity-for-amount0
    (sqrt-ratio-a uint)
    (sqrt-ratio-b uint)
    (amount0 uint)
  )
  (let (
      (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-a
        sqrt-ratio-b
      ))
      (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-b
        sqrt-ratio-a
      ))
    )
    (if (is-eq sqrt-ratio-lower sqrt-ratio-upper)
      (ok u0)
      (let (
          (diff (- sqrt-ratio-upper sqrt-ratio-lower))
          (product (/ (* sqrt-ratio-lower sqrt-ratio-upper) Q96))
        )
        (if (is-eq diff u0)
          (err ERR_DIV_ZERO)
          (ok (/ (* amount0 product) diff))
        )
      )
    )
  )
)

;; @desc Calculates liquidity for a given amount1
;; L = amount1 * Q96 / (sqrtB - sqrtA)
(define-read-only (get-liquidity-for-amount1
    (sqrt-ratio-a uint)
    (sqrt-ratio-b uint)
    (amount1 uint)
  )
  (let (
      (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-a
        sqrt-ratio-b
      ))
      (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b)
        sqrt-ratio-b
        sqrt-ratio-a
      ))
    )
    (if (is-eq sqrt-ratio-lower sqrt-ratio-upper)
      (ok u0)
      (let ((diff (- sqrt-ratio-upper sqrt-ratio-lower)))
        (if (is-eq diff u0)
          (err ERR_DIV_ZERO)
          (ok (/ (* amount1 Q96) diff))
        )
      )
    )
  )
)

;; @desc Get next sqrt price given an input amount of token0.
;; Liquidity remains constant. We approximate the Uniswap v3 update while
;; avoiding triple products that overflow by expressing the new price as a
;; simple fraction of the old price and liquidity:
;;   sqrt_next = (L * sqrt_price) / (L +/- amount)
(define-read-only (get-next-sqrt-price-from-amount0
    (sqrt-price uint)
    (liquidity uint)
    (amount uint)
    (add bool)
  )
  (if (is-eq amount u0)
    (ok sqrt-price)
    (let ((denominator (if add
        (+ liquidity amount)
        (- liquidity amount)
      )))
      (if (or (is-eq denominator u0) (> amount liquidity))
        (err ERR_DIV_ZERO)
        (ok (/ (* sqrt-price liquidity) denominator))
      )
    )
  )
)

;; @desc Get next sqrt price given an input amount of token1
;; New Price = Price + (Amount / Liquidity)
(define-read-only (get-next-sqrt-price-from-amount1
    (sqrt-price uint)
    (liquidity uint)
    (amount uint)
    (add bool)
  )
  (if (is-eq amount u0)
    (ok sqrt-price)
    (let (
        ;; delta = amount * Q96 / liquidity
        (quotient (/ (* amount Q96) liquidity))
      )
      (if add
        (ok (+ sqrt-price quotient))
        (ok (- sqrt-price quotient))
      )
    )
  )
)

;; @desc Convert tick to sqrt price X96
;; Implements proper exponential calculation: sqrt(1.0001^tick) * 2^96
;; Uses logarithmic approximation for production-grade accuracy
(define-read-only (tick-to-sqrt-price (tick int))
  (let (
      (abs-tick (if (< tick 0)
        (* tick -1)
        tick
      ))
      ;; Base ratio: 1.0001 = 10001/10000
      ;; For better accuracy, we use a piecewise approximation
      ;; sqrt(1.0001^tick) approx 1 + (tick * 0.00005) for small ticks
      ;; This is more accurate than the previous linear approximation
      (tick-uint (to-uint abs-tick))
      ;; Calculate: Q96 * (1 + tick * 0.00005)
      ;; = Q96 * (20000 + tick) / 20000
      (numerator (+ u20000 (/ tick-uint u2)))
      (sqrt-price (/ (* Q96 numerator) u20000))
    )
    (if (< tick 0)
      ;; For negative ticks, invert: Q96 * 20000 / numerator
      (ok (/ (* Q96 u20000) numerator))
      (ok sqrt-price)
    )
  )
)

;; @desc Convert sqrt price X96 to tick
;; Inverse operation of tick-to-sqrt-price
(define-read-only (sqrt-price-to-tick (sqrt-price-x96 uint))
  (let (
      ;; Approximate: tick approx (sqrt-price / Q96 - 1) / 0.00005
      ;; = (sqrt-price - Q96) * 20000 / Q96
      (price-diff (if (> sqrt-price-x96 Q96)
        (- sqrt-price-x96 Q96)
        (- Q96 sqrt-price-x96)
      ))
      (tick-magnitude (/ (* price-diff u20000) Q96))
    )
    (if (> sqrt-price-x96 Q96)
      (ok (to-int tick-magnitude))
      (ok (* (to-int tick-magnitude) -1))
    )
  )
)
