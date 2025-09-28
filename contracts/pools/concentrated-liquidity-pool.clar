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
(define-read-only (get-sqrt-price-from-tick (tick int))
  "Calculates the square root price corresponding to a given tick.
  This function is crucial for converting between tick-based price representation and square root price.

  @param tick The integer tick value.
  @returns An `(ok uint)` result containing the calculated square root price, or an error if the tick is invalid.
  "

;; @desc Calculates the tick from a given square root price.
;; @param sqrt-price The square root price to convert.
;; @returns An `(ok int)` result containing the tick, or an error.
(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  "Calculates the tick value corresponding to a given square root price.
  This function is essential for converting square root prices back to tick-based representation.

  @param sqrt-price The square root price to convert.
  @returns An `(ok int)` result containing the calculated tick, or an error if the square root price is invalid.
  "

;; @desc Calculates the amount of liquidity for given token amounts and price range.
;; @param sqrt-price-current The current square root price of the pool.
;; @param sqrt-price-lower The square root price at the lower tick.
;; @param sqrt-price-upper The square root price at the upper tick.
;; @param amount-x The amount of token-x.
;; @param amount-y The amount of token-y.
;; @returns An `(ok uint)` result containing the calculated liquidity, or an error.
(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (amount-x uint) (amount-y uint))
  "Calculates the amount of liquidity that can be provided for given token amounts within a specific price range.
  This function is used to determine the liquidity value based on the current price, lower tick, upper tick, and the amounts of token-x and token-y.

  @param sqrt-price-current The current square root price of the pool.
  @param sqrt-price-lower The square root price at the lower tick of the position.
  @param sqrt-price-upper The square root price at the upper tick of the position.
  @param amount-x The amount of token-x to consider.
  @param amount-y The amount of token-y to consider.
  @returns An `(ok uint)` result containing the calculated liquidity, or an error if the liquidity calculation fails.
  "

;; @desc Calculates the amount of token-x for a given liquidity and price range.
;; @param liquidity The liquidity amount.
;; @param sqrt-price-current The current square root price of the pool.
;; @param sqrt-price-lower The square root price at the lower tick.
;; @param sqrt-price-upper The square root price at the upper tick.
;; @returns An `(ok uint)` result containing the calculated amount of token-x, or an error.
(define-read-only (calculate-amount-x (liquidity uint) (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
  "Calculates the amount of token-x required or returned for a given liquidity amount within a specific price range.
  This function is used in both adding and removing liquidity to determine the token-x component.

  @param liquidity The liquidity amount to consider.
  @param sqrt-price-current The current square root price of the pool.
  @param sqrt-price-lower The square root price at the lower tick of the position.
  @param sqrt-price-upper The square root price at the upper tick of the position.
  @returns An `(ok uint)` result containing the calculated amount of token-x, or an error if the calculation fails.
  "

;; @desc Calculates the amount of token-y for a given liquidity and price range.
;; @param liquidity The liquidity amount.
;; @param sqrt-price-current The current square root price of the pool.
;; @param sqrt-price-lower The square root price at the lower tick.
;; @param sqrt-price-upper The square root price at the upper tick.
;; @returns An `(ok uint)` result containing the calculated amount of token-y, or an error.
(define-read-only (calculate-amount-y (liquidity uint) (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
  "Calculates the amount of token-y required or returned for a given liquidity amount within a specific price range.
  This function is used in both adding and removing liquidity to determine the token-y component.

  @param liquidity The liquidity amount to consider.
  @param sqrt-price-current The current square root price of the pool.
  @param sqrt-price-lower The square root price at the lower tick of the position.
  @param sqrt-price-upper The square root price at the upper tick of the position.
  @returns An `(ok uint)` result containing the calculated amount of token-y, or an error if the calculation fails.
  "

(define-non-fungible-token position-nft uint)

;; @desc Mints a new concentrated liquidity position.
;; This function allows a user to provide liquidity to a concentrated liquidity pool within a specified price range (defined by `tick-lower` and `tick-upper`).
;; It calculates the liquidity to be minted based on the desired token amounts and the current pool state, and transfers the tokens from the sender to the pool.
;; A non-fungible token (NFT) representing the position is minted to the sender.
;; @param pool-id The ID of the pool to add liquidity to.
;; @param tick-lower The lower tick of the price range for the position.
;; @param tick-upper The upper tick of the price range for the position.
;; @param amount-x-desired The desired amount of token-x to provide.
;; @param amount-y-desired The desired amount of token-y to provide.
;; @param amount-x-min The minimum acceptable amount of token-x to provide (slippage control).
;; @param amount-y-min The minimum acceptable amount of token-y to provide (slippage control).
;; @returns An `(ok uint)` result containing the ID of the newly minted position, or an error if the operation fails.
(define-public (mint-position (pool-id uint) (tick-lower int) (tick-upper int) (amount-x-desired uint) (amount-y-desired uint) (amount-x-min uint) (amount-y-min uint))
  "Mints a new concentrated liquidity position.
  This function allows a user to provide liquidity to a concentrated liquidity pool within a specified price range (defined by `tick-lower` and `tick-upper`).
  It calculates the liquidity to be minted based on the desired token amounts and the current pool state, and transfers the tokens from the sender to the pool.
  A non-fungible token (NFT) representing the position is minted to the sender.

  @param pool-id The ID of the pool to add liquidity to.
  @param tick-lower The lower tick of the price range for the position.
  @param tick-upper The upper tick of the price range for the position.
  @param amount-x-desired The desired amount of token-x to provide.
  @param amount-y-desired The desired amount of token-y to provide.
  @param amount-x-min The minimum acceptable amount of token-x to provide (slippage control).
  @param amount-y-min The minimum acceptable amount of token-y to provide (slippage control).
  @returns An `(ok uint)` result containing the ID of the newly minted position, or an error if the operation fails.
  "        tick-lower: tick-lower,
        tick-upper: tick-upper,
        liquidity: liquidity,
        amount-x: amount-x,
        amount-y: amount-y,
        fee-growth-inside-last-x: u0,
        fee-growth-inside-last-y: u0
      }
    )
    (var-set next-position-id (+ position-id u1))
    (ok position-id)
  )
)

;; @desc Collects accumulated fees for a given position.
;; @param position-id The ID of the position to collect fees from.
;; @returns An `(ok {fees-x: uint, fees-y: uint})` result containing the collected fees for token-x and token-y, or an error.
(define-public (collect-fees (position-id uint))
  "Collects accumulated trading fees for a specific concentrated liquidity position.
  The fees are calculated based on the global fee growth and the position's fee growth at the last collection.
  The collected fees are transferred to the position owner.

  @param position-id The ID of the position to collect fees from.
  @returns An `(ok {fees-x: uint, fees-y: uint})` result containing the collected fees for token-x and token-y, or an error if the position is invalid or the sender is not the owner.
  "

;; @desc Performs a token swap within the pool.
;; @param amount-in The amount of the input token.
;; @param token-in The principal of the input token.
;; @param recipient The principal of the recipient for the output token.
;; @returns An `(ok uint)` result containing the amount of the output token, or an error.
(define-public (swap (amount-in uint) (token-in principal) (recipient principal))
  "Performs a token swap within the concentrated liquidity pool.
  This function determines the direction of the swap (token-x to token-y or vice-versa) based on the `token-in` parameter and calls the appropriate internal swap function.

  @param amount-in The amount of the input token to swap.
  @param token-in The principal of the input token (either token-x or token-y).
  @param recipient The principal of the recipient for the output token.
  @returns An `(ok uint)` result containing the amount of the output token received, or an error if the swap fails.
  "

;; @desc Swaps token-y for token-x.
;; @param pool-id The ID of the pool.
;; @param amount-y-in The amount of token-y to swap in.
;; @param amount-x-min-out The minimum amount of token-x to receive.
;; @param recipient The principal of the recipient for token-x.
;; @returns An `(ok uint)` result containing the amount of token-x received, or an error.
(define-public (swap-y-for-x (pool-id uint) (amount-y-in uint) (amount-x-min-out uint) (recipient principal))
    (let
      (
        (pool (unwrap! (map-get? pools {pool-id: pool-id}) ERR_INVALID_POSITION))
        (token-x (get token-x pool))
        (token-y (get token-y pool))
        (fee-bps (get fee-bps pool))
        (current-sqrt-price (get current-sqrt-price pool))
        (liquidity (get liquidity pool))

        ;; Calculate fee
        (fee-amount (/ (* amount-y-in fee-bps) u10000))
        (amount-y-after-fee (- amount-y-in fee-amount))

        (new-sqrt-price (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-new-sqrt-price current-sqrt-price liquidity amount-y-after-fee) ERR_SWAP_FAILED))
        (amount-x-out (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-x-out current-sqrt-price new-sqrt-price liquidity) ERR_SWAP_FAILED))

        ;; Update global fee growth
        (new-fee-growth-global-y (+ (get fee-growth-global-y pool) (/ (* fee-amount Q128) liquidity)))
      )
      (asserts! (> amount-y-in u0) ERR_INVALID_AMOUNT)

      ;; Transfer token-y from sender to contract
      (try! (contract-call? token-y transfer amount-y-in tx-sender (as-contract tx-sender)))

      (asserts! (>= amount-x-out amount-x-min-out) ERR_INSUFFICIENT_OUTPUT)

      ;; Transfer token-x from contract to recipient
      (try! (contract-call? token-x transfer amount-x-out (as-contract tx-sender) recipient))

      ;; Update pool state
      (map-set pools {pool-id: pool-id} (merge pool {
        current-sqrt-price: new-sqrt-price,
        fee-growth-global-y: new-fee-growth-global-y
      }))

      (ok amount-x-out)
    )
  )

;; @desc Swaps token-x for token-y.
;; @param pool-id The ID of the pool.
;; @param amount-x-in The amount of token-x to swap in.
;; @param amount-y-min-out The minimum amount of token-y to receive.
;; @param recipient The principal of the recipient for token-y.
;; @returns An `(ok uint)` result containing the amount of token-y received, or an error.
(define-public (swap-x-for-y (pool-id uint) (amount-x-in uint) (amount-y-min-out uint) (recipient principal))
  (let
    (
      (pool (unwrap! (map-get? pools {pool-id: pool-id}) (err-trait-err ERR_INVALID_POSITION)))
      (token-x (get token-x pool))
      (token-y (get token-y pool))
      (fee-bps (get fee-bps pool))
      (current-sqrt-price (get current-sqrt-price pool))
      (liquidity (get liquidity pool))

      ;; Calculate fee
      (fee-amount (/ (* amount-x-in fee-bps) u10000))
      (amount-x-after-fee (- amount-x-in fee-amount))

      (new-sqrt-price (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-new-sqrt-price current-sqrt-price liquidity amount-x-after-fee) (err-trait-err ERR_SWAP_FAILED)))
      (amount-y-out (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-y-out current-sqrt-price new-sqrt-price liquidity) (err-trait-err ERR_SWAP_FAILED)))

      ;; Update global fee growth
      (new-fee-growth-global-x (+ (get fee-growth-global-x pool) (/ (* fee-amount Q128) liquidity)))
    )
    (asserts! (> amount-x-in u0) (err-trait-err ERR_INVALID_AMOUNT))

    ;; Transfer token-x from sender to contract
    (try! (contract-call? token-x transfer amount-x-in tx-sender (as-contract tx-sender)))

    (asserts! (>= amount-y-out amount-y-min-out) (err-trait-err ERR_INSUFFICIENT_OUTPUT))

    ;; Transfer token-y from contract to recipient
    (try! (contract-call? token-y transfer amount-y-out (as-contract tx-sender) recipient))

    ;; Update pool state
    (map-set pools {pool-id: pool-id} (merge pool {
      current-sqrt-price: new-sqrt-price,
      fee-growth-global-x: new-fee-growth-global-x
    }))

    (ok amount-y-out)
  )
)

;; @desc Burns a concentrated liquidity position, removing liquidity from the pool.
;; This function allows a user to remove liquidity from a previously minted concentrated liquidity position.
;; It calculates the amounts of token-x and token-y to be returned based on the liquidity amount to remove and the current pool state.
;; The corresponding tokens are transferred back to the sender, and the position NFT is burned.
;; @param position-id The ID of the position to burn.
;; @param liquidity-amount The amount of liquidity to remove from the position.
;; @returns An `(ok {amount-x: uint, amount-y: uint})` result containing the amounts of token-x and token-y returned, or an error.
(define-public (burn-position (position-id uint) (liquidity-amount uint))
  (let
    (
      (position (unwrap! (map-get? positions {position-id: position-id}) ERR_INVALID_POSITION))
      (pool (unwrap! (map-get? pools {pool-id: (get pool-id position)}) ERR_INVALID_POSITION))
      (sqrt-price-current (get current-sqrt-price pool))
      (sqrt-price-lower (unwrap! (get-sqrt-price-from-tick (get tick-lower position)) ERR_INVALID_TICK))
      (sqrt-price-upper (unwrap! (get-sqrt-price-from-tick (get tick-upper position)) ERR_INVALID_TICK))
      (amount-x (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-x liquidity-amount sqrt-price-current sqrt-price-lower sqrt-price-upper) ERR_INVALID_AMOUNT))
      (amount-y (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-y liquidity-amount sqrt-price-current sqrt-price-lower sqrt-price-upper) ERR_INVALID_AMOUNT))
    )
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (>= (get liquidity position) liquidity-amount) ERR_INSUFFICIENT_LIQUIDITY)

    ;; Transfer tokens back to user
    (try! (contract-call? (get token-x pool) transfer amount-x (as-contract tx-sender) tx-sender))
    (try! (contract-call? (get token-y pool) transfer amount-y (as-contract tx-sender) tx-sender))

    ;; Burn NFT
    (try! (nft-burn position-nft position-id tx-sender))

    ;; Update position liquidity
    (map-set positions {position-id: position-id} (merge position {liquidity: (- (get liquidity position) liquidity-amount)}))

    (ok {amount-x: amount-x, amount-y: amount-y})
  )
)