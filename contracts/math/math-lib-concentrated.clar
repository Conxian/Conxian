;; @desc A library for concentrated liquidity math.
;; This contract is intended to provide mathematical functions for concentrated liquidity pools.
;; Currently, it only contains a placeholder function to get the contract's name.

;; @desc Get the name of the contract.
;; @returns (response (string-ascii) uint): The name of the contract.
(define-public (get-name)
    (ok "math-lib-concentrated")
)

;; @desc Calculates the liquidity given amount1 and price range.
;; @param sqrt-ratio-a The starting sqrt price.
;; @param sqrt-ratio-b The ending sqrt price.
;; @param amount1 The amount of token1.
;; @returns (response uint uint) The calculated liquidity.
(define-read-only (get-liquidity-for-amount1 (sqrt-ratio-a uint) (sqrt-ratio-b uint) (amount1 uint))
    (let (
        (sqrt-ratio-lower (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-a sqrt-ratio-b))
        (sqrt-ratio-upper (if (< sqrt-ratio-a sqrt-ratio-b) sqrt-ratio-b sqrt-ratio-a))
    )
        ;; liquidity = amount1 / (upper - lower)
        ;; Temporarily replace with simple division until fixed-point-math is available
        (/ amount1 (- sqrt-ratio-upper sqrt-ratio-lower))
    )
)
