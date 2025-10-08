;; Concentrated Liquidity Pool (v1)
;; Implements tick-based liquidity positions with customizable fee tiers
;; Implements the pool-trait interface for compatibility with the DEX router

;; --- Constants ---
(define-constant FEE_TIER_LOW u3000)   ;; 0.3%
(define-constant FEE_TIER_MEDIUM u10000) ;; 1.0%
(define-constant FEE_TIER_HIGH u30000)  ;; 3.0%
(define-constant TRAIT_REGISTRY .trait-registry)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_FEE_TIER (err u101))
(define-constant ERR_INVALID_TICK_RANGE (err u102))
(define-constant ERR_ZERO_LIQUIDITY (err u103))
(define-constant ERR_INSUFFICIENT_FUNDS (err u104))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u105))
(define-constant ERR_INVALID_TOKEN (err u106))
(define-constant ERR_POSITION_NOT_FOUND (err u107))
(define-constant ERR_POOL_NOT_INITIALIZED (err u108))
(define-constant ERR_PRICE_LIMIT_REACHED (err u109))
(define-constant ERR_MATH_OVERFLOW (err u110))
(define-constant PRECISION u1000000000000000000) ;; 18 decimals

;; --- Traits ---

;; Implement the standard pool trait

;; --- Contract State ---
(define-data-var contract-owner principal tx-sender)
(define-data-var position-nft-contract principal tx-sender)
(define-data-var protocol-fee uint u1667) ;; 1/6 of the fee (0.05% for 0.3% pools)
(define-data-var is-initialized bool false)

;; Initialize data variables with default values
(define-data-var pool-token-x principal tx-sender)
(define-data-var pool-token-y principal tx-sender)
(define-data-var fee-tier uint u0)
(define-data-var tick-spacing uint u60)  ;; 0.05% tick spacing
(define-data-var liquidity uint u0)
(define-data-var sqrt-price-x64 uint u0)
(define-data-var current-tick int i0)
(define-data-var fee-growth-global-x uint u0)
(define-data-var fee-growth-global-y uint u0)
(define-data-var protocol-fees-x uint u0)
(define-data-var protocol-fees-y uint u0)

;; Tracks individual positions
(define-map positions 
  {position-id: uint}
  {owner: principal,
   tick-lower: int,
   tick-upper: int,
   liquidity: uint,
   fee-growth-inside-x: uint,
   fee-growth-inside-y: uint,
   tokens-owed-x: uint,
   tokens-owed-y: uint})

;; Tracks tick data
(define-map ticks
  {tick: int}
  {liquidity-gross: uint,
   liquidity-net: int,
   fee-growth-outside-x: uint,
   fee-growth-outside-y: uint,
   initialized: bool})

;; Initialize pool with two tokens and fee tier
(define-public (initialize (token-x principal) (token-y principal) (fee uint) (initial-sqrt-price uint))
  (begin
    ;; Validate tokens and fee tier
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-fee-tier fee) ERR_INVALID_FEE_TIER)
    (asserts! (not (var-get is-initialized)) ERR_UNAUTHORIZED)
    
    ;; Set initial state
    (var-set pool-token-x token-x)
    (var-set pool-token-y token-y)
    (var-set fee-tier fee)
    (var-set tick-spacing (get-tick-spacing fee))
    (var-set sqrt-price-x64 initial-sqrt-price)
    (var-set current-tick (contract-call? .concentrated-math sqrt-price-to-tick initial-sqrt-price))
    (var-set is-initialized true)
    
    (ok true)))

(define-public (set-position-nft-contract (contract-address principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set position-nft-contract contract-address)
        (ok true)
    )
)

;; Create a new position within a tick range
(define-public (mint-position 
  (recipient principal)
  (tick-lower int) 
  (tick-upper int) 
  (amount-x-desired uint) 
  (amount-y-desired uint)
  (amount-x-min uint)
  (amount-y-min uint))
  
  (let ((position-id (try! (contract-call? (var-get position-nft-contract) mint recipient)))
        (token-x (var-get pool-token-x))
        (token-y (var-get pool-token-y)))
    
    ;; Validate inputs
    (asserts! (var-get is-initialized) ERR_POOL_NOT_INITIALIZED)
    (asserts! (< tick-lower tick-upper) ERR_INVALID_TICK_RANGE)
    (asserts! (is-valid-tick tick-lower) ERR_INVALID_TICK_RANGE)
    (asserts! (is-valid-tick tick-upper) ERR_INVALID_TICK_RANGE)
    
    ;; Calculate liquidity from amounts
    (let ((liquidity-amount (contract-call? .concentrated-math 
                              get-liquidity-for-amounts 
                              (var-get sqrt-price-x64) 
                              (contract-call? .concentrated-math tick-to-sqrt-price tick-lower)
                              (contract-call? .concentrated-math tick-to-sqrt-price tick-upper)
                              amount-x-desired
                              amount-y-desired)))
      
      ;; Ensure non-zero liquidity
      (asserts! (> liquidity-amount u0) ERR_ZERO_LIQUIDITY)
      
      ;; Calculate actual token amounts needed
      (let ((amounts (calculate-amounts-for-liquidity 
                       (var-get current-tick)
                       tick-lower
                       tick-upper
                       liquidity-amount)))
        
        (let ((amount-x (get amount-x amounts))
              (amount-y (get amount-y amounts)))
          
          ;; Check slippage
          (asserts! (>= amount-x amount-x-min) ERR_SLIPPAGE_EXCEEDED)
          (asserts! (>= amount-y amount-y-min) ERR_SLIPPAGE_EXCEEDED)
          
          ;; Transfer tokens to pool
          (try! (contract-call? token-x transfer amount-x tx-sender (as-contract tx-sender) none))
          (try! (contract-call? token-y transfer amount-y tx-sender (as-contract tx-sender) none))
          
          ;; Update ticks
          (update-tick tick-lower (to-int liquidity-amount))
          (update-tick tick-upper (to-int (- u0 liquidity-amount)))
          
          ;; Create position
          (map-set positions 
            {position-id: position-id}
            {owner: recipient,
             tick-lower: tick-lower,
             tick-upper: tick-upper,
             liquidity: liquidity-amount,
             fee-growth-inside-x: u0,
             fee-growth-inside-y: u0,
             tokens-owed-x: u0,
             tokens-owed-y: u0})
          
          ;; Update global state
          (var-set liquidity (+ (var-get liquidity) liquidity-amount))
          
          (ok (tuple (position-id position-id) (liquidity liquidity-amount) (amount-x amount-x) (amount-y amount-y)))))))
  ))

;; Remove liquidity from a position
(define-public (burn-position (position-id uint))
  (let ((position (unwrap! (map-get? positions {position-id: position-id}) ERR_POSITION_NOT_FOUND)))
    
    ;; Verify ownership and burn NFT
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (try! (contract-call? (var-get position-nft-contract) burn position-id (get owner position)))
    
    ;; Calculate fees earned
    (let ((fees (calculate-fees-earned position)))
      
      ;; Update ticks
      (update-tick (get tick-lower position) (to-int (- u0 (get liquidity position))))
      (update-tick (get tick-upper position) (to-int (get liquidity position)))
      
      ;; Update global liquidity
      (var-set liquidity (- (var-get liquidity) (get liquidity position)))
      
      ;; Update position with fees owed
      (map-set positions 
        {position-id: position-id}
        (merge position 
          {liquidity: u0,
           tokens-owed-x: (+ (get tokens-owed-x position) (get fees-x fees)),
           tokens-owed-y: (+ (get tokens-owed-y position) (get fees-y fees))}))
      
      (ok (tuple (fees-x (get fees-x fees)) (fees-y (get fees-y fees))))
    ))
  )

;; Collect fees and tokens from a burned position
(define-public (collect-position (position-id uint) (recipient principal))
  (let ((position (unwrap! (map-get? positions {position-id: position-id}) ERR_POSITION_NOT_FOUND))
        (token-x (var-get pool-token-x))
        (token-y (var-get pool-token-y)))
    
    ;; Verify ownership
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    
    ;; Get amounts to collect
    (let ((amount-x (get tokens-owed-x position))
          (amount-y (get tokens-owed-y position)))
      
      ;; Transfer tokens to recipient
      (if (> amount-x u0)
        (try! (as-contract (contract-call? token-x transfer amount-x tx-sender recipient none)))
        true)
      
      (if (> amount-y u0)
        (try! (as-contract (contract-call? token-y transfer amount-y tx-sender recipient none)))
        true)
      
      ;; Update position
      (map-set positions 
        {position-id: position-id}
        (merge position {tokens-owed-x: u0, tokens-owed-y: u0}))
      
      (ok (tuple (amount-x amount-x) (amount-y amount-y)))
    ))
  )

;; Swap tokens
(define-public (swap 
  (zero-for-one bool) 
  (amount-specified uint) 
  (sqrt-price-limit uint))
  
  (let ((token-in (if zero-for-one (var-get pool-token-x) (var-get pool-token-y)))
        (token-out (if zero-for-one (var-get pool-token-y) (var-get pool-token-x))))
    
    ;; Validate inputs
    (asserts! (var-get is-initialized) ERR_POOL_NOT_INITIALIZED)
    (asserts! (> amount-specified u0) ERR_INVALID_TICK_RANGE)
    
    ;; Execute swap
    (let ((result (execute-swap zero-for-one amount-specified sqrt-price-limit)))
      
      ;; Transfer tokens
      (try! (contract-call? token-in transfer (get amount-in result) tx-sender (as-contract tx-sender) none))
      (try! (as-contract (contract-call? token-out transfer (get amount-out result) tx-sender tx-sender none)))
      
      (ok result)
    ))
  )

;; Internal: Execute swap calculation and state updates
(define-private (execute-swap (zero-for-one bool) (amount-specified uint) (sqrt-price-limit uint))
  (let ((current-sqrt-price (var-get sqrt-price-x64))
        (current-tick (var-get current-tick))
        (current-liquidity (var-get liquidity)))
    
    ;; Validate price limit
    (asserts! (if zero-for-one
                (< sqrt-price-limit current-sqrt-price)
                (> sqrt-price-limit current-sqrt-price))
              ERR_PRICE_LIMIT_REACHED)
    
    ;; Calculate swap amounts (simplified)
    (let ((amount-in amount-specified)
          (amount-out (calculate-output-amount amount-specified zero-for-one current-sqrt-price current-liquidity))
          (new-sqrt-price (calculate-new-sqrt-price amount-specified zero-for-one current-sqrt-price current-liquidity))
          (new-tick (contract-call? .concentrated-math sqrt-price-to-tick new-sqrt-price)))
      
      ;; Calculate fees
      (let ((fee-amount (/ (* amount-in (var-get fee-tier)) u1000000))
            (protocol-fee-amount (/ (* fee-amount (var-get protocol-fee)) u10000)))
        
        ;; Update global state
        (var-set sqrt-price-x64 new-sqrt-price)
        (var-set current-tick new-tick)
        
        ;; Update fee tracking
        (if zero-for-one
          (begin
            (var-set fee-growth-global-x (+ (var-get fee-growth-global-x) (/ (* (- fee-amount protocol-fee-amount) PRECISION) current-liquidity)))
            (var-set protocol-fees-x (+ (var-get protocol-fees-x) protocol-fee-amount)))
          (begin
            (var-set fee-growth-global-y (+ (var-get fee-growth-global-y) (/ (* (- fee-amount protocol-fee-amount) PRECISION) current-liquidity)))
            (var-set protocol-fees-y (+ (var-get protocol-fees-y) protocol-fee-amount))))
        
        (tuple (amount-in amount-in) (amount-out amount-out) (fee fee-amount) (new-sqrt-price new-sqrt-price))
      ))
    ))

;; Internal: Calculate output amount for swap (simplified)
(define-private (calculate-output-amount (amount-in uint) (zero-for-one bool) (sqrt-price uint) (liquidity-amount uint))
  ;; Simplified calculation - in production would use more precise math
  (let ((price (/ (* sqrt-price sqrt-price) PRECISION)))
    (if zero-for-one
      (/ (* amount-in price) PRECISION)  ;; x to y
      (/ (* amount-in PRECISION) price)  ;; y to x
    )))

;; Internal: Calculate new sqrt price after swap (simplified)
(define-private (calculate-new-sqrt-price (amount-in uint) (zero-for-one bool) (sqrt-price uint) (liquidity-amount uint))
  ;; Simplified calculation - in production would use more precise math
  (let ((price-impact (/ (* amount-in u100) liquidity-amount)))
    (if zero-for-one
      (- sqrt-price (/ (* sqrt-price price-impact) u10000))  ;; Price decreases
      (+ sqrt-price (/ (* sqrt-price price-impact) u10000))  ;; Price increases
    )))

;; Internal: Update tick data
(define-private (update-tick (tick-idx int) (liquidity-delta int))
  (let ((tick-data (default-to 
                     {liquidity-gross: u0, liquidity-net: i0, 
                      fee-growth-outside-x: u0, fee-growth-outside-y: u0, 
                      initialized: false}
                     (map-get? ticks {tick: tick-idx}))))
    
    (let ((new-liquidity-gross (if (> liquidity-delta i0)
                                 (+ (get liquidity-gross tick-data) (to-uint liquidity-delta))
                                 (+ (get liquidity-gross tick-data) (to-uint (- i0 liquidity-delta)))))
          (new-liquidity-net (+ (get liquidity-net tick-data) liquidity-delta)))
      
      (map-set ticks
        {tick: tick-idx}
        {liquidity-gross: new-liquidity-gross,
         liquidity-net: new-liquidity-net,
         fee-growth-outside-x: (get fee-growth-outside-x tick-data),
         fee-growth-outside-y: (get fee-growth-outside-y tick-data),
         initialized: true})
      
      true
    )))

;; Internal: Calculate amounts for liquidity
(define-private (calculate-amounts-for-liquidity (current-tick int) (tick-lower int) (tick-upper int) (liquidity uint))
  (let ((sqrt-price-current (var-get sqrt-price-x64))
        (sqrt-price-lower (contract-call? .concentrated-math tick-to-sqrt-price tick-lower))
        (sqrt-price-upper (contract-call? .concentrated-math tick-to-sqrt-price tick-upper)))
    
    (let ((amount-x (if (< current-tick tick-lower)
                       ;; Current price below range - only token X
                       (/ (* liquidity (- sqrt-price-upper sqrt-price-lower)) sqrt-price-lower)
                       (if (< current-tick tick-upper)
                         ;; Current price in range
                         (/ (* liquidity (- sqrt-price-upper sqrt-price-current)) sqrt-price-current)
                         ;; Current price above range - no token X
                         u0)))
          (amount-y (if (< current-tick tick-lower)
                       ;; Current price below range - no token Y
                       u0
                       (if (< current-tick tick-upper)
                         ;; Current price in range
                         (* liquidity (- sqrt-price-current sqrt-price-lower))
                         ;; Current price above range - only token Y
                         (* liquidity (- sqrt-price-upper sqrt-price-lower))))))
      
      (tuple (amount-x amount-x) (amount-y amount-y))
    )))

;; Internal: Calculate fees earned by a position
(define-private (calculate-fees-earned (position {owner: principal, tick-lower: int, tick-upper: int, liquidity: uint, fee-growth-inside-x: uint, fee-growth-inside-y: uint, tokens-owed-x: uint, tokens-owed-y: uint}))
  (let ((fee-growth-inside-x-new (get-fee-growth-inside (get tick-lower position) (get tick-upper position) true))
        (fee-growth-inside-y-new (get-fee-growth-inside (get tick-lower position) (get tick-upper position) false)))
    
    (let ((fees-x (/ (* (get liquidity position) (- fee-growth-inside-x-new (get fee-growth-inside-x position))) PRECISION))
          (fees-y (/ (* (get liquidity position) (- fee-growth-inside-y-new (get fee-growth-inside-y position))) PRECISION)))
      
      (tuple (fees-x fees-x) (fees-y fees-y))
    )))

;; Internal: Get fee growth inside a tick range
(define-private (get-fee-growth-inside (tick-lower int) (tick-upper int) (is-token-x bool))
  (let ((global-growth (if is-token-x (var-get fee-growth-global-x) (var-get fee-growth-global-y)))
        (lower-outside (get-fee-growth-outside tick-lower is-token-x))
        (upper-outside (get-fee-growth-outside tick-upper is-token-x))
        (current-tick (var-get current-tick)))
    
    (let ((growth-below (if (< current-tick tick-lower) (- global-growth lower-outside) lower-outside))
          (growth-above (if (>= current-tick tick-upper) (- global-growth upper-outside) upper-outside)))
      
      (- (- global-growth growth-below) growth-above)
    )))

;; Internal: Get fee growth outside a tick
(define-private (get-fee-growth-outside (tick int) (is-token-x bool))
  (let ((tick-data (default-to 
                     {liquidity-gross: u0, liquidity-net: i0, 
                      fee-growth-outside-x: u0, fee-growth-outside-y: u0, 
                      initialized: false}
                     (map-get? ticks {tick: tick}))))
    
    (if is-token-x
      (get fee-growth-outside-x tick-data)
      (get fee-growth-outside-y tick-data))
  ))

;; Internal: Validate fee tier
(define-private (is-valid-fee-tier (fee uint))
  (or 
    (is-eq fee FEE_TIER_LOW)
    (is-eq fee FEE_TIER_MEDIUM)
    (is-eq fee FEE_TIER_HIGH)))

;; Internal: Calculate tick spacing based on fee tier
(define-private (get-tick-spacing (fee uint))
  (if (is-eq fee FEE_TIER_LOW)
    u10
    (if (is-eq fee FEE_TIER_MEDIUM)
      u60
      (if (is-eq fee FEE_TIER_HIGH)
        u200
        u60)))) ;; Default to medium spacing if no match

;; Internal: Validate tick is within allowed range
(define-private (is-valid-tick (tick int))
  (and 
    (>= tick (- 887272))  ;; Min tick
    (<= tick 887272)))    ;; Max tick

;; Read-only functions for external queries

;; Get pool information
(define-read-only (get-pool-info)
  (ok (tuple 
    (token-x (var-get pool-token-x))
    (token-y (var-get pool-token-y))
    (fee-tier (var-get fee-tier))
    (liquidity (var-get liquidity))
    (sqrt-price (var-get sqrt-price-x64))
    (current-tick (var-get current-tick))
    (tick-spacing (var-get tick-spacing)))))

;; Get position information
(define-read-only (get-position (position-id uint))
  (match (map-get? positions {position-id: position-id})
    position (ok position)
    (err ERR_POSITION_NOT_FOUND)))

;; Get tick information
(define-read-only (get-tick (tick-idx int))
  (match (map-get? ticks {tick: tick-idx})
    tick-data (ok tick-data)
    (ok {liquidity-gross: u0, liquidity-net: i0, 
         fee-growth-outside-x: u0, fee-growth-outside-y: u0, 
         initialized: false})))

;; Get current price
(define-read-only (get-current-price)
  (let ((sqrt-price (var-get sqrt-price-x64)))
    (ok (/ (* sqrt-price sqrt-price) PRECISION))))

;; Get protocol fees collected
(define-read-only (get-protocol-fees)
  (ok (tuple (fees-x (var-get protocol-fees-x)) (fees-y (var-get protocol-fees-y)))))

;; Get owner
(define-read-only (get-owner)
  (ok (var-get contract-owner)))

;; Implement pool-trait functions
(define-public (swap-exact-tokens-for-tokens (token-x-in principal) (token-y-out principal) (amount-in uint) (min-amount-out uint) (recipient principal))
  (let ((zero-for-one (is-eq token-x-in (var-get pool-token-x))))
    (asserts! (or (and zero-for-one (is-eq token-y-out (var-get pool-token-y)))
                 (and (not zero-for-one) (is-eq token-x-in (var-get pool-token-y)) (is-eq token-y-out (var-get pool-token-x))))
              ERR_INVALID_TOKEN)
    
    (let ((result (try! (swap zero-for-one amount-in u0))))
      (asserts! (>= (get amount-out result) min-amount-out) ERR_SLIPPAGE_EXCEEDED)
      (ok (get amount-out result)))))

;; Additional pool-trait variants are implemented by the canonical pool trait file.


