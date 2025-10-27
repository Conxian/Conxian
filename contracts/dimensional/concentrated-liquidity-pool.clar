;; ===========================================
;; CONXIAN CONCENTRATED LIQUIDITY POOL
;; ===========================================
;; Implements tick-based concentrated liquidity positions
;; with NFT position management and advanced fee tracking
;;
;; This contract provides Uniswap V3-style concentrated liquidity
;; functionality for the Conxian DEX protocol.

;; Use centralized traits
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait ownable-trait .all-traits.ownable-trait)
(use-trait pausable-trait .all-traits.pausable-trait)
(use-trait pool-trait .all-traits.pool-trait)

;; Implement required traits
(impl-trait pausable-trait)
(impl-trait ownable-trait)
(impl-trait pool-trait)

;; ===========================================
;; CONSTANTS
;; ===========================================

;; Fee tiers (in basis points)
(define-constant FEE_TIER_LOW u3000)      ;; 0.3%
(define-constant FEE_TIER_MEDIUM u10000)  ;; 1.0%
(define-constant FEE_TIER_HIGH u30000)    ;; 3.0%

;; Tick bounds
(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)

;; Protocol fee (1/6 of swap fee)
(define-constant PROTOCOL_FEE u1667)

;; Precision for calculations
(define-constant PRECISION u1000000000000000000) ;; 10^18

;; Q96 constant for sqrt price
(define-constant Q96 u79228162514264337593543950336)

;; ===========================================
;; ERROR CODES (from standardized errors.clar)
;; ===========================================

(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_INPUT (err u1005))
(define-constant ERR_INVALID_FEE_TIER (err u4001))
(define-constant ERR_INVALID_TICK_RANGE (err u4002))
(define-constant ERR_ZERO_LIQUIDITY (err u4004))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u4004))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u4005))
(define-constant ERR_POSITION_NOT_FOUND (err u6000))
(define-constant ERR_CONTRACT_PAUSED (err u1003))

;; ===========================================
;; DATA VARIABLES
;; ===========================================

(define-data-var contract-owner principal tx-sender)
(define-data-var position-nft-contract principal tx-sender)
(define-data-var is-paused bool false)

;; Pool configuration
(define-data-var pool-token-x principal tx-sender)
(define-data-var pool-token-y principal tx-sender)
(define-data-var fee-tier uint u0)
(define-data-var tick-spacing uint u60)
(define-data-var is-initialized bool false)

;; Pool state
(define-data-var liquidity uint u0)
(define-data-var sqrt-price-x96 uint u0)
(define-data-var current-tick int i0)

;; Fee tracking
(define-data-var fee-growth-global-x uint u0)
(define-data-var fee-growth-global-y uint u0)
(define-data-var protocol-fees-x uint u0)
(define-data-var protocol-fees-y uint u0)

;; ===========================================
;; DATA MAPS
;; ===========================================

;; Position data
(define-map positions
  { position-id: uint }
  {
    owner: principal,
    tick-lower: int,
    tick-upper: int,
    liquidity: uint,
    fee-growth-inside-x: uint,
    fee-growth-inside-y: uint,
    tokens-owed-x: uint,
    tokens-owed-y: uint
  }
)

;; Tick data
(define-map ticks
  { tick: int }
  {
    liquidity-gross: uint,
    liquidity-net: int,
    fee-growth-outside-x: uint,
    fee-growth-outside-y: uint,
    initialized: bool
  }
)

;; ===========================================
;; OWNABLE TRAIT IMPLEMENTATION
;; ===========================================

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

(define-read-only (is-owner (account principal))
  (ok (is-eq account (var-get contract-owner)))
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq new-owner tx-sender)) ERR_INVALID_INPUT)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; ===========================================
;; PAUSABLE TRAIT IMPLEMENTATION
;; ===========================================

(define-read-only (is-paused)
  (ok (var-get is-paused))
)

(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set is-paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set is-paused false)
    (ok true)
  )
)

;; ===========================================
;; INTERNAL VALIDATION FUNCTIONS
;; ===========================================

(define-private (check-not-paused)
  (asserts! (not (var-get is-paused)) ERR_CONTRACT_PAUSED)
)

(define-private (is-valid-fee-tier (fee uint))
  (or (is-eq fee FEE_TIER_LOW)
      (is-eq fee FEE_TIER_MEDIUM)
      (is-eq fee FEE_TIER_HIGH))
)

(define-private (get-tick-spacing-by-fee (fee uint))
  (if (is-eq fee FEE_TIER_LOW)
    u10
    (if (is-eq fee FEE_TIER_MEDIUM)
      u60
      u200)) ;; FEE_TIER_HIGH
)

(define-private (is-valid-tick (tick int))
  (and (>= tick MIN_TICK) (<= tick MAX_TICK))
)

;; ===========================================
;; POOL INITIALIZATION
;; ===========================================

(define-public (initialize
  (token-x principal)
  (token-y principal)
  (fee uint)
  (initial-sqrt-price-x96 uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-fee-tier fee) ERR_INVALID_FEE_TIER)
    (asserts! (not (var-get is-initialized)) ERR_UNAUTHORIZED)
    (asserts! (not (is-eq token-x token-y)) ERR_INVALID_INPUT)

    ;; Set pool configuration
    (var-set pool-token-x token-x)
    (var-set pool-token-y token-y)
    (var-set fee-tier fee)
    (var-set tick-spacing (get-tick-spacing-by-fee fee))
    (var-set sqrt-price-x96 initial-sqrt-price-x96)

    ;; Calculate initial tick
    (let ((initial-tick (unwrap! (contract-call? .math-lib-concentrated sqrt-price-x96-to-tick initial-sqrt-price-x96) ERR_INVALID_INPUT)))
      (var-set current-tick initial-tick)
      (var-set is-initialized true)
      (ok true)
    )
  )
)

(define-public (set-position-nft-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set position-nft-contract contract-address)
    (ok true)
  )
)

;; ===========================================
;; POSITION MANAGEMENT
;; ===========================================

(define-public (mint-position
  (recipient principal)
  (tick-lower int)
  (tick-upper int)
  (amount-x-desired uint)
  (amount-y-desired uint)
  (amount-x-min uint)
  (amount-y-min uint)
)
  (begin
    (check-not-paused)
    (asserts! (var-get is-initialized) ERR_INVALID_INPUT)
    (asserts! (< tick-lower tick-upper) ERR_INVALID_TICK_RANGE)
    (asserts! (is-valid-tick tick-lower) ERR_INVALID_TICK_RANGE)
    (asserts! (is-valid-tick tick-upper) ERR_INVALID_TICK_RANGE)

    ;; Mint NFT position
    (let ((position-id (unwrap! (contract-call? (var-get position-nft-contract) mint recipient) ERR_UNAUTHORIZED)))
      ;; Calculate liquidity
      (let ((sqrt-price-lower (unwrap! (contract-call? .math-lib-concentrated tick-to-sqrt-price-x96 tick-lower) ERR_INVALID_INPUT))
(sqrt-price-upper (unwrap! (contract-call? .math-lib-concentrated tick-to-sqrt-price-x96 tick-upper) ERR_INVALID_INPUT)))
        (let ((liquidity-amount (unwrap! (contract-call? .math-lib-concentrated get-liquidity-for-amounts
                                                          (var-get sqrt-price-x96)
                                                          sqrt-price-lower
                                                          sqrt-price-upper
                                                          amount-x-desired
                                                          amount-y-desired) ERR_INVALID_INPUT)))

          (asserts! (> liquidity-amount u0) ERR_ZERO_LIQUIDITY)

          ;; Calculate actual amounts needed
          (let ((amounts (unwrap! (contract-call? .math-lib-concentrated get-amounts-for-liquidity
                                                   (var-get sqrt-price-x96)
                                                   sqrt-price-lower
                                                   sqrt-price-upper
                                                   liquidity-amount) ERR_INVALID_INPUT)))
            (let ((amount-x (get amount0 amounts))
                  (amount-y (get amount1 amounts)))

              ;; Check slippage
              (asserts! (>= amount-x amount-x-min) ERR_SLIPPAGE_EXCEEDED)
              (asserts! (>= amount-y amount-y-min) ERR_SLIPPAGE_EXCEEDED)

              ;; Transfer tokens to pool
              (try! (contract-call? (var-get pool-token-x) transfer amount-x tx-sender (as-contract tx-sender) none))
              (try! (contract-call? (var-get pool-token-y) transfer amount-y tx-sender (as-contract tx-sender) none))

              ;; Update ticks
              (update-tick tick-lower liquidity-amount)
              (update-tick tick-upper (- u0 liquidity-amount))

              ;; Create position
              (map-set positions
                { position-id: position-id }
                {
                  owner: recipient,
                  tick-lower: tick-lower,
                  tick-upper: tick-upper,
                  liquidity: liquidity-amount,
                  fee-growth-inside-x: u0,
                  fee-growth-inside-y: u0,
                  tokens-owed-x: u0,
                  tokens-owed-y: u0
                }
              )

              ;; Update global liquidity
              (var-set liquidity (+ (var-get liquidity) liquidity-amount))

              (ok (tuple (position-id position-id) (liquidity liquidity-amount) (amount-x amount-x) (amount-y amount-y)))
            )
          )
        )
      )
    )
  )
)

(define-public (burn-position (position-id uint))
  (let ((position (unwrap! (map-get? positions { position-id: position-id }) ERR_POSITION_NOT_FOUND)))
    (begin
      (check-not-paused)
      (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)

      ;; Calculate fees earned
      (let ((fees (calculate-fees-earned position)))
        ;; Burn NFT
        (try! (contract-call? (var-get position-nft-contract) burn position-id (get owner position)))

        ;; Update ticks
        (update-tick (get tick-lower position) (- u0 (get liquidity position)))
        (update-tick (get tick-upper position) (get liquidity position))

        ;; Update global liquidity
        (var-set liquidity (- (var-get liquidity) (get liquidity position)))

        ;; Update position with fees owed
        (map-set positions
          { position-id: position-id }
          (merge position {
            liquidity: u0,
            tokens-owed-x: (+ (get tokens-owed-x position) (get fees-x fees)),
            tokens-owed-y: (+ (get tokens-owed-y position) (get fees-y fees))
          })
        )

        (ok (tuple (fees-x (get fees-x fees)) (fees-y (get fees-y fees))))
      )
    )
  )
)

(define-public (collect-position (position-id uint) (recipient principal))
  (let ((position (unwrap! (map-get? positions { position-id: position-id }) ERR_POSITION_NOT_FOUND)))
    (begin
      (check-not-paused)
      (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)

      (let ((amount-x (get tokens-owed-x position))
            (amount-y (get tokens-owed-y position)))

        ;; Transfer tokens
        (if (> amount-x u0)
          (try! (as-contract (contract-call? (var-get pool-token-x) transfer amount-x tx-sender recipient none)))
          true
        )
        (if (> amount-y u0)
          (try! (as-contract (contract-call? (var-get pool-token-y) transfer amount-y tx-sender recipient none)))
          true
        )

        ;; Reset owed amounts
        (map-set positions
          { position-id: position-id }
          (merge position { tokens-owed-x: u0, tokens-owed-y: u0 })
        )

        (ok (tuple (amount-x amount-x) (amount-y amount-y)))
      )
    )
  )
)

;; ===========================================
;; SWAPPING
;; ===========================================

(define-public (swap
  (token-in principal)
  (token-out principal)
  (amount-in uint)
  (min-amount-out uint)
  (recipient principal)
)
  (begin
    (check-not-paused)
    (asserts! (var-get is-initialized) ERR_INVALID_INPUT)
    (asserts! (> amount-in u0) ERR_INVALID_INPUT)

    (let ((zero-for-one (is-eq token-in (var-get pool-token-x))))
      (asserts! (if zero-for-one
                   (is-eq token-out (var-get pool-token-y))
                   (is-eq token-out (var-get pool-token-x))) ERR_INVALID_INPUT)

      ;; Execute swap
      (let ((result (try! (execute-swap zero-for-one amount-in u0))))
        (let ((amount-out (get amount-out result)))
          (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_EXCEEDED)

          ;; Transfer tokens
          (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
          (try! (as-contract (contract-call? token-out transfer amount-out tx-sender recipient none)))

          (ok amount-out)
        )
      )
    )
  )
)

(define-private (execute-swap (zero-for-one bool) (amount-specified uint) (sqrt-price-limit-x96 uint))
  (let ((current-sqrt-price (var-get sqrt-price-x96))
        (current-liquidity (var-get liquidity)))

    ;; Validate price limit
    (let ((min-sqrt-price (unwrap! (contract-call? .math-lib-concentrated tick-to-sqrt-price-x96 MIN_TICK) ERR_INVALID_INPUT))
(max-sqrt-price (unwrap! (contract-call? .math-lib-concentrated tick-to-sqrt-price-x96 MAX_TICK) ERR_INVALID_INPUT)))

      (asserts! (if zero-for-one
                   (or (is-eq sqrt-price-limit-x96 u0) (> sqrt-price-limit-x96 min-sqrt-price))
                   (or (is-eq sqrt-price-limit-x96 u0) (< sqrt-price-limit-x96 max-sqrt-price))) ERR_INVALID_INPUT)

      ;; Calculate swap result
      (let ((amount-out (unwrap! (contract-call? .math-lib-concentrated get-amount-out
                                                 current-sqrt-price
                                                 current-liquidity
                                                 amount-specified
                                                 zero-for-one) ERR_INVALID_INPUT))
            (new-sqrt-price (unwrap! (contract-call? .math-lib-concentrated get-next-sqrt-price-from-input
                                                     current-sqrt-price
                                                     current-liquidity
                                                     amount-specified
                                                     zero-for-one) ERR_INVALID_INPUT)))

        ;; Calculate fees
        (let ((fee-amount (/ (* amount-specified (var-get fee-tier)) u10000))
              (protocol-fee-amount (/ (* fee-amount PROTOCOL_FEE) u10000))
              (new-tick (unwrap! (contract-call? .math-lib-concentrated sqrt-price-x96-to-tick new-sqrt-price) ERR_INVALID_INPUT)))

          ;; Update state
          (var-set sqrt-price-x96 new-sqrt-price)
          (var-set current-tick new-tick)

          ;; Update fee tracking
          (if zero-for-one
            (begin
              (var-set fee-growth-global-x (+ (var-get fee-growth-global-x)
                                            (/ (* (- fee-amount protocol-fee-amount) PRECISION) current-liquidity)))
              (var-set protocol-fees-x (+ (var-get protocol-fees-x) protocol-fee-amount)))
            (begin
              (var-set fee-growth-global-y (+ (var-get fee-growth-global-y)
                                            (/ (* (- fee-amount protocol-fee-amount) PRECISION) current-liquidity)))
              (var-set protocol-fees-y (+ (var-get protocol-fees-y) protocol-fee-amount))))

          (ok (tuple (amount-in amount-specified) (amount-out amount-out) (fee fee-amount)))
        )
      )
    )
  )
)

;; ===========================================
;; POOL TRAIT IMPLEMENTATION
;; ===========================================

(define-read-only (get-tokens)
  (ok (tuple (token-x (var-get pool-token-x)) (token-y (var-get pool-token-y))))
)

(define-read-only (get-fee)
  (ok (var-get fee-tier))
)

(define-read-only (get-liquidity (token principal))
  (let ((token-x (var-get pool-token-x))
        (token-y (var-get pool-token-y)))
    (asserts! (or (is-eq token token-x) (is-eq token token-y)) ERR_INVALID_INPUT)
    (if (is-eq token token-x)
      (ok (var-get protocol-fees-x)) ;; Simplified - should calculate actual reserves
      (ok (var-get protocol-fees-y))
    )
  )
)

(define-read-only (get-amount-out (token-in principal) (token-out principal) (amount-in uint))
  (let ((zero-for-one (is-eq token-in (var-get pool-token-x))))
    (asserts! (if zero-for-one
                 (is-eq token-out (var-get pool-token-y))
                 (is-eq token-out (var-get pool-token-x))) ERR_INVALID_INPUT)
    (contract-call? .math-lib-concentrated get-amount-out
                    (var-get sqrt-price-x96)
                    (var-get liquidity)
                    amount-in
                    zero-for-one)
  )
)

(define-read-only (get-amount-in (token-in principal) (token-out principal) (amount-out uint))
  ;; Simplified - should implement proper calculation
  (ok amount-out)
)

;; ===========================================
;; POOL TRAIT IMPLEMENTATION
;; ===========================================

(define-public (add-liquidity (provider principal) (token-amount uint) (stx-amount uint))
  ;; For concentrated liquidity, this is a simplified wrapper
  ;; In production, would handle both token types appropriately
  (begin
    (check-not-paused)
    (asserts! (var-get is-initialized) ERR_INVALID_INPUT)
    ;; Simplified implementation - would need proper token handling
    (ok u0)
  )
)

(define-public (remove-liquidity (provider principal) (liquidity-amount uint))
  ;; For concentrated liquidity, this is a simplified wrapper
  (begin
    (check-not-paused)
    (asserts! (var-get is-initialized) ERR_INVALID_INPUT)
    ;; Simplified implementation - would need proper token handling
    (ok (tuple (token-amount u0) (stx-amount u0)))
  )
)

(define-public (swap (sender principal) (token-in principal) (token-out principal) (amount-in uint) (min-out uint))
  ;; Use existing execute-swap function directly to avoid recursion
  (begin
    (check-not-paused)
    (asserts! (var-get is-initialized) ERR_INVALID_INPUT)
    (asserts! (> amount-in u0) ERR_INVALID_INPUT)

    (let ((zero-for-one (is-eq token-in (var-get pool-token-x))))
      (asserts! (if zero-for-one
                   (is-eq token-out (var-get pool-token-y))
                   (is-eq token-out (var-get pool-token-x))) ERR_INVALID_INPUT)

      ;; Execute swap using existing logic
      (let ((result (try! (execute-swap zero-for-one amount-in u0))))
        (let ((amount-out (get amount-out result)))
          (asserts! (>= amount-out min-out) ERR_SLIPPAGE_EXCEEDED)

          ;; Transfer tokens
          (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
          (try! (as-contract (contract-call? token-out transfer amount-out tx-sender sender none)))

          (ok amount-out)
        )
      )
    )
  )
)

(define-read-only (get-reserves)
  ;; Return current reserves (simplified)
  (ok (tuple (token-reserve (var-get protocol-fees-x)) (stx-reserve (var-get protocol-fees-y))))
)

(define-read-only (get-pool-info)
  ;; Return pool information in trait-compatible format
  (ok (tuple (total-liquidity (var-get liquidity)) (fee-rate (var-get fee-tier))))
)

(define-private (update-tick (tick-idx int) (liquidity-delta uint))
  (let ((tick-data (default-to
                    {
                      liquidity-gross: u0,
                      liquidity-net: i0,
                      fee-growth-outside-x: u0,
                      fee-growth-outside-y: u0,
                      initialized: false
                    }
                    (map-get? ticks { tick: tick-idx }))))
    (let ((new-liquidity-gross (+ (get liquidity-gross tick-data) liquidity-delta))
          (new-liquidity-net (+ (get liquidity-net tick-data) (to-int liquidity-delta))))

      (map-set ticks
        { tick: tick-idx }
        {
          liquidity-gross: new-liquidity-gross,
          liquidity-net: new-liquidity-net,
          fee-growth-outside-x: (get fee-growth-outside-x tick-data),
          fee-growth-outside-y: (get fee-growth-outside-y tick-data),
          initialized: true
        }
      )
    )
  )
)

;; ===========================================
;; FEE CALCULATIONS
;; ===========================================

(define-private (calculate-fees-earned (position {owner: principal, tick-lower: int, tick-upper: int, liquidity: uint, fee-growth-inside-x: uint, fee-growth-inside-y: uint, tokens-owed-x: uint, tokens-owed-y: uint}))
  (let ((fee-growth-inside-x-new (get-fee-growth-inside (get tick-lower position) (get tick-upper position) true))
        (fee-growth-inside-y-new (get-fee-growth-inside (get tick-lower position) (get tick-upper position) false)))

    (let ((fees-x (/ (* (get liquidity position) (- fee-growth-inside-x-new (get fee-growth-inside-x position))) PRECISION))
          (fees-y (/ (* (get liquidity position) (- fee-growth-inside-y-new (get fee-growth-inside-y position))) PRECISION)))

      (tuple (fees-x fees-x) (fees-y fees-y))
    )
  )
)

(define-private (get-fee-growth-inside (tick-lower int) (tick-upper int) (is-token-x bool))
  (let ((global-growth (if is-token-x (var-get fee-growth-global-x) (var-get fee-growth-global-y)))
        (lower-outside (get-fee-growth-outside tick-lower is-token-x))
        (upper-outside (get-fee-growth-outside tick-upper is-token-x))
        (current-tick (var-get current-tick)))

    (let ((growth-below (if (< current-tick tick-lower)
                          (- global-growth lower-outside)
                          lower-outside))
          (growth-above (if (>= current-tick tick-upper)
                          (- global-growth upper-outside)
                          upper-outside)))

      (- (- global-growth growth-below) growth-above)
    )
  )
)

(define-private (get-fee-growth-outside (tick int) (is-token-x bool))
  (let ((tick-data (default-to
                    {
                      liquidity-gross: u0,
                      liquidity-net: i0,
                      fee-growth-outside-x: u0,
                      fee-growth-outside-y: u0,
                      initialized: false
                    }
                    (map-get? ticks { tick: tick }))))
    (if is-token-x
      (get fee-growth-outside-x tick-data)
      (get fee-growth-outside-y tick-data)
    )
  )
)

;; ===========================================
;; READ-ONLY FUNCTIONS
;; ===========================================

(define-read-only (get-pool-info)
  (ok (tuple
    (token-x (var-get pool-token-x))
    (token-y (var-get pool-token-y))
    (fee-tier (var-get fee-tier))
    (liquidity (var-get liquidity))
    (sqrt-price-x96 (var-get sqrt-price-x96))
    (current-tick (var-get current-tick))
    (tick-spacing (var-get tick-spacing))
  ))
)

(define-read-only (get-position (position-id uint))
  (match (map-get? positions { position-id: position-id })
    position (ok position)
    (err ERR_POSITION_NOT_FOUND)
  )
)

(define-read-only (get-tick (tick-idx int))
  (match (map-get? ticks { tick: tick-idx })
    tick-data (ok tick-data)
    (ok {
      liquidity-gross: u0,
      liquidity-net: i0,
      fee-growth-outside-x: u0,
      fee-growth-outside-y: u0,
      initialized: false
    })
  )
)

(define-read-only (get-protocol-fees)
  (ok (tuple (fees-x (var-get protocol-fees-x)) (fees-y (var-get protocol-fees-y))))
)