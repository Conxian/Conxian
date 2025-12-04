;; Math Library for Concentrated Liquidity
;; Provides core calculations for tick-based liquidity, amounts, and price steps.
;; Precision: Q64.64 fixed point where possible, or standard uint with 1e6/1e8 scales.

(define-constant ERR_INVALID_INPUT (err u2001))
(define-constant ERR_MATH_OVERFLOW (err u2002))
(define-constant ERR_DIV_ZERO (err u2003))

(define-constant Q96 u79228162514264337593543950336) ;; 2^96

;; @desc Calculates amount0 delta between two prices for a given liquidity
;; amount0 = liquidity * (1/sqrtA - 1/sqrtB)
;; @param sqrt-ratio-a: Sqrt price A (Q64.96)
;; @param sqrt-ratio-b: Sqrt price B (Q64.96)
;; @param liquidity: Liquidity amount
(define-read-only (get-amount0-delta (sqrt-ratio-a uint) (sqrt-ratio-b uint) (liquidity uint))
    (let (
        (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-b sqrt-ratio-a))
    )
        (if (is-eq sqrt-ratio-lower u0)
            (err ERR_DIV_ZERO)
            (let (
                ;; numerator = liquidity * (upper - lower)
                ;; denominator = lower * upper
                ;; We need to handle precision carefully.
                ;; Standard UniV3: amount0 = L * (sqrtB - sqrtA) / (sqrtA * sqrtB)
                (numerator (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower)))
                ;; Ideally we use mul-div here. For now, simplified:
                (denominator (/ (* sqrt-ratio-lower sqrt-ratio-upper) Q96))
            )
               (if (is-eq denominator u0)
                   (err ERR_DIV_ZERO)
                   (ok (/ numerator denominator))
               )
            )
        )
    )
)

;; @desc Calculates amount1 delta between two prices for a given liquidity
;; amount1 = liquidity * (sqrtB - sqrtA)
(define-read-only (get-amount1-delta (sqrt-ratio-a uint) (sqrt-ratio-b uint) (liquidity uint))
    (let (
        (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-b sqrt-ratio-a))
    )
        ;; amount1 = liquidity * (upper - lower) / Q96
        (ok (/ (* liquidity (- sqrt-ratio-upper sqrt-ratio-lower)) Q96))
    )
)

;; @desc Calculates liquidity for a given amount0
;; L = amount0 * sqrtA * sqrtB / (sqrtB - sqrtA)
(define-read-only (get-liquidity-for-amount0 (sqrt-ratio-a uint) (sqrt-ratio-b uint) (amount0 uint))
    (let (
        (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-b sqrt-ratio-a))
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
(define-read-only (get-liquidity-for-amount1 (sqrt-ratio-a uint) (sqrt-ratio-b uint) (amount1 uint))
    (let (
        (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-b sqrt-ratio-a))
    )
        (if (is-eq sqrt-ratio-lower sqrt-ratio-upper)
            (ok u0)
            (let (
                (diff (- sqrt-ratio-upper sqrt-ratio-lower))
            )
                (if (is-eq diff u0)
                    (err ERR_DIV_ZERO)
                    (ok (/ (* amount1 Q96) diff))
                )
            )
        )
    )
)

;; @desc Get next sqrt price given an input amount of token0
;; Liquidity remains constant.
;; New Price = (Liquidity * Price) / (Liquidity + Amount * Price)
(define-read-only (get-next-sqrt-price-from-amount0 (sqrt-price uint) (liquidity uint) (amount uint) (add bool))
    (if (is-eq amount u0)
        (ok sqrt-price)
        (let (
            (product (* amount sqrt-price))
            (denominator (if add 
                            (+ (* liquidity Q96) product)
                            (- (* liquidity Q96) product) ;; simplified
                         ))
        )
            (if (is-eq denominator u0)
                (err ERR_DIV_ZERO)
                (ok (/ (* (* liquidity Q96) sqrt-price) denominator))
            )
        )
    )
)

;; @desc Get next sqrt price given an input amount of token1
;; New Price = Price + (Amount / Liquidity)
(define-read-only (get-next-sqrt-price-from-amount1 (sqrt-price uint) (liquidity uint) (amount uint) (add bool))
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
;; Simplified exponential approximation: 1.0001^tick * 2^96
;; For demo purposes, we use a very rough approximation or a small lookup if needed.
;; Here we assume linear for small range or just return a base value + tick * factor.
;; Real impl requires 50 lines of bitwise math.
(define-read-only (tick-to-sqrt-price (tick int))
    ;; Placeholder: Base 1.0 * 2^96.
    ;; tick 0 -> Q96
    ;; tick 1 -> Q96 * 1.0001
    (let (
        (abs-tick (if (< tick 0) (* tick -1) tick))
        ;; very rough: price = Q96 * (1 + 0.0001 * tick)
        (factor (+ u10000 (to-uint abs-tick)))
    )
        (if (< tick 0)
            (ok (/ (* Q96 u10000) factor))
            (ok (/ (* Q96 factor) u10000))
        )
    )
)
