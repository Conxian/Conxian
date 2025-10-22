;; ===========================================
;; CONCENTRATED LIQUIDITY MATH LIBRARY
;; ===========================================
;;
;; Advanced mathematical functions for concentrated liquidity pools
;; Implements Uniswap V3-style concentrated liquidity calculations
;;
;; VERSION: 2.0

;; ===========================================
;; CONSTANTS
;; ===========================================

;; Fixed-point constants
(define-constant Q64 u18446744073709551616)  ;; 2^64
(define-constant Q96 u79228162514264337593543950336)  ;; 2^96
(define-constant Q128 u340282366920938463463374607431768211455)  ;; 2^128 - 1

;; Tick range constants
(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)

;; Sqrt price range constants (using smaller, safe values)
(define-constant MIN_SQRT_RATIO u4295128739)  ;; Minimum sqrt price
(define-constant MAX_SQRT_RATIO u1461446703485210103287273052203988822378723970342)  ;; Maximum sqrt price (truncated to safe value)

;; Error codes
(define-constant ERR_INVALID_TICK (err u1001))
(define-constant ERR_INVALID_SQRT_RATIO (err u1002))
(define-constant ERR_OVERFLOW (err u1003))
(define-constant ERR_DIVISION_BY_ZERO (err u1004))
(define-constant ERR_INVALID_POOL (err u1005))

;; ===========================================
;; DATA STRUCTURES
;; ===========================================

;; Tick information structure
(define-map ticks 
  { pool-id: uint, tick: int }
  { 
    liquidity-gross: uint,
    liquidity-net: int,
    fee-growth-outside0-x128: uint,
    fee-growth-outside1-x128: uint,
    seconds-per-liquidity-outside-x128: uint
  })

;; Pool state variables
(define-data-var pool-id uint u0)
(define-data-var tick-current int 0)

;; ===========================================
;; TICK AND PRICE CONVERSION FUNCTIONS
;; ===========================================

;; Convert tick to sqrt price in Q96 format
(define-read-only (tick-to-sqrt-price-x96 (tick int))
  (let ((abs-tick (if (< tick 0) (- 0 tick) tick)))
    (asserts! (<= abs-tick (to-uint MAX_TICK)) ERR_INVALID_TICK)
    
    ;; Simplified calculation for demonstration
    ;; In production, this would use the full Uniswap V3 formula
    (let ((base-ratio u79228162514264337593543950336)) ;; Q96
      (if (< tick 0)
        (ok (/ Q96 base-ratio))
        (ok base-ratio)))))

;; Convert sqrt price in Q96 format to tick
(define-read-only (sqrt-price-x96-to-tick (sqrt-price-x96 uint))
  (asserts! (>= sqrt-price-x96 MIN_SQRT_RATIO) ERR_INVALID_SQRT_RATIO)
  (asserts! (<= sqrt-price-x96 u79228162514264337593543950336) ERR_INVALID_SQRT_RATIO) ;; Use safe max value
  
  ;; Simplified calculation - in production would use proper log calculation
  (let ((normalized-price (/ sqrt-price-x96 u1000000000000000000))) ;; Scale down
    (ok (to-int normalized-price))))

;; ===========================================
;; LIQUIDITY CALCULATION FUNCTIONS
;; ===========================================

;; Calculate liquidity for given amounts and price range
(define-read-only (get-liquidity-for-amounts 
  (sqrt-price-current uint) 
  (sqrt-price-a uint) 
  (sqrt-price-b uint) 
  (amount0 uint) 
  (amount1 uint))
  
  (asserts! (> sqrt-price-a u0) ERR_DIVISION_BY_ZERO)
  (asserts! (> sqrt-price-b u0) ERR_DIVISION_BY_ZERO)
  (asserts! (< sqrt-price-a sqrt-price-b) ERR_INVALID_SQRT_RATIO)
  
  (if (< sqrt-price-current sqrt-price-a)
    ;; Current price below range - only token0 needed
    (ok (/ (* amount0 sqrt-price-a) (- sqrt-price-b sqrt-price-a)))
    (if (> sqrt-price-current sqrt-price-b)
      ;; Current price above range - only token1 needed
      (ok (/ amount1 (- sqrt-price-b sqrt-price-a)))
      ;; Current price in range - use minimum of both calculations
      (let ((liquidity0 (/ (* amount0 sqrt-price-current) (- sqrt-price-current sqrt-price-a)))
            (liquidity1 (/ amount1 (- sqrt-price-b sqrt-price-current))))
        (ok (min liquidity0 liquidity1))))))

;; Calculate amounts for given liquidity and price range
(define-read-only (get-amounts-for-liquidity 
  (sqrt-price-current uint) 
  (sqrt-price-a uint) 
  (sqrt-price-b uint) 
  (liquidity uint))
  
  (if (< sqrt-price-current sqrt-price-a)
    ;; Current price below range
    (ok {amount0: (/ (* liquidity (- sqrt-price-b sqrt-price-a)) sqrt-price-a), amount1: u0})
    (if (> sqrt-price-current sqrt-price-b)
      ;; Current price above range
      (ok {amount0: u0, amount1: (* liquidity (- sqrt-price-b sqrt-price-a))})
      ;; Current price in range
      (ok {
        amount0: (/ (* liquidity (- sqrt-price-current sqrt-price-a)) sqrt-price-current),
        amount1: (* liquidity (- sqrt-price-b sqrt-price-current))
      }))))

;; ===========================================
;; SWAP CALCULATION FUNCTIONS
;; ===========================================

;; Calculate the next sqrt price after swap
(define-read-only (get-next-sqrt-price-from-input 
  (sqrt-price-current uint) 
  (liquidity uint) 
  (amount-in uint) 
  (zero-for-one bool))
  
  (asserts! (> liquidity u0) ERR_DIVISION_BY_ZERO)
  (asserts! (> sqrt-price-current u0) ERR_DIVISION_BY_ZERO)
  
  (if zero-for-one
    ;; Swapping token0 for token1 (price decreases)
    (let ((numerator (* liquidity sqrt-price-current))
          (denominator (+ (* liquidity sqrt-price-current) (* amount-in Q96))))
      (if (is-eq denominator u0)
        ERR_DIVISION_BY_ZERO
        (ok (/ numerator denominator))))
    ;; Swapping token1 for token0 (price increases)
    (let ((delta-sqrt-price (/ amount-in liquidity)))
      (ok (+ sqrt-price-current delta-sqrt-price)))))

;; Calculate output amount for swap
(define-read-only (get-amount-out 
  (sqrt-price-current uint) 
  (liquidity uint) 
  (amount-in uint) 
  (zero-for-one bool))
  
  (let ((new-sqrt-price (unwrap! (get-next-sqrt-price-from-input sqrt-price-current liquidity amount-in zero-for-one) ERR_OVERFLOW)))
    (if zero-for-one
      ;; Output is token1
      (ok (/ (* liquidity (- sqrt-price-current new-sqrt-price)) new-sqrt-price))
      ;; Output is token0
      (ok (/ (* liquidity (- new-sqrt-price sqrt-price-current)) sqrt-price-current)))))

;; ===========================================
;; FEE CALCULATION FUNCTIONS
;; ===========================================

;; Calculate fee growth inside tick range
(define-read-only (get-fee-growth-inside 
  (tick-lower int) 
  (tick-upper int) 
  (tick-current int) 
  (fee-growth-global0 uint) 
  (fee-growth-global1 uint))
  
  (let ((fee-growth-below0 (unwrap! (get-fee-growth-below tick-lower fee-growth-global0 tick-current) ERR_INVALID_POOL))
        (fee-growth-below1 (unwrap! (get-fee-growth-below tick-lower fee-growth-global1 tick-current) ERR_INVALID_POOL))
        (fee-growth-above0 (unwrap! (get-fee-growth-above tick-upper fee-growth-global0 tick-current) ERR_INVALID_POOL))
        (fee-growth-above1 (unwrap! (get-fee-growth-above tick-upper fee-growth-global1 tick-current) ERR_INVALID_POOL)))
    
    (ok {
      fee-growth-inside0: (- fee-growth-global0 (+ fee-growth-below0 fee-growth-above0)),
      fee-growth-inside1: (- fee-growth-global1 (+ fee-growth-below1 fee-growth-above1))
    })))

;; Calculate fee growth below tick
(define-private (get-fee-growth-below (tick int) (fee-growth-global uint) (current-tick int))
  (let ((current-pool-id (var-get pool-id)))
    (match (map-get? ticks {pool-id: current-pool-id, tick: tick})
      tick-info 
        (if (< current-tick tick)
          (ok (get fee-growth-outside0-x128 tick-info))
          (ok (- fee-growth-global (get fee-growth-outside0-x128 tick-info))))
      ;; If tick not found, assume no fees collected
      (ok u0))))

;; Calculate fee growth above tick
(define-private (get-fee-growth-above (tick int) (fee-growth-global uint) (current-tick int))
  (let ((current-pool-id (var-get pool-id)))
    (match (map-get? ticks {pool-id: current-pool-id, tick: tick})
      tick-info 
        (if (>= current-tick tick)
          (ok (get fee-growth-outside0-x128 tick-info))
          (ok (- fee-growth-global (get fee-growth-outside0-x128 tick-info))))
      ;; If tick not found, assume no fees collected
      (ok u0))))

;; ===========================================
;; UTILITY FUNCTIONS
;; ===========================================

;; Minimum of two values
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

;; Maximum of two values
(define-private (max (a uint) (b uint))
  (if (> a b) a b))

;; Absolute value for integers
(define-private (abs (x int))
  (if (< x 0) (- 0 x) x))

;; Safe division with zero check
(define-private (safe-div (a uint) (b uint))
  (if (is-eq b u0)
    ERR_DIVISION_BY_ZERO
    (ok (/ a b))))

;; ===========================================
;; POOL MANAGEMENT FUNCTIONS
;; ===========================================

;; Set current pool ID
(define-public (set-pool-id (new-pool-id uint))
  (begin
    (var-set pool-id new-pool-id)
    (ok true)))

;; Set current tick
(define-public (set-current-tick (new-tick int))
  (begin
    (var-set tick-current new-tick)
    (ok true)))

;; Initialize tick data
(define-public (initialize-tick (tick int) (liquidity-gross uint) (liquidity-net int))
  (let ((current-pool-id (var-get pool-id)))
    (map-set ticks 
      {pool-id: current-pool-id, tick: tick}
      {
        liquidity-gross: liquidity-gross,
        liquidity-net: liquidity-net,
        fee-growth-outside0-x128: u0,
        fee-growth-outside1-x128: u0,
        seconds-per-liquidity-outside-x128: u0
      })
    (ok true)))

;; Get tick data
(define-read-only (get-tick-data (tick int))
  (let ((current-pool-id (var-get pool-id)))
    (map-get? ticks {pool-id: current-pool-id, tick: tick})))

;; ===========================================
;; VALIDATION FUNCTIONS
;; ===========================================

;; Validate tick is within bounds
(define-read-only (is-valid-tick (tick int))
  (and (>= tick MIN_TICK) (<= tick MAX_TICK)))

;; Validate sqrt price is within bounds
(define-read-only (is-valid-sqrt-price (sqrt-price uint))
  (and (>= sqrt-price MIN_SQRT_RATIO) (<= sqrt-price u79228162514264337593543950336)))

;; Get current pool state
(define-read-only (get-pool-state)
  {pool-id: (var-get pool-id), tick-current: (var-get tick-current)})