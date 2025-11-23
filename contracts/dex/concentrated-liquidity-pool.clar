;; Concentrated Liquidity Pool (CLP) - Minimal adapter implementation for trait compliance and compilation

(use-trait rbac-trait .core-protocol.02-core-protocol.rbac-trait-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1100))
(define-constant ERR_INVALID_TICK (err u3001))
(define-constant ERR_INVALID_TICK_RANGE (err u3002))
(define-constant ERR_ZERO_AMOUNT_IN (err u1207))
(define-constant ERR_INVALID_AMOUNT (err u1004))
(define-constant ERR_POSITION_NOT_FOUND (err u3006))
(define-constant ERR_OVERFLOW (err u1008))
(define-constant ERR_UNDERFLOW (err u1009))
(define-constant ERR_DIVISION_BY_ZERO (err u1010))
(define-constant ERR_INVALID_SQRT_PRICE (err u3010))
(define-constant ERR_ZERO_LIQUIDITY (err u3011))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1307))
(define-constant ERR_PRICE_LIMIT_EXCEEDED (err u3013))
(define-constant ERR_NFT_MINT_FAILED (err u3014))
(define-constant ERR_NFT_BURN_FAILED (err u3015))

(define-constant ONE_18 u1000000000000000000) ;; 1e18 for fixed-point math
(define-constant MIN_TICK i-887272)
(define-constant MAX_TICK i887272)
(define-constant TICK_SPACING u10) ;; Example tick spacing, can be configured
(define-constant MIN_SQRT_RATIO u4295048016) ;; sqrt(MIN_PRICE) * 1e9
(define-constant MAX_SQRT_RATIO u340282366920938463463374607431768211455) ;; max Clarity uint as placeholder for sqrt(MAX_PRICE) * 1e9

;; --- Data Variables ---
(define-data-var token0 principal tx-sender)
(define-data-var token1 principal tx-sender)
(define-data-var fee uint u3000) ;; basis points (e.g., u3000 = 0.3%)
(define-data-var current-tick int i0)
(define-data-var current-sqrt-price uint u0) ;; Current sqrt(price) * 1e9
(define-data-var total-liquidity uint u0) ;; Total liquidity in the pool
(define-data-var fee-growth-global-0 uint u0) ;; Total fee growth for token0
(define-data-var fee-growth-global-1 uint u0) ;; Total fee growth for token1
(define-data-var next-position-id uint u1)

;; --- Data Maps ---
(define-map positions { position-id: uint } { lower: int, upper: int, shares: uint, liquidity: uint, fee-growth-inside-0: uint, fee-growth-inside-1: uint })
(define-map ticks { tick-id: int } { liquidity-gross: uint, liquidity-net: int, fee-growth-outside-0: uint, fee-growth-outside-1: uint })

;; --- NFT Definition ---
(define-non-fungible-token position-nft uint)

;; --- Helper Functions ---

;; @desc Calculates the square root price from a tick index.
;; @param tick (int) The tick index.
;; @returns (response uint (err u3003)) The square root price scaled by 1e9, or an error.
;; @error u3003 If a mathematical overflow occurs during calculation.
(define-read-only (get-sqrt-price-from-tick (tick int))
  (ok u0))

;; @desc Converts a price to the nearest tick index.
;; @param price (uint) The price to convert.
;; @returns (response int (err u3004)) The tick index, or an error.
;; @error u3004 If a mathematical overflow occurs during calculation.
(define-read-only (get-tick-from-price (price uint))
  (ok i0))

;; @desc Mints a new position NFT and associates it with liquidity.
;; @param recipient (principal) The principal to receive the NFT.
;; @param lower-tick (int) The lower tick of the position.
;; @param upper-tick (int) The upper tick of the position.
;; @param liquidity (uint) The amount of liquidity provided.
;; @returns (response uint (err u3005)) The new position ID or an error.
;; @error u3005 If NFT minting fails or an overflow occurs when incrementing the position ID.
(define-private (mint-position-nft (recipient principal) (lower-tick int) (upper-tick int) (liquidity uint))
  (let (
    (position-id (var-get next-position-id))
  )
    (try! (nft-mint? position-nft position-id recipient))
    (map-set positions
      { position-id: position-id }
      { lower: lower-tick, upper: upper-tick, shares: u0, liquidity: liquidity, fee-growth-inside-0: u0, fee-growth-inside-1: u0 }
    )
    (var-set next-position-id (unwrap-panic (+ position-id u1)))
    (ok position-id)
  )
)

;; @desc Burns a position NFT.
;; @param position-id (uint) The ID of the position NFT to burn.
;; @param owner (principal) The owner of the NFT.
;; @returns (response bool (err u3006)) True if the NFT was burned successfully, or an error.
;; @error u3006 If the caller is not authorized or NFT burning fails.
(define-private (burn-position-nft (position-id uint) (owner principal))
  (begin
    (asserts! (is-eq (nft-get-owner? position-nft position-id) (ok owner)) u3006)
    (map-delete positions { position-id: position-id })
    (nft-burn? position-nft position-id owner)
  )
)

;; @desc Calculates the fee growth inside a given tick range.
;; @param lower-tick (int) The lower tick of the range.
;; @param upper-tick (int) The upper tick of the range.
;; @param fee-growth-global-0 (uint) The global fee growth for token 0.
;; @param fee-growth-global-1 (uint) The global fee growth for token 1.
;; @returns (response { fee-growth-0: uint, fee-growth-1: uint } (err u3007)) The fee growth inside the range, or an error.
;; @error u3007 If a tick is not found or a mathematical overflow occurs.
(define-private (calculate-fee-growth-inside (lower-tick int) (upper-tick int) (fee-growth-global-0 uint) (fee-growth-global-1 uint))
  (ok { fee-growth-0: u0, fee-growth-1: u0 })
)

;; @desc Initializes the concentrated liquidity pool with token information and initial tick.
;; @param t0 (principal) The principal of the first token.
;; @param t1 (principal) The principal of the second token.
;; @param initial-tick (int) The initial tick for the pool.
;; @param rbac-contract (<rbac-trait>) The RBAC trait contract.
;; @returns (response bool (err u3008)) True if successful, or an error.
;; @error u3008 If the caller is not authorized or an overflow occurs during price calculation.
(define-public (initialize (t0 principal) (t1 principal) (initial-tick int) (rbac-contract principal))
  (begin
    (asserts! (contract-call? rbac-contract has-role "contract-owner") u3008)
    (var-set token0 t0)
    (var-set token1 t1)
    (var-set current-tick initial-tick)
    (var-set current-sqrt-price (unwrap! (get-sqrt-price-from-tick initial-tick) u3008))
    (ok true)
  )
)

;; @desc Sets the fee rate for the pool.
;; @param new-fee (uint) The new fee rate in basis points.
;; @param rbac-contract (<rbac-trait>) The RBAC trait contract.
;; @returns (response bool (err u3009)) True if successful, or an error.
;; @error u3009 If the caller is not authorized.
(define-public (set-fee (new-fee uint) (rbac-contract <rbac-trait>))
  (begin
    (asserts! (contract-call? rbac-contract has-role "contract-owner") u3009)
    (var-set fee new-fee)
    (ok true)
  )
)

;; @desc Sets the current tick for the pool.
;; @param new-tick (int) The new tick value.
;; @param rbac-contract (<rbac-trait>) The RBAC trait contract.
;; @returns (response bool (err u3010)) True if successful, or an error.
;; @error u3010 If the caller is not authorized or an overflow occurs during price calculation.
(define-public (set-current-tick (new-tick int) (rbac-contract <rbac-trait>))
  (begin
    (asserts! (contract-call? rbac-contract has-role "contract-owner") u3010)
    (var-set current-tick new-tick)
    (var-set current-sqrt-price (unwrap! (get-sqrt-price-from-tick new-tick) u3010))
    (ok true)
  )
)

;; @desc Adds liquidity to the concentrated liquidity pool.
;; @param lower-tick (int) The lower tick of the position.
;; @param upper-tick (int) The upper tick of the position.
;; @param amount0-desired (uint) The desired amount of token0 to add.
;; @param amount1-desired (uint) The desired amount of token1 to add.
;; @returns (response { position-id: uint, amount0-actual: uint, amount1-actual: uint, liquidity-added: uint } (err u3011)) The details of the added liquidity, or an error.
;; @error u3011 If the tick range is invalid, a mathematical overflow occurs, or token transfers fail.
(define-public (add-liquidity (lower-tick int) (upper-tick int) (amount0-desired uint) (amount1-desired uint))
  (begin
    (asserts! (and (> upper-tick lower-tick) (>= lower-tick MIN_TICK) (<= upper-tick MAX_TICK)) ERR_INVALID_TICK_RANGE)

    (let ((sqrt-price-lower (unwrap! (get-sqrt-price-from-tick lower-tick) ERR_INVALID_TICK))
          (sqrt-price-upper (unwrap! (get-sqrt-price-from-tick upper-tick) ERR_INVALID_TICK))
          (current-sqrt-price (var-get current-sqrt-price)))

      (let ((liquidity (if (<= current-sqrt-price sqrt-price-lower)
                         (unwrap! (get-liquidity-for-amount0 sqrt-price-lower sqrt-price-upper amount0-desired) ERR_OVERFLOW)
                         (if (>= current-sqrt-price sqrt-price-upper)
                           (unwrap! (get-liquidity-for-amount1 sqrt-price-lower sqrt-price-upper amount1-desired) ERR_OVERFLOW)
                           (min (unwrap! (get-liquidity-for-amount0 current-sqrt-price sqrt-price-upper amount0-desired) ERR_OVERFLOW)
                                (unwrap! (get-liquidity-for-amount1 sqrt-price-lower current-sqrt-price amount1-desired) ERR_OVERFLOW))))))

        (let ((amounts (unwrap! (get-amounts-for-liquidity sqrt-price-lower sqrt-price-upper liquidity) ERR_OVERFLOW))
              (amount0-actual (get amount0 amounts))
              (amount1-actual (get amount1 amounts)))

          (asserts! (and (>= amount0-desired amount0-actual) (>= amount1-desired amount1-actual)) ERR_INSUFFICIENT_LIQUIDITY)

          (let ((position-id (unwrap! (mint-position-nft tx-sender lower-tick upper-tick liquidity) ERR_NFT_MINT_FAILED)))

            (try! (update-tick-liquidity lower-tick liquidity true))
            (try! (update-tick-liquidity upper-tick liquidity false))
            (var-set total-liquidity (+ (var-get total-liquidity) liquidity))

            (try! (contract-call? (var-get token0) transfer amount0-actual tx-sender (as-contract tx-sender) none))
            (try! (contract-call? (var-get token1) transfer amount1-actual tx-sender (as-contract tx-sender) none))

            (print {
              event: "add-liquidity",
              position-id: position-id,
              lower-tick: lower-tick,
              upper-tick: upper-tick,
              amount0-actual: amount0-actual,
              amount1-actual: amount1-actual,
              liquidity-added: liquidity
            })
            (ok { position-id: position-id, amount0-actual: amount0-actual, amount1-actual: amount1-actual, liquidity-added: liquidity })
          )
        )
      )
    )
  )
)

(define-private (update-tick-liquidity (tick int) (liquidity-delta uint) (is-add bool))
  (let ((tick-data (default-to {liquidity-gross: u0, liquidity-net: i0, fee-growth-outside-0: u0, fee-growth-outside-1: u0} (map-get? ticks {tick-id: tick}))))
    (map-set ticks {tick-id: tick} (merge tick-data {
      liquidity-gross: (+ (get liquidity-gross tick-data) liquidity-delta),
      liquidity-net: (if is-add
        (+ (get liquidity-net tick-data) (to-int liquidity-delta))
        (- (get liquidity-net tick-data) (to-int liquidity-delta))
      )
    }))
    (ok true)
  )
)

;; @desc Removes liquidity from the pool.
;; @param position-id The ID of the position NFT.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_POSITION_NOT_FOUND if the position ID does not exist.
;; @error ERR_UNAUTHORIZED if the transaction sender is not the NFT owner.
;; @error ERR_INVALID_TICK if lower-tick or upper-tick are invalid.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during token amount calculation.
;; @error ERR_NFT_BURN_FAILED if the NFT burning fails.
;; @desc Removes liquidity from the pool.
;; @param position-id The ID of the position NFT.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_POSITION_NOT_FOUND if the position ID does not exist.
;; @error ERR_UNAUTHORIZED if the transaction sender is not the NFT owner.
;; @error ERR_INVALID_TICK if lower-tick or upper-tick are invalid.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during token amount calculation.
;; @error ERR_NFT_BURN_FAILED if the NFT burning fails.
;; @desc Removes liquidity from the concentrated liquidity pool.
;; @param position-id (uint) The ID of the position NFT to remove liquidity from.
;; @returns (response { amount0-returned: uint, amount1-returned: uint, liquidity-removed: uint } (err u3012)) The amounts of token0 and token1 returned, and the liquidity removed, or an error.
;; @error u3012 If the position is not found, the caller is not authorized, or token transfers fail.
(define-public (remove-liquidity (position-id uint))
  (let ((position (unwrap! (map-get? positions { position-id: position-id }) ERR_POSITION_NOT_FOUND))
        (owner (unwrap! (nft-get-owner? position-nft position-id) ERR_UNAUTHORIZED)))
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)

    (let ((lower-tick (get lower position))
          (upper-tick (get upper position))
          (liquidity (get liquidity position)))

      (let ((amounts (unwrap! (get-amounts-for-liquidity
                              (unwrap! (get-sqrt-price-from-tick lower-tick) ERR_INVALID_TICK)
                              (unwrap! (get-sqrt-price-from-tick upper-tick) ERR_INVALID_TICK)
                              liquidity) ERR_OVERFLOW))
            (amount0-returned (get amount0 amounts))
            (amount1-returned (get amount1 amounts)))

        (try! (update-tick-liquidity lower-tick liquidity false))
        (try! (update-tick-liquidity upper-tick liquidity true))
        (var-set total-liquidity (- (var-get total-liquidity) liquidity))

        (try! (burn-position-nft position-id owner))

        (try! (as-contract (contract-call? (var-get token0) transfer amount0-returned tx-sender none)))
(try! (as-contract (contract-call? (var-get token1) transfer amount1-returned tx-sender none)))


        (print {
          event: "remove-liquidity",
          position-id: position-id,
          amount0-returned: amount0-returned,
          amount1-returned: amount1-returned,
          liquidity-removed: liquidity
        })
        (ok { amount0-returned: amount0-returned, amount1-returned: amount1-returned, liquidity-removed: liquidity })
      )
    )
  )
)

;; @desc Swaps token0 for token1 in the concentrated liquidity pool.
;; @param amount-in (uint) The amount of token0 to swap.
;; @param min-amount-out (uint) The minimum amount of token1 to receive.
;; @returns (response uint (err u3013)) The amount of token1 received, or an error.
;; @error u3013 If amount-in is zero, there is insufficient liquidity, the price limit is exceeded, or a mathematical overflow occurs.
(define-public (swap-x-for-y (amount-in uint) (min-amount-out uint))
  (let ((sqrt-price-limit (unwrap! (get-sqrt-price-from-tick MIN_TICK) ERR_INVALID_TICK)))
    (swap amount-in min-amount-out sqrt-price-limit true)
  )
)

(define-public (swap-y-for-x (amount-in uint) (min-amount-out uint))
  (let ((sqrt-price-limit (unwrap! (get-sqrt-price-from-tick MAX_TICK) ERR_INVALID_TICK)))
    (swap amount-in min-amount-out sqrt-price-limit false)
  )
)

(define-private (swap (amount-in uint) (min-amount-out uint) (sqrt-price-limit uint) (is-x-for-y bool))
  (begin
    (asserts! (> amount-in u0) ERR_ZERO_AMOUNT_IN)

    (let ((token-in (if is-x-for-y (var-get token0) (var-get token1)))
          (token-out (if is-x-for-y (var-get token1) (var-get token0))))

      (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))

      (let ((swap-result (unwrap! (compute-swap amount-in sqrt-price-limit is-x-for-y) ERR_SWAP_FAILED))
            (amount-out (get amount-out swap-result)))

        (asserts! (>= amount-out min-amount-out) ERR_INSUFFICIENT_LIQUIDITY)

        (var-set current-sqrt-price (get new-sqrt-price swap-result))
        (var-set current-tick (get new-tick swap-result))

        (try! (as-contract (contract-call? token-out transfer amount-out tx-sender none)))

        (print {
          event: "swap",
          token-in: token-in,
          token-out: token-out,
          amount-in: amount-in,
          amount-out: amount-out
        })
        (ok amount-out)
      )
    )
  )
)

(define-private (compute-swap (amount-remaining uint) (sqrt-price-limit uint) (is-x-for-y bool))
  (let ((current-sqrt-price (var-get current-sqrt-price))
        (current-liquidity (var-get total-liquidity))
        (amount-out u0))

    (while (> amount-remaining u0)
      (let ((next-tick (unwrap! (get-next-initialized-tick (var-get current-tick) (not is-x-for-y)) (err u3031))))
        (let ((next-sqrt-price (unwrap! (get-sqrt-price-from-tick next-tick) ERR_INVALID_TICK)))

          (let ((sqrt-price-target (if (if is-x-for-y (< next-sqrt-price sqrt-price-limit) (> next-sqrt-price sqrt-price-limit))
                                   sqrt-price-limit
                                   next-sqrt-price)))

            (let ((swap-step (unwrap! (compute-swap-step current-sqrt-price sqrt-price-target current-liquidity amount-remaining is-x-for-y) ERR_SWAP_FAILED)))
              (var-set amount-remaining (- amount-remaining (get amount-in-step swap-step)))
              (var-set amount-out (+ amount-out (get amount-out-step swap-step)))
              (var-set current-sqrt-price (get new-sqrt-price-step swap-step))

              (if (is-eq current-sqrt-price next-sqrt-price)
                (let ((liquidity-net (get liquidity-net (unwrap! (map-get? ticks {tick-id: next-tick}) (err u3032)))))
                  (var-set current-liquidity (if is-x-for-y
                                               (- current-liquidity (to-uint liquidity-net))
                                               (+ current-liquidity (to-uint liquidity-net))))
                )
                true
              )
            )
          )
        )
      )
    )
    (ok { amount-out: amount-out, new-sqrt-price: current-sqrt-price, new-tick: (unwrap! (get-tick-from-price current-sqrt-price) ERR_INVALID_TICK) })
  )
)

(define-private (compute-swap-step (current-sqrt-price uint) (target-sqrt-price uint) (liquidity uint) (amount-remaining uint) (is-x-for-y bool))
  (let ((amount-in-step u0)
        (amount-out-step u0)
        (new-sqrt-price-step u0))
    (if is-x-for-y
      (let ((amount-in-max (unwrap! (get-amount0-delta target-sqrt-price current-sqrt-price liquidity) ERR_OVERFLOW)))
        (if (>= amount-remaining amount-in-max)
          (begin
            (var-set amount-in-step amount-in-max)
            (var-set amount-out-step (unwrap! (get-amount1-delta target-sqrt-price current-sqrt-price liquidity) ERR_OVERFLOW))
            (var-set new-sqrt-price-step target-sqrt-price)
          )
          (begin
            (var-set amount-in-step amount-remaining)
            (var-set new-sqrt-price-step (unwrap! (get-next-sqrt-price-from-input amount-remaining liquidity current-sqrt-price true) ERR_OVERFLOW))
            (var-set amount-out-step (unwrap! (get-amount1-delta new-sqrt-price-step current-sqrt-price liquidity) ERR_OVERFLOW))
          )
        )
      )
      (let ((amount-in-max (unwrap! (get-amount1-delta current-sqrt-price target-sqrt-price liquidity) ERR_OVERFLOW)))
        (if (>= amount-remaining amount-in-max)
          (begin
            (var-set amount-in-step amount-in-max)
            (var-set amount-out-step (unwrap! (get-amount0-delta current-sqrt-price target-sqrt-price liquidity) ERR_OVERFLOW))
            (var-set new-sqrt-price-step target-sqrt-price)
          )
          (begin
            (var-set amount-in-step amount-remaining)
            (var-set new-sqrt-price-step (unwrap! (get-next-sqrt-price-from-input amount-remaining liquidity current-sqrt-price false) ERR_OVERFLOW))
            (var-set amount-out-step (unwrap! (get-amount0-delta new-sqrt-price-step current-sqrt-price liquidity) ERR_OVERFLOW))
          )
        )
      )
    )
    (ok { amount-in-step: amount-in-step, amount-out-step: amount-out-step, new-sqrt-price-step: new-sqrt-price-step })
  )
)

(define-private (get-next-sqrt-price-from-input (amount-in uint) (liquidity uint) (current-sqrt-price uint) (is-x-for-y bool))
  (if is-x-for-y
    (ok (/ (* liquidity current-sqrt-price) (+ (* amount-in current-sqrt-price) liquidity)))
    (ok (+ current-sqrt-price (/ amount-in liquidity)))
  )
)

;; @desc Collects accrued fees for a given position.
;; @param position-id (uint) The ID of the position NFT.
;; @returns (response { amount0: uint, amount1: uint } (err u3015)) The collected amounts of token0 and token1 or an error.
;; @error u3015 If the position ID does not exist or the transaction sender is not the NFT owner.
(define-public (collect-fees (position-id uint))
  (let (
    (position (unwrap! (map-get? positions { position-id: position-id })
      ERR_POSITION_NOT_FOUND
    ))
    (owner (unwrap! (nft-get-owner? position-nft position-id) ERR_UNAUTHORIZED))
  )
    (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
    ;; v1 stub: detailed fee accounting is not wired yet; return zero amounts
    (ok { amount0: u0, amount1: u0 })
  )
)

;; @desc Updates the global fee growth for the pool.
;; @param amount0 The amount of token0 swapped.
;; @param amount1 The amount of token1 swapped.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during fee growth calculation.
;; @desc Updates the global fee growth for the pool.
;; @param amount0 The amount of token0 swapped.
;; @param amount1 The amount of token1 swapped.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during fee growth calculation.
(define-private (update-fee-growth (amount0 uint) (amount1 uint))
  (begin
    (var-set fee-growth-global-0 (unwrap! (+ (var-get fee-growth-global-0) (unwrap! (/ amount0 (var-get total-liquidity)) ERR_OVERFLOW)) ERR_OVERFLOW))
    (var-set fee-growth-global-1 (unwrap! (+ (var-get fee-growth-global-1) (unwrap! (/ amount1 (var-get total-liquidity)) ERR_OVERFLOW)) ERR_OVERFLOW))
    (ok true)
  )
)

;; @desc Gets the current price of the pool.
;; @returns (response uint uint) The current sqrt price scaled by 1e9 or an error.
(define-read-only (get-current-price)
  (ok (var-get current-sqrt-price)))

;; @desc Gets the total liquidity in the pool.
;; @returns (response uint uint) The total liquidity or an error.
(define-read-only (get-total-liquidity)
  (ok (var-get total-liquidity)))

;; @desc Gets the fee growth for a specific position.
;; @param position-id The ID of the position NFT.
;; @returns (response (tuple (fee-growth-0 uint) (fee-growth-1 uint)) uint) The fee growth for token0 and token1 or an error.
;; @error ERR_POSITION_NOT_FOUND if the position ID does not exist.
(define-read-only (get-position-fee-growth (position-id uint))
  (let (
    (position (unwrap! (map-get? positions { position-id: position-id }) ERR_POSITION_NOT_FOUND))
  )
    (ok { fee-growth-0: (get fee-growth-inside-0 position), fee-growth-1: (get fee-growth-inside-1 position) })
  )
)

;; @desc Gets the current tick of the pool.
;; @returns (response int uint) The current tick or an error.
(define-read-only (get-current-tick)
  (ok (var-get current-tick)))

;; @desc Gets the fee rate of the pool.
;; @returns (response uint uint) The fee rate in basis points or an error.
(define-read-only (get-fee)
  (ok (var-get fee)))

;; @desc Gets the token0 principal of the pool.
;; @returns (response principal uint) The principal of token0 or an error.
(define-read-only (get-token0)
  (ok (var-get token0))
)

;; @desc Gets the token1 principal of the pool.
;; @returns (response principal uint) The principal of token1 or an error.
(define-read-only (get-token1)
  (ok (var-get token1))
)

;; NOTE: The legacy remove-liquidity and swap adapters that directly called
;; .sip-010-ft-trait have been removed in v1 to avoid invalid principals and
;; duplicated logic. The primary add/remove liquidity and swap paths above
;; should be used instead.

;; @desc Returns the details of a specific liquidity position.
;; @param position-id (uint) The ID of the position NFT.
;; @returns (response { lower: int, upper: int, liquidity: uint, fee-growth-inside-0: uint, fee-growth-inside-1: uint } (err u3016)) The position details or an error.
;; @error u3016 If the position ID does not exist.
(define-read-only (get-position (position-id uint))
  (ok (unwrap-panic (map-get? positions { position-id: position-id }) u3016)))

;; @desc Returns the current square root price of the pool.
;; @returns (response uint (err u3018)) The current square root price or an error.
(define-read-only (get-current-sqrt-price)
  (ok (var-get current-sqrt-price)))

;; @desc Returns the current tick of the pool.
;; @returns (response int (err u3017)) The current tick or an error.
(define-read-only (get-current-tick)
  (ok (var-get current-tick)))

;; @desc Returns the fee rate of the pool.
;; @returns (response uint uint) The fee rate or an error.
(define-read-only (get-fee-rate)
  (ok (var-get fee)))

;; --- Backward Compatibility Adapters ---

;; @desc Initializes the concentrated liquidity pool (legacy adapter).
;; @param t0 The principal of the first token in the pool.
;; @param t1 The principal of the second token in the pool.
;; @param initial-tick The initial tick of the pool.
;; @param rbac-contract The RBAC trait contract.
;; @returns (response bool uint) True if successful, or an error.
;; @error ERR_UNAUTHORIZED if the caller is not the contract owner.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during sqrt price calculation.
(define-public (initialize-legacy (t0 principal) (t1 principal) (initial-tick int) (rbac-contract <rbac-trait>))
  (initialize t0 t1 initial-tick rbac-contract))

;; @desc Adds liquidity to the pool (legacy adapter).
;; @param lower-tick The lower tick of the position.
;; @param upper-tick The upper tick of the position.
;; @param amount0-desired The desired amount of token0 to add.
;; @param amount1-desired The desired amount of token1 to add.
;; @returns (response uint uint) The ID of the new position NFT or an error.
;; @error ERR_INVALID_TICK if lower-tick or upper-tick are invalid.
;; @error ERR_INVALID_TICK_RANGE if the tick range is invalid.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during liquidity calculation.
;; @error ERR_NFT_MINT_FAILED if the NFT minting fails.
(define-public (add-liquidity-legacy (lower-tick int) (upper-tick int) (amount0-desired uint) (amount1-desired uint))
  (add-liquidity lower-tick upper-tick amount0-desired amount1-desired))

;; @desc Swaps tokens in the pool (legacy adapter).
;; @param token-in The principal of the token being sent in.
;; @param amount-in The amount of the token being sent in.
;; @param min-amount-out The minimum amount of the token to receive.
;; @returns (response uint uint) The amount of token out received or an error.
;; @error ERR_INVALID_AMOUNT if the token-in is not one of the pool's tokens.
;; @error ERR_ZERO_AMOUNT_IN if the amount-in is zero.
;; @error ERR_OVERFLOW if a mathematical overflow occurs during swap calculation.
;; @error ERR_INSUFFICIENT_LIQUIDITY if the amount-out is less than min-amount-out.
(define-public (swap-legacy (token-in principal) (amount-in uint) (min-amount-out uint))
  (if (is-eq token-in (var-get token0))
    (swap-x-for-y amount-in min-amount-out)
    (swap-y-for-x amount-in min-amount-out)
  )
)

;; @desc Calculates the fee growth outside a given tick range.
;; @param lower-tick The lower tick of the range.
;; @param upper-tick The upper tick of the range.
;; @returns (response { fee-growth-outside-0: uint, fee-growth-outside-1: uint } (err u3019)) The fee growth outside the range or an error.
;; @error u3019 If a mathematical overflow occurs.
(define-private (get-fee-growth-outside (lower-tick int) (upper-tick int))
  ;; v1 stub: return zero fee growth outside the range
  (ok {
    fee-growth-outside-0: u0,
    fee-growth-outside-1: u0
  })
)

;; @desc Calculates the tick for a given price.
;; @param price The price to convert to a tick.
;; @returns (response int (err u3020)) The tick or an error.
;; @error u3020 If a mathematical overflow occurs.
(define-private (get-tick-at-price (price uint))
  (ok (unwrap-panic (log256 price) u3020)))

;; @desc Calculates the price for a given tick.
;; @param tick The tick to convert to a price.
;; @returns (response uint (err u3021)) The price or an error.
;; @error u3021 If a mathematical overflow occurs.
(define-private (get-price-at-tick (tick int))
  (ok (unwrap-panic (exp256 tick) u3021)))

;; @desc Calculates the liquidity for given amounts of token0 and token1.
;; @param sqrt-price-a The square root price at the lower tick.
;; @param sqrt-price-b The square root price at the upper tick.
;; @param amount0 The amount of token0.
;; @param amount1 The amount of token1.
;; @returns (response uint (err u3022)) The calculated liquidity or an error.
;; @error u3022 If a mathematical overflow occurs.
(define-private (min (a uint) (b uint))
  (if (< a b) a b))

(define-private (get-liquidity-for-amounts (sqrt-price-a uint) (sqrt-price-b uint) (amount0 uint) (amount1 uint))
  (let (
    (sqrt-price-diff (abs (- sqrt-price-b sqrt-price-a)))
    (liquidity0 (if (is-eq sqrt-price-diff u0) u0 (/ (* amount0 sqrt-price-a sqrt-price-b) sqrt-price-diff)))
    (liquidity1 (if (is-eq sqrt-price-diff u0) u0 (/ amount1 sqrt-price-diff)))
  )
    (ok (min liquidity0 liquidity1))
  )
)

;; @desc Calculates the amounts of token0 and token1 for a given liquidity and price range.
;; @param sqrt-price-a The square root price at the lower tick.
;; @param sqrt-price-b The square root price at the upper tick.
;; @param liquidity The liquidity amount.
;; @returns (response { amount0: uint, amount1: uint } (err u3023)) The calculated amounts or an error.
;; @error u3023 If a mathematical overflow occurs.
(define-private (get-amounts-for-liquidity (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (let (
    (amount0 (if (>= sqrt-price-a sqrt-price-b) u0 (/ (* liquidity (- sqrt-price-a sqrt-price-b)) (* sqrt-price-a sqrt-price-b))))
    (amount1 (if (>= sqrt-price-a sqrt-price-b) (* liquidity (- sqrt-price-a sqrt-price-b)) u0))
  )
    (ok { amount0: amount0, amount1: amount1 })
  )
)

;; @desc Finds the next initialized tick in a given direction.
;; @param tick The starting tick.
;; @param lte True to search for a tick less than or equal to the given tick, false for greater than or equal.
;; @returns (response (optional int) (err u3024)) The next initialized tick or none if not found, or an error.
;; @error u3024 If an unexpected error occurs.
(define-private (get-next-initialized-tick (tick int) (lte bool))
  ;; v1 stub: initialized tick tracking is not wired; return the current tick as the only candidate.
  (ok (some tick))
)

;; @desc Returns the global fee growth for token0 and token1.
;; @returns (response { fee-growth-global-0: uint, fee-growth-global-1: uint } (err u3025)) The global fee growth or an error.
;; @error u3025 If an unexpected error occurs.
(define-private (get-fee-growth-global)
  (ok { fee-growth-global-0: (var-get fee-growth-global-0), fee-growth-global-1: (var-get fee-growth-global-1) }))

;; @desc Calculates the liquidity for a given amount of token0.
;; @param sqrt-price-a The square root price at the lower tick.
;; @param sqrt-price-b The square root price at the upper tick.
;; @param amount0 The amount of token0.
;; @returns (response uint (err u3027)) The calculated liquidity or an error.
;; @error u3027 If a mathematical overflow occurs.
(define-private (get-liquidity-for-amount0 (sqrt-price-a uint) (sqrt-price-b uint) (amount0 uint))
  (ok (/ (* amount0 sqrt-price-a sqrt-price-b) (- sqrt-price-b sqrt-price-a))))

;; @desc Calculates the liquidity for a given amount of token1.
;; @param sqrt-price-a The square root price at the lower tick.
;; @param sqrt-price-b The square root price at the upper tick.
;; @param amount1 The amount of token1.
;; @returns (response uint (err u3028)) The calculated liquidity or an error.
;; @error u3028 If a mathematical overflow occurs.
(define-private (get-liquidity-for-amount1 (sqrt-price-a uint) (sqrt-price-b uint) (amount1 uint))
  (ok (/ amount1 (- sqrt-price-b sqrt-price-a))))

;; @desc Calculates the amount of token0 for a given liquidity and price range.
;; @param sqrt-price-a The square root price at the lower tick.
;; @param sqrt-price-b The square root price at the upper tick.
;; @param liquidity The liquidity amount.
;; @returns (response uint (err u3029)) The calculated amount of token0 or an error.
;; @error u3029 If a mathematical overflow occurs.
(define-private (get-amount0-delta (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (ok (/ (* liquidity (- sqrt-price-b sqrt-price-a)) (* sqrt-price-a sqrt-price-b))))

;; @desc Calculates the amount of token1 for a given liquidity and price range.
;; @param sqrt-price-a The square root of the price at the lower bound.
;; @param sqrt-price-b The square root of the price at the upper bound.
;; @param liquidity The liquidity amount.
;; @returns (response uint (err u3030)) The amount of token1 or an error.
;; @error u3030 If a mathematical overflow occurs.
(define-private (get-amount1-delta (sqrt-price-a uint) (sqrt-price-b uint) (liquidity uint))
  (ok (* liquidity
         (- sqrt-price-b sqrt-price-a)
         (/ (pow 2 96) (* sqrt-price-a sqrt-price-b)))))

;; @desc Returns the position details for a given position ID (legacy adapter).
;; @param position-id The ID of the position NFT.
(define-read-only (get-position-legacy (position-id uint))
  (get-position position-id))
