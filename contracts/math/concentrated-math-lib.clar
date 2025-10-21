;; concentrated-math-lib.clar
;; Advanced mathematical functions for concentrated liquidity pools

;; Constants
(define-constant Q64 u18446744073709551616)  ;; 2^64
(define-constant Q96 u79228162514264337593543950336)  ;; 2^96
(define-constant Q128 u340282366920938463463374607431768211455)  ;; 2^128 - 1
(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)
(define-constant MIN_SQRT_RATIO u4295128739)  ;; sqrt(1.0001^MIN_TICK)
(define-constant MAX_SQRT_RATIO u1461446703485210103287273052203988822378723970342)  ;; sqrt(1.0001^MAX_TICK)

;; Error codes
(define-constant ERR_INVALID_TICK (err u1001))
(define-constant ERR_INVALID_SQRT_RATIO (err u1002))
(define-constant ERR_OVERFLOW (err u1003))
(define-constant ERR_DIVISION_BY_ZERO (err u1004))

;; @desc Convert tick to sqrt price in Q96 format
;; @param tick Tick value
;; @returns (response uint uint)
(define-read-only (tick-to-sqrt-price-x96 (tick int))
  (let ((abs-tick (if (< tick 0) (- 0 tick) tick)))
    (asserts! (<= abs-tick (to-uint MAX_TICK)) ERR_INVALID_TICK)
    
    (let ((ratio (if (is-eq (bitwise-and abs-tick u1) u1)
                   u79232123830000000000000000000000000000
                   u79228162514264337593543950336)))
      (if (< tick 0)
        (ok (/ Q96 ratio))
        (ok ratio)
      )
    )
  )
)

;; @desc Convert sqrt price in Q96 format to tick
;; @param sqrt-price-x96 Sqrt price in Q96 format
;; @returns (response int uint)
(define-read-only (sqrt-price-x96-to-tick (sqrt-price-x96 uint))
  (asserts! (>= sqrt-price-x96 MIN_SQRT_RATIO) ERR_INVALID_SQRT_RATIO)
  (asserts! (<= sqrt-price-x96 MAX_SQRT_RATIO) ERR_INVALID_SQRT_RATIO)
  
  (let ((ratio (/ (* sqrt-price-x96 sqrt-price-x96) Q96)))
    (ok (to-int (log2 ratio)))
  )
)

;; @desc Calculate liquidity for given amounts and price range
;; @param sqrt-price-current Current sqrt price in Q96 format
;; @param sqrt-price-a Lower sqrt price boundary in Q96 format
;; @param sqrt-price-b Upper sqrt price boundary in Q96 format
;; @param amount0 Amount of token0
;; @param amount1 Amount of token1
;; @returns (response uint uint)
(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-a uint) (sqrt-price-b uint) (amount0 uint) (amount1 uint))
  (asserts! (> sqrt-price-a u0) ERR_DIVISION_BY_ZERO)
  (asserts! (> sqrt-price-b u0) ERR_DIVISION_BY_ZERO)
  
  (if (< sqrt-price-current sqrt-price-a)
    (ok (div amount0 (- sqrt-price-b sqrt-price-a)))
    (if (> sqrt-price-current sqrt-price-b)
      (ok (div amount1 (- sqrt-price-b sqrt-price-a)))
      (ok (min (div amount0 (- sqrt-price-current sqrt-price-a)) (div amount1 (- sqrt-price-b sqrt-price-current))))
    )
  )
)

;; @desc Calculate amounts for given liquidity and price range
;; @param sqrt-price-current Current sqrt price in Q96 format
;; @param sqrt-price-a Lower sqrt price boundary in Q96 format
;; @param sqrt-price-b Upper sqrt price boundary in Q96 format
;; @param liquidity Liquidity amount
;; @returns (response (tuple (amount0 uint) (amount1 uint)) uint)
(define-read-only (get-amounts-for-liquidity (sqrt-price-current uint) (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (if (< sqrt-price-current sqrt-price-a)
    (ok (tuple (amount0 (* liquidity (- sqrt-price-b sqrt-price-a))) (amount1 u0)))
    (if (> sqrt-price-current sqrt-price-b)
      (ok (tuple (amount0 u0) (amount1 (* liquidity (- sqrt-price-b sqrt-price-a)))))
      (ok (tuple
        (amount0 (* liquidity (- sqrt-price-current sqrt-price-a)))
        (amount1 (* liquidity (- sqrt-price-b sqrt-price-current))))
    )
  )
)

;; @desc Calculate the next sqrt price after swap
;; @param sqrt-price-current Current sqrt price in Q96 format
;; @param liquidity Liquidity amount
;; @param amount-in Input amount
;; @param zero-for-one Direction of swap
;; @returns (response uint uint)
(define-read-only (get-next-sqrt-price-from-input (sqrt-price-current uint) (liquidity uint) (amount-in uint) (zero-for-one bool))
  (asserts! (> liquidity u0) ERR_DIVISION_BY_ZERO)
  
  (let ((numerator (* liquidity sqrt-price-current)))
    (if zero-for-one
      (let ((denominator (+ numerator (* amount-in Q96))))
        (ok (div numerator denominator))
      )
      (let ((denominator (- numerator (* amount-in Q96))))
        (ok (div numerator denominator))
      )
    )
  )
)

;; @desc Calculate output amount for swap
;; @param sqrt-price-current Current sqrt price in Q96 format
;; @param liquidity Liquidity amount
;; @param amount-in Input amount
;; @param zero-for-one Direction of swap
;; @returns (response uint uint)
(define-read-only (get-amount-out (sqrt-price-current uint) (liquidity uint) (amount-in uint) (zero-for-one bool))
  (let ((new-sqrt-price (unwrap! (get-next-sqrt-price-from-input sqrt-price-current liquidity amount-in zero-for-one))))
    (if zero-for-one
      (ok (div (* liquidity (- sqrt-price-current new-sqrt-price)) new-sqrt-price))
      (ok (div (* liquidity (- new-sqrt-price sqrt-price-current)) sqrt-price-current))
    )
  )
)

;; @desc Calculate fee growth inside tick range
;; @param tick-lower Lower tick boundary
;; @param tick-upper Upper tick boundary
;; @param tick-current Current tick
;; @param fee-growth-global0 Global fee growth for token0
;; @param fee-growth-global1 Global fee growth for token1
;; @returns (response (tuple (fee-growth-inside0 uint) (fee-growth-inside1 uint)) uint)
(define-read-only (get-fee-growth-inside (tick-lower int) (tick-upper int) (tick-current int) (fee-growth-global0 uint) (fee-growth-global1 uint))
  (let ((fee-growth-below0 (get-fee-growth-below tick-lower fee-growth-global0))
        (fee-growth-below1 (get-fee-growth-below tick-lower fee-growth-global1))
        (fee-growth-above0 (get-fee-growth-above tick-upper fee-growth-global0))
        (fee-growth-above1 (get-fee-growth-above tick-upper fee-growth-global1)))
    
    (ok (tuple
      (fee-growth-inside0 (- fee-growth-global0 (+ fee-growth-below0 fee-growth-above0)))
      (fee-growth-inside1 (- fee-growth-global1 (+ fee-growth-below1 fee-growth-above1)))
    ))
  )
)

;; @desc Calculate fee growth below tick
;; @param tick Tick value
;; @param fee-growth-global Global fee growth
;; @returns (response uint uint)
(define-private (get-fee-growth-below (tick int) (fee-growth-global uint))
  (let ((tick-info (unwrap! (map-get? ticks { pool-id: pool-id, tick: tick }) 
                          { liquidity-gross: u0, liquidity-net: i0, 
                            fee-growth-outside0-x128: fee-growth-global,
                            fee-growth-outside1-x128: fee-growth-global,
                            seconds-per-liquidity-outside-x128: u0 })))
    (if (< tick-current tick)
      (ok (get fee-growth-outside0-x128 tick-info))
      (ok (- fee-growth-global (get fee-growth-outside0-x128 tick-info)))
    )
  )
)

;; @desc Calculate fee growth above tick
;; @param tick Tick value
;; @param fee-growth-global Global fee growth
;; @returns (response uint uint)
(define-private (get-fee-growth-above (tick int) (fee-growth-global uint))
  (let ((tick-info (unwrap! (map-get? ticks { pool-id: pool-id, tick: tick }) 
                          { liquidity-gross: u0, liquidity-net: i0, 
                            fee-growth-outside0-x128: fee-growth-global,
                            fee-growth-outside1-x128: fee-growth-global,
                            seconds-per-liquidity-outside-x128: u0 })))
    (if (>= tick-current tick)
      (ok (get fee-growth-outside0-x128 tick-info))
      (ok (- fee-growth-global (get fee-growth-outside0-x128 tick-info)))
    )
  )
)

;; Utility functions
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

(define-private (max (a uint) (b uint))
  (if (> a b) a b))

(define-private (abs (x int))
  (if (< x 0) (- 0 x) x))