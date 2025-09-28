;; concentrated-liquidity-pool.clar
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

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait pool-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pool-trait)
(use-trait math-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.math-trait)
(use-trait error-codes-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.error-codes-trait)
(use-trait nft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.nft-trait)

(use-trait err-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.errors.err-trait)

;; Constants
(define-constant Q128 u340282366920938463463374607431768211456)

;; Data Maps
(
define-map pools
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


;; @desc Adds liquidity to an existing concentrated liquidity pool.
;; @param pool-id The ID of the pool to add liquidity to.
;; @param amount-x-desired The desired amount of token-x to provide.
;; @param amount-y-desired The desired amount of token-y to provide.
;; @param amount-x-min The minimum acceptable amount of token-x to provide (slippage control).
;; @param amount-y-min The minimum acceptable amount of token-y to provide (slippage control).
;; @param recipient The principal of the recipient for the position NFT.
;; @returns An `(ok {tokens-minted: uint, token-a-used: uint, token-b-used: uint})` result containing the liquidity minted and tokens used, or an error.
(define-public (add-liquidity (pool-id uint) (amount-x-desired uint) (amount-y-desired uint) (amount-x-min uint) (amount-y-min uint) (recipient principal))
  "Adds liquidity to a concentrated liquidity pool within a specified price range.
  This function mints a new position NFT representing the provided liquidity.

  @param pool-id The ID of the pool to add liquidity to.
  @param amount-x-desired The desired amount of token-x to provide.
  @param amount-y-desired The desired amount of token-y to provide.
  @param amount-x-min The minimum acceptable amount of token-x to provide (slippage control).
  @param amount-y-min The minimum acceptable amount of token-y to provide (slippage control).
  @param recipient The principal of the recipient for the position NFT.
  @returns An `(ok {tokens-minted: uint, token-a-used: uint, token-b-used: uint})` result containing the liquidity minted and tokens used, or an error.
  "

;; @desc Removes liquidity from an existing concentrated liquidity position.
;; @param position-id The ID of the position to remove liquidity from.
;; @param liquidity-amount The amount of liquidity to remove from the position.
;; @param recipient The principal of the recipient for the returned tokens.
;; @returns An `(ok {token-a-returned: uint, token-b-returned: uint})` result containing the amounts of tokens returned, or an error.
(define-public (remove-liquidity (position-id uint) (liquidity-amount uint) (recipient principal))
  "Removes liquidity from a concentrated liquidity pool and burns the corresponding position NFT.
  The tokens are transferred back to the recipient.

  @param position-id The ID of the position to remove liquidity from.
  @param liquidity-amount The amount of liquidity to remove from the position.
  @param recipient The principal of the recipient for the returned tokens.
  @returns An `(ok {token-a-returned: uint, token-b-returned: uint})` result containing the amounts of tokens returned, or an error.
  "

;; @desc Retrieves the current reserves of token-x and token-y for a given pool.
;; @param pool-id The ID of the pool.
;; @returns An `(ok {reserve-a: uint, reserve-b: uint})` result containing the reserves, or an error.
(define-public (get-reserves (pool-id uint))
  "Retrieves the current reserves (balances) of token-x and token-y held by a specific concentrated liquidity pool.

  @param pool-id The ID of the pool to query.
  @returns An `(ok {reserve-a: uint, reserve-b: uint})` result containing the current balances of token-x and token-y, or an error if the pool does not exist.
  "

  ;; @desc Retrieves the total liquidity supply for a given pool.
;; @param pool-id The ID of the pool.
;; @returns An `(ok uint)` result containing the total liquidity, or an error.
(define-public (get-total-supply (pool-id uint))
  "Retrieves the total liquidity currently managed by a specific concentrated liquidity pool.

  @param pool-id The ID of the pool to query.
  @returns An `(ok uint)` result containing the total liquidity, or an error if the pool does not exist.
  "

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
  "Creates a new concentrated liquidity pool with specified parameters.
  This function is typically called by a factory contract to deploy new pools.
  It initializes the pool's state, including the tokens, fees, tick spacing, and initial price.

  @param token-a The SIP-010 trait for the first token in the pool.
  @param token-b The SIP-010 trait for the second token in the pool.
  @param factory-address The principal of the factory contract that is authorized to create pools.
  @param fee-bps The fee percentage for swaps in basis points (e.g., u30 for 0.3%).
  @param tick-spacing The spacing between ticks, determining the granularity of liquidity ranges.
  @param start-tick The initial lower tick for the pool's active liquidity range.
  @param end-tick The initial upper tick for the pool's active liquidity range.
  @param initial-price The initial square root price of the pool, used to set the starting price.
  @returns An `(ok uint)` result containing the ID of the newly created pool, or an error if unauthorized.
  "
  (let
    (
      (current-pool-id (var-get next-pool-id))
    )
    (asserts! (is-eq tx-sender factory-address) (err-trait-err ERR_UNAUTHORIZED))
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
(use-trait math-lib-concentrated-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated)
(define-read-only (get-sqrt-price-from-tick (tick int))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-sqrt-ratio-at-tick tick)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math.math-lib-concentrated get-tick-at-sqrt-ratio sqrt-price)
)

(define-read-only (get-tick-from