;; concentrated
;; Implements a concentrated liquidity pool for the Conxian DEX.
;;
;; Overview:
;; This contract provides a concentrated liquidity pool implementation, allowing liquidity providers to
;; allocate capital within specific price ranges (ticks) for higher capital efficiency. It supports:
;; - Position management (mint/burn)
;; - Swaps with optimized routing
;; - Fee collection
;; - Integration with SIP-010 tokens and advanced math libraries.
;;
;; Key Features:
;; - Tick-based liquidity allocation
;; - NFT-style position tracking
;; - Advanced math for precise calculations
;; - Centralized error handling via `errors.clar`
;;
;; Dependencies:
;; - `sip-010-ft-trait` for token interactions
;; - `pool-trait` for DEX integration
;; - `math-trait` for calculations
;; - `error-codes-trait` for standardized errors
;; - `nft-trait` for position NFTs

(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)
(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)



;; Constants
(define-constant Q128 u340282366920938463463374607431768211455)

;; Data Maps
 (define-map pools
  {pool-id: uint}
  {
    token-x: <sip-010-ft-trait>,
    token-y: <sip-010-ft-trait>,
    factory: principal,
    fee-bps: uint,
    tick-spacing: uint,
    current-tick: int,
    current-sqrt-price: uint,
    liquidity: uint,
    fee-growth-global-x: uint,
    fee-growth-global-y: uint,
    start-tick: int,
    end-tick: int
  }
)

(define-map positions
  {position-id: uint}
  {
    owner: principal,
    pool-id: uint,
    tick-lower: int,
    tick-upper: int,
    liquidity: uint,
    amount-x: uint,
    amount-y: uint,
    fee-growth-inside-last-x: uint,
    fee-growth-inside-last-y: uint
  }
)

(define-data-var next-pool-id uint u0)
(define-data-var next-position-id uint u0)

;; Position NFT
(define-non-fungible-token position-nft position-id uint)

(define-private (mint-position (recipient principal) (position-id uint))
  (nft-mint? position-nft position-id recipient)
)

(define-private (transfer-position (sender principal) (recipient principal) (position-id uint))
  (nft-transfer? position-nft position-id sender recipient)
)

(define-private (burn-position (owner principal) (position-id uint))
  (nft-burn? position-nft position-id owner)
)

;; @desc Updates the liquidity and fee growth for a given tick.
;; @param tick The tick to update.
;; @param liquidity-delta The change in liquidity.
;; @param fee-growth-global0 The global fee growth for token0.
;; @param fee-growth-global1 The global fee growth for token1.
;; @param current-tick The current tick of the pool.
;; @returns A boolean indicating success.
(define-private (update-liquidity-and-fees (tick int) (liquidity-delta int) (fee-growth-global0 uint) (fee-growth-global1 uint) (current-tick int))
  (let
    (
      (current-tick-info (default-to {liquidity-gross: u0, liquidity-net: i0, fee-growth-outside0: u0, fee-growth-outside1: u0, tick-cumulative-outside: u0, seconds-per-liquidity-outside: u0, seconds-outside: u0, initialized: false} (map-get? ticks tick)))
      (new-liquidity-gross (+ (get liquidity-gross current-tick-info) (abs liquidity-delta)))
      (new-liquidity-net (+ (get liquidity-net current-tick-info) liquidity-delta))
      (new-fee-growth-outside0 (if (> tick current-tick) (get fee-growth-outside0 current-tick-info) (- fee-growth-global0 (get fee-growth-outside0 current-tick-info))))
      (new-fee-growth-outside1 (if (> tick current-tick) (get fee-growth-outside1 current-tick-info) (- fee-growth-global1 (get fee-growth-outside1 current-tick-info))))
    )
    (map-set ticks tick {
      liquidity-gross: new-liquidity-gross,
      liquidity-net: new-liquidity-net,
      fee-growth-outside0: new-fee-growth-outside0,
      fee-growth-outside1: new-fee-growth-outside1,
      tick-cumulative-outside: (get tick-cumulative-outside current-tick-info),
      seconds-per-liquidity-outside: (get seconds-per-liquidity-outside current-tick-info),
      seconds-outside: (get seconds-outside current-tick-info),
      initialized: true
    })
    (ok true)
  )
)

;; @desc Adds liquidity to an existing concentrated liquidity pool.
;; @param pool-id The ID of the pool to add liquidity to.
;; @param amount-x-desired The desired amount of token-x to provide.
;; @param amount-y-desired The desired amount of token-y to provide.
;; @param amount-x-min The minimum acceptable amount of token-x to provide (slippage control).
;; @param amount-y-min The minimum acceptable amount of token-y to provide (slippage control).
;; ;; @param recipient The principal of the recipient for the position NFT.
;; @returns An `(ok {tokens-minted: uint, token-a-used: uint, token-b-used: uint})` result containing the liquidity minted and tokens used, or an error.
(define-public (add-liquidity (pool-id uint) (amount-x-desired uint) (amount-y-desired uint) (amount-x-min uint) (amount-y-min uint) (recipient principal) (tick-lower int) (tick-upper int))
  ;; Adds liquidity to a concentrated liquidity pool within a specified price range.
  ;; This function mints a new position NFT representing the provided liquidity.
  ;;
  ;; @param pool-id The ID of the pool to add liquidity to.
  ;; @param amount-x-desired The desired amount of token-x to provide.
  ;; @param amount-y-desired The desired amount of token-y to provide.
  ;; @param amount-x-min The minimum acceptable amount of token-x to provide (slippage control).
  ;; @param amount-y-min The minimum acceptable amount of token-y to provide (slippage control).
  ;; @param recipient The principal of the recipient for the position NFT.
  ;; @param tick-lower The lower tick of the liquidity range.
  ;; @param tick-upper The upper tick of the liquidity range.
  ;; @returns An (ok {tokens-minted: uint, token-a-used: uint, token-b-used: uint, position-id: uint}) result containing the liquidity minted and tokens used, or an error.
  (let
    (
      (pool (try! (map-get? pools {pool-id: pool-id})))
      (current-position-id (var-get next-position-id))
      ;; Placeholder for actual liquidity calculation
      (liquidity-minted u100)
      (token-x-used amount-x-desired)
      (token-y-used amount-y-desired)
    )
    ;; Placeholder for actual liquidity calculation and token transfers
    (var-set next-position-id (+ current-position-id u1))
    (map-set positions
      {position-id: current-position-id}
      {
        owner: recipient,
        pool-id: pool-id,
        tick-lower: tick-lower,
        tick-upper: tick-upper,
        liquidity: liquidity-minted,
        amount-x: token-x-used,
        amount-y: token-y-used,
        fee-growth-inside-last-x: u0,
        fee-growth-inside-last-y: u0
      }
    )
    (try! (mint-position recipient current-position-id))
    (try! (update-liquidity-and-fees tick-lower (to-int liquidity-minted) (get fee-growth-global-x pool) (get fee-growth-global-y pool) (get current-tick pool)))
    (try! (update-liquidity-and-fees tick-upper (to-int (- u0 liquidity-minted)) (get fee-growth-global-x pool) (get fee-growth-global-y pool) (get current-tick pool)))
    (ok {tokens-minted: liquidity-minted, token-a-used: token-x-used, token-b-used: token-y-used, position-id: current-position-id})
  )
)

;; @desc Removes liquidity from a concentrated liquidity pool.
;; @param position-id The ID of the position NFT to burn.
;; @param amount-x-min The minimum acceptable amount of token-x to receive.
;; @param amount-y-min The minimum acceptable amount of token-y to receive.
;; @param recipient The principal of the recipient for the tokens.
;; @returns An `(ok {amount-x: uint, amount-y: uint})` result containing the tokens received, or an error.
(define-public (remove-liquidity (position-id uint) (amount-x-min uint) (amount-y-min uint) (recipient principal))
  ;; Removes liquidity from a concentrated liquidity pool by burning a position NFT.
  ;; This function calculates the tokens owed for the given position and transfers them to the recipient.
  ;;
  ;; @param position-id The ID of the position NFT to burn.
  ;; @param amount-x-min The minimum acceptable amount of token-x to receive (slippage control).
  ;; @param amount-y-min The minimum acceptable amount of token-y to receive (slippage control).
  ;; @param recipient The principal of the recipient for the tokens.
  ;; @returns An (ok {amount-x: uint, amount-y: uint}) result containing the tokens received, or an error.
  (let
    (
      (position (try! (map-get? positions {position-id: position-id})))
      ;; Placeholder for actual token calculation
      (amount-x-received u100)
      (amount-y-received u100)
    )
    (asserts! (is-eq (get owner position) tx-sender) (err u403)) ;; ERR_UNAUTHORIZED
    ;; Placeholder for actual token transfers
    (try! (burn-position tx-sender position-id))
    (map-delete positions {position-id: position-id})
    (let ((pool (try! (map-get? pools {pool-id: (get pool-id position)}))))
      (try! (update-liquidity-and-fees (get tick-lower position) (to-int (- u0 (get liquidity position))) (get fee-growth-global-x pool) (get fee-growth-global-y pool) (get current-tick pool))))
    (let ((pool (try! (map-get? pools {pool-id: (get pool-id position)}))))
      (try! (update-liquidity-and-fees (get tick-upper position) (to-int (get liquidity position)) (get fee-growth-global-x pool) (get fee-growth-global-y pool) (get current-tick pool))))
    (ok {amount-x: amount-x-received, amount-y: amount-y-received})
  )
)

;; @desc Retrieves the current reserves of token-x and token-y for a given pool.
;; @param pool-id The ID of the pool.
;; @returns An `(ok {reserve-a: uint, reserve-b: uint})` result containing the reserves, or an error.
(define-public (get-reserves (pool-id uint))
  ;; Retrieves the current reserves (balances) of token-x and token-y held by a specific concentrated liquidity pool.
  ;; @param pool-id The ID of the pool to query.
  ;; @returns An (ok {reserve-a: uint, reserve-b: uint}) result containing the current balances of token-x and token-y, or an error if the pool does not exist.
  ;;

  ;; @desc Retrieves the total liquidity supply for a given pool.
;; @param pool-id The ID of the pool.
;; @returns An `(ok uint)` result containing the total liquidity, or an error.
(define-public (get-total-supply (pool-id uint))
  ;; Retrieves the total liquidity currently managed by a specific concentrated liquidity pool.
  ;; @param pool-id The ID of the pool to query.
  ;; @returns An `(ok uint)` result containing the total liquidity, or an error if the pool does not exist.

;; Public functions
;; @desc Creates a new concentrated liquidity pool.
;; @param token-a The SIP-010 trait for the first token.
;; @param token-b The SIP-010 trait for the second token.
;; @param factory-address The address of the factory contract deploying this pool.
;; @param fee-bps The fee in basis points (e.g., 30 for 0.3%).
;; @param tick-spacing The spacing between ticks.
;; @param start-tick The initial lower tick for the pool.
;; @param end-tick The initial upper tick for the pool.
;; @param initial-price The initial square root price of the pool.
;; @returns An `(ok uint)` result containing the new pool ID, or an error.
;; ----------------------------------------------------------------------------------------------------
;; SWAP FUNCTION
;; ----------------------------------------------------------------------------------------------------
(define-public (swap
  (zero-for-one bool)
  (amount-specified uint)
  (limit-sqrt-price uint)
)
  (let (
    (pool-id (var-get next-pool-id))
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) (err ERR_POOL_NOT_FOUND)))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (fee-bps (get fee-bps pool))
    (current-sqrt-price (get current-sqrt-price pool))
    (current-tick (get current-tick pool))
    (liquidity (get liquidity pool))
    (fee-growth-global-x (get fee-growth-global-x pool))
    (fee-growth-global-y (get fee-growth-global-y pool))
    (amount-in u0)
    (amount-out u0)
    (amount-remaining amount-specified)
    (next-sqrt-price current-sqrt-price)
    (next-tick current-tick)
    (total-fee u0)
  )
    ;; Input validation
    (asserts! (not (is-eq amount-specified u0)) (err ERR_INVALID_AMOUNT))

    ;; Determine the direction of the swap and calculate the next price
    (if zero-for-one
      (begin
        (asserts! (> current-sqrt-price limit-sqrt-price) (err ERR_PRICE_LIMIT_REACHED))
        (let (
          (sqrt-price-target limit-sqrt-price)
          (amount-in-calc (unwrap! (contract-call? .math-lib-concentrated calculate-amount0-delta current-sqrt-price sqrt-price-target liquidity true) (err ERR_SWAP_FAILED)))
          (amount-out-calc (unwrap! (contract-call? .math-lib-concentrated calculate-amount1-delta current-sqrt-price sqrt-price-target liquidity false) (err ERR_SWAP_FAILED)))
        )
          (if (>= amount-remaining amount-in-calc)
            (begin
              (var-set amount-in amount-in-calc)
              (var-set amount-out amount-out-calc)
              (var-set next-sqrt-price sqrt-price-target)
            )
            (begin
              (var-set amount-in amount-remaining)
              (var-set next-sqrt-price (unwrap! (contract-call? .math-lib-concentrated get-next-sqrt-price-from-input current-sqrt-price liquidity amount-remaining true) (err ERR_SWAP_FAILED)))
              (var-set amount-out (unwrap! (contract-call? .math-lib-concentrated calculate-amount1-delta current-sqrt-price (var-get next-sqrt-price) liquidity false) (err ERR_SWAP_FAILED)))
            )
          )
        )
      )
      (begin
        (asserts! (< current-sqrt-price limit-sqrt-price) (err ERR_PRICE_LIMIT_REACHED))
        (let (
          (sqrt-price-target limit-sqrt-price)
          (amount-in-calc (unwrap! (contract-call? .math-lib-concentrated calculate-amount1-delta current-sqrt-price sqrt-price-target liquidity true) (err ERR_SWAP_FAILED)))
          (amount-out-calc (unwrap! (contract-call? .math-lib-concentrated calculate-amount0-delta current-sqrt-price sqrt-price-target liquidity false) (err ERR_SWAP_FAILED)))
        )
          (if (>= amount-remaining amount-in-calc)
            (begin
              (var-set amount-in amount-in-calc)
              (var-set amount-out amount-out-calc)
              (var-set next-sqrt-price sqrt-price-target)
            )
            (begin
              (var-set amount-in amount-remaining)
              (var-set next-sqrt-price (unwrap! (contract-call? .math-lib-concentrated get-next-sqrt-price-from-input current-sqrt-price liquidity amount-remaining false) (err ERR_SWAP_FAILED)))
              (var-set amount-out (unwrap! (contract-call? .math-lib-concentrated calculate-amount0-delta current-sqrt-price (var-get next-sqrt-price) liquidity false) (err ERR_SWAP_FAILED)))
            )
          )
        )
      )
    )

    ;; Calculate fee
    (var-set total-fee (unwrap! (contract-call? .math-lib-concentrated mul-div amount-in fee-bps u10000) (err ERR_SWAP_FAILED)))
    (var-set amount-in (- amount-in (var-get total-fee)))

    ;; Update pool state
    (map-set pools {pool-id: pool-id} (merge pool {
      current-sqrt-price: (var-get next-sqrt-price),
      current-tick: (unwrap! (contract-call? .math-lib-concentrated get-tick-from-sqrt-price (var-get next-sqrt-price) (get tick-spacing pool)) (err ERR_SWAP_FAILED)),
      fee-growth-global-x: (+ fee-growth-global-x (if zero-for-one (var-get total-fee) u0)),
      fee-growth-global-y: (+ fee-growth-global-y (if (not zero-for-one) (var-get total-fee) u0))
    }))

    ;; Transfer tokens
    (if zero-for-one
      (begin
        (unwrap! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)) (err ERR_SWAP_FAILED))
        (unwrap! (contract-call? token-y transfer amount-out (as-contract tx-sender) tx-sender) (err ERR_SWAP_FAILED))
      )
      (begin
        (unwrap! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)) (err ERR_SWAP_FAILED))
        (unwrap! (contract-call? token-x transfer amount-out (as-contract tx-sender) tx-sender) (err ERR_SWAP_FAILED))
      )
    )

    ;; Emit event
    (print (ok {type: "swap", pool-id: pool-id, zero-for-one: zero-for-one, amount-in: (var-get amount-in), amount-out: (var-get amount-out), next-sqrt-price: (var-get next-sqrt-price)}))

    (ok u1)
  )
)

;; ----------------------------------------------------------------------------------------------------
;; POOL TRAIT ADAPTER FUNCTIONS
;; ----------------------------------------------------------------------------------------------------

(define-public (add-liquidity-trait-adapter (amount-a uint) (amount-b uint) (recipient principal))
  (let (
    (pool-id (var-get next-pool-id))
    (result (add-liquidity pool-id amount-a amount-b u0 u0 recipient u0 u0))
  )
    (match result
      (ok (tuple (tokens-minted uint) (token-x-used uint) (token-y-used uint)) (ok (tuple (tokens-minted tokens-minted) (token-a-used token-x-used) (token-b-used token-b-used))))
      (err e (err e))
    )
  )
)

(define-public (remove-liquidity-trait-adapter (amount-lp uint) (sender principal))
  (let (
    (pool-id (var-get next-pool-id))
    (result (remove-liquidity pool-id amount-lp sender))
  )
    (match result
      (ok (tuple (token-x-withdrawn uint) (token-y-withdrawn uint)) (ok (tuple (token-a-withdrawn token-x-withdrawn) (token-b-withdrawn token-y-withdrawn))))
      (err e (err e))
    )
  )
)

(define-public (swap-trait-adapter (token-in <sip-010-ft-trait>)
                                   (token-out <sip-010-ft-trait>)
                                   (amount-in uint)
                                   (min-amount-out uint)
                                   (recipient principal))
  (let (
    (pool-id (var-get next-pool-id))
    (zero-for-one (if (is-eq token-in (get token-x (map-get? pools {pool-id: pool-id})))) true false))
    (result (swap pool-id zero-for-one amount-in u0))
  )
  (match result
    (ok (tuple (amount-in uint) (amount-out uint) (next-sqrt-price uint)) (ok (tuple (amount-in amount-in) (amount-out amount-out))))
    (err e (err e))
  )
)

(define-public (get-reserves-trait-adapter (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>))
  (let (
    (pool-id (var-get next-pool-id))
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) (err ERR_POOL_NOT_FOUND)))
  )
    (ok (tuple (reserve-a (get balance-x pool)) (reserve-b (get balance-y pool))))
  )
)

(define-public (get-total-supply-trait-adapter)
  (ok u0)
)

;; ----------------------------------------------------------------------------------------------------
;; CREATE POOL FUNCTION
;; ----------------------------------------------------------------------------------------------------
;; ----------------------------------------------------------------------------------------------------
;; COLLECT FEES FUNCTION
;; ----------------------------------------------------------------------------------------------------
(define-public (collect-fees
  (position-id uint)
)
  (let (
    (position (unwrap! (map-get? positions {position-id: position-id}) (err ERR_INVALID_POSITION)))
    (pool-id (get pool-id position))
    (pool (unwrap! (map-get? pools {pool-id: pool-id}) (err ERR_POOL_NOT_FOUND)))
    (token-x (get token-x pool))
    (token-y (get token-y pool))
    (tick-lower (get tick-lower position))
    (tick-upper (get tick-upper position))
    (liquidity (get liquidity position))
    (fee-growth-global-x (get fee-growth-global-x pool))
    (fee-growth-global-y (get fee-growth-global-y pool))
    (fee-growth-position-x (get fee-growth-position-x position))
    (fee-growth-position-y (get fee-growth-position-y position))
    (fees-owed-x u0)
    (fees-owed-y u0)
  )
    (asserts! (> liquidity u0) (err ERR_INVALID_POSITION))

    (let (
      (fee-growth-inside-x (unwrap! (contract-call? .math-lib-concentrated get-fee-growth-inside
        tick-lower
        tick-upper
        (get current-tick pool)
        fee-growth-global-x
        (get fee-growth-outside0 (unwrap! (map-get? ticks {pool-id: pool-id, tick: tick-lower}) (err ERR_INVALID_TICK)))
        (get fee-growth-outside0 (unwrap! (map-get? ticks {pool-id: pool-id, tick: tick-upper}) (err ERR_INVALID_TICK)))
      ) (err ERR_SWAP_FAILED)))
      (fee-growth-inside-y (unwrap! (contract-call? .math-lib-concentrated get-fee-growth-inside
        tick-lower
        tick-upper
        (get current-tick pool)
        fee-growth-global-y
        (get fee-growth-outside1 (unwrap! (map-get? ticks {pool-id: pool-id, tick: tick-lower}) (err ERR_INVALID_TICK)))
        (get fee-growth-outside1 (unwrap! (map-get? ticks {pool-id: pool-id, tick: tick-upper}) (err ERR_INVALID_TICK)))
      ) (err ERR_SWAP_FAILED)))
    )
      (var-set fees-owed-x (unwrap! (contract-call? .math-lib-concentrated mul-div liquidity (- fee-growth-inside-x fee-growth-position-x) Q128) (err ERR_SWAP_FAILED)))
      (var-set fees-owed-y (unwrap! (contract-call? .math-lib-concentrated mul-div liquidity (- fee-growth-inside-y fee-growth-position-y) Q128) (err ERR_SWAP_FAILED)))
    )

    ;; Update position
    (map-set positions {position-id: position-id} (merge position {
      fee-growth-position-x: fee-growth-global-x,
      fee-growth-position-y: fee-growth-global-y
    }))

    ;; Transfer fees
    (if (> (var-get fees-owed-x) u0)
      (unwrap! (contract-call? token-x transfer (var-get fees-owed-x) (as-contract tx-sender) tx-sender) (err ERR_SWAP_FAILED))
    )
    (if (> (var-get fees-owed-y) u0)
      (unwrap! (contract-call? token-y transfer (var-get fees-owed-y) (as-contract tx-sender) tx-sender) (err ERR_SWAP_FAILED))
    )

    ;; Emit event
    (print (ok {type: "collect-fees", position-id: position-id, fees-x: (var-get fees-owed-x), fees-y: (var-get fees-owed-y)}))

    (ok u1)
  )
)
;; CREATE POOL FUNCTION
;; ----------------------------------------------------------------------------------------------------
(define-public (create-pool
  (token-a <sip-010-ft-trait>)
  (token-b <sip-010-ft-trait>)
  (factory-address principal)
  (fee-bps uint)
  (tick-spacing uint)
  (start-tick int)
  (end-tick int)
  (initial-price uint)
)
  ;; Creates a new concentrated liquidity pool with specified parameters.
  ;; This function is typically called by a factory contract to deploy new pools.
  ;; It initializes the pool's state, including the tokens, fees, tick spacing, and initial price.
  ;;
  ;; @param token-a The SIP-010 trait for the first token in the pool.
  ;; @param token-b The SIP-010 trait for the second token in the pool.
  ;; @param factory-address The principal of the factory contract that is authorized to create pools.
  ;; @param fee-bps The fee percentage for swaps in basis points (e.g., u30 for 0.3%).
  ;; @param tick-spacing The spacing between ticks, determining the granularity of liquidity ranges.
  ;; @param start-tick The initial lower tick for the pool's active liquidity range.
  ;; @param end-tick The initial upper tick for the pool's active liquidity range.
  ;; @param initial-price The initial square root price of the pool, used to set the starting price.
  ;; @returns An (ok uint) result containing the ID of the newly created pool, or an error if unauthorized.
  (let
    (
      (current-pool-id (var-get next-pool-id))
    )
    (asserts! (is-eq tx-sender factory-address) (err ERR_UNAUTHORIZED))
    (map-set pools
      {pool-id: current-pool-id}
      {
        token-x: token-a,
        token-y: token-b,
        factory: factory-address,
        fee-bps: fee-bps,
        tick-spacing: tick-spacing,
        current-tick: start-tick,
        current-sqrt-price: initial-price,
        liquidity: u0,
        fee-growth-global-x: u0,
        fee-growth-global-y: u0,
        start-tick: start-tick,
        end-tick: end-tick
      }
    )
    (var-set next-pool-id (+ current-pool-id u1))
    (ok current-pool-id)
  )
)


;; Helper functions for tick-based liquidity management
;; @desc Calculates the square root price from a given tick.
;; @param tick The tick to convert.
;; @returns An `(ok uint)` result containing the square root price, or an error.

(define-read-only (get-sqrt-price-from-tick (tick int))
  (contract-call? .math.math-lib-concentrated get-sqrt-ratio-at-tick tick)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? .math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)































































































































































































































































































































 

