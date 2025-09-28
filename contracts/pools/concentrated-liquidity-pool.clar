;; concentrated-liquidity-pool.clar
;; Implements a concentrated liquidity pool for the Conxian DEX.

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait pool-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pool-trait)
(use-trait math-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.math-trait)
(use-trait error-codes-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.error-codes-trait)
(use-trait nft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.nft-trait)

;; Constants
(define-constant Q128 u340282366920938463463374607431768211456)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INVALID_TICK (err u102))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u103))
(define-constant ERR_SWAP_FAILED (err u104))
(define-constant ERR_MINT_FAILED (err u105))
(define-constant ERR_BURN_FAILED (err u106))
(define-constant ERR_INVALID_POSITION (err u107))

;; Data Maps
(define-map pools
  {pool-id: uint}
  {
    token-x: principal,
    token-y: principal,
    factory: principal,
    fee-bps: uint,
    tick-spacing: uint,
    current-tick: int,
    current-sqrt-price: uint,
    liquidity: uint,
    fee-growth-global-x: uint,
    fee-growth-global-y: uint
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


(define-public (add-liquidity (pool-id uint) (amount-x-desired uint) (amount-y-desired uint) (amount-x-min uint) (amount-y-min uint) (recipient principal))
    (let
      (
        (position-id (try! (mint-position pool-id amount-x-desired amount-y-desired amount-x-min amount-y-min)))
        (position (unwrap! (map-get? positions {position-id: position-id}) ERR_INVALID_POSITION))
      )
      (ok {tokens-minted: (get liquidity position), token-a-used: (get amount-x position), token-b-used: (get amount-y position)})
    )
  )

(define-public (remove-liquidity (position-id uint) (liquidity-amount uint) (recipient principal))
    (let
      (
        (amounts (try! (burn-position position-id liquidity-amount)))
      )
      (ok {token-a-returned: (get amount-x amounts), token-b-returned: (get amount-y amounts)})
    )
  )

(define-public (get-reserves (pool-id uint))
    (let
      (
        (pool (unwrap! (map-get? pools {pool-id: pool-id}) ERR_INVALID_POSITION))
        (token-x-balance (unwrap! (contract-call? (get token-x pool) get-balance (as-contract tx-sender)) (err u0)))
        (token-y-balance (unwrap! (contract-call? (get token-y pool) get-balance (as-contract tx-sender)) (err u0)))
      )
      (ok {reserve-a: token-x-balance, reserve-b: token-y-balance})
    )
  )

  (define-public (get-total-supply (pool-id uint))
    (let
      (
        (pool (unwrap! (map-get? pools {pool-id: pool-id}) ERR_INVALID_POSITION))
      )
      (ok (get liquidity pool))
    )
  )

;; Public functions
(define-public (create-pool
  (token-x <sip-010-ft-trait>)
  (token-y <sip-010-ft-trait>)
  (factory-address principal)
  (fee-bps uint)
  (tick-spacing uint)
  (initial-price uint)
  (start-tick int)
  (end-tick int)
  (pool-id uint)
  )
  (let
    (
      (current-pool-id (var-get next-pool-id))
    )
    (asserts! (is-eq tx-sender factory-address) ERR_UNAUTHORIZED)
    (map-set pools
      {pool-id: current-pool-id}
      {
        token-x: (contract-of token-x),
        token-y: (contract-of token-y),
        factory: factory-address,
        fee-bps: fee-bps,
        tick-spacing: tick-spacing,
        current-tick: start-tick,
        current-sqrt-price: initial-price,
        liquidity: u0,
        fee-growth-global-x: u0,
        fee-growth-global-y: u0
      }
    )
    (var-set next-pool-id (+ current-pool-id u1))
    (ok current-pool-id)
  )
)


;; Helper functions for tick-based liquidity management
(define-read-only (get-sqrt-price-from-tick (tick int))
  (ok (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced get-sqrt-price-from-tick tick) ERR_INVALID_TICK))
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint))
  (ok (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced get-tick-from-sqrt-price sqrt-price) ERR_INVALID_TICK))
)

(define-read-only (get-liquidity-for-amounts (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint) (amount-x uint) (amount-y uint))
  (ok (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced get-liquidity-for-amounts sqrt-price-current sqrt-price-lower sqrt-price-upper amount-x amount-y) ERR_INSUFFICIENT_LIQUIDITY))
)

(define-read-only (calculate-amount-x (liquidity uint) (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
  (ok (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-x liquidity sqrt-price-current sqrt-price-lower sqrt-price-upper) ERR_INVALID_AMOUNT))
)

(define-read-only (calculate-amount-y (liquidity uint) (sqrt-price-current uint) (sqrt-price-lower uint) (sqrt-price-upper uint))
  (ok (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-y liquidity sqrt-price-current sqrt-price-lower sqrt-price-upper) ERR_INVALID_AMOUNT))
)

(define-non-fungible-token position-nft uint)

(define-public (mint-position (pool-id uint) (tick-lower int) (tick-upper int) (amount-x-desired uint) (amount-y-desired uint) (amount-x-min uint) (amount-y-min uint))
  (let
    (
      (position-id (var-get next-position-id))
      (pool (unwrap! (map-get? pools {pool-id: pool-id}) ERR_INVALID_POSITION))
      (sqrt-price-current (get current-sqrt-price pool))
      (sqrt-price-lower (unwrap! (get-sqrt-price-from-tick tick-lower) ERR_INVALID_TICK))
      (sqrt-price-upper (unwrap! (get-sqrt-price-from-tick tick-upper) ERR_INVALID_TICK))
      (liquidity (unwrap! (get-liquidity-for-amounts sqrt-price-current sqrt-price-lower sqrt-price-upper amount-x-desired amount-y-desired) ERR_INSUFFICIENT_LIQUIDITY))
      (amount-x (unwrap! (calculate-amount-x liquidity sqrt-price-current sqrt-price-lower sqrt-price-upper) ERR_INVALID_AMOUNT))
      (amount-y (unwrap! (calculate-amount-y liquidity sqrt-price-current sqrt-price-lower sqrt-price-upper) ERR_INVALID_AMOUNT))
    )
    (asserts! (>= amount-x amount-x-min) ERR_INSUFFICIENT_LIQUIDITY)
    (asserts! (>= amount-y amount-y-min) ERR_INSUFFICIENT_LIQUIDITY)

    ;; Transfer tokens
    (try! (contract-call? (get token-x pool) transfer amount-x tx-sender (as-contract tx-sender)))
    (try! (contract-call? (get token-y pool) transfer amount-y tx-sender (as-contract tx-sender)))

    ;; Mint NFT
    (try! (nft-mint position-nft position-id tx-sender))

    ;; Update position data
    (map-set positions
      {position-id: position-id}
      {
        owner: tx-sender,
        pool-id: pool-id,
        tick-lower: tick-lower,
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

(define-public (collect-fees (position-id uint))
  (let
    (
      (position (unwrap! (map-get? positions {position-id: position-id}) ERR_INVALID_POSITION))
      (pool (unwrap! (map-get? pools {pool-id: (get pool-id position)}) ERR_INVALID_POSITION))
      (fee-growth-global-x (get fee-growth-global-x pool))
      (fee-growth-global-y (get fee-growth-global-y pool))
      (fee-growth-inside-last-x (get fee-growth-inside-last-x position))
      (fee-growth-inside-last-y (get fee-growth-inside-last-y position))
      (liquidity (get liquidity position))

      (fees-x (- fee-growth-global-x fee-growth-inside-last-x))
      (fees-y (- fee-growth-global-y fee-growth-inside-last-y))

      (amount-x-to-collect (/ (* fees-x liquidity) Q128))
      (amount-y-to-collect (/ (* fees-y liquidity) Q128))
    )
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)

    ;; Transfer fees to owner
    (try! (contract-call? (get token-x pool) transfer amount-x-to-collect (as-contract tx-sender) tx-sender))
    (try! (contract-call? (get token-y pool) transfer amount-y-to-collect (as-contract tx-sender) tx-sender))

    ;; Update fee tracking in position
    (map-set positions {position-id: position-id} (merge position {fee-growth-inside-last-x: fee-growth-global-x, fee-growth-inside-last-y: fee-growth-global-y}))

    (ok {fees-x: amount-x-to-collect, fees-y: amount-y-to-collect})
  )
)

(define-public (swap (amount-in uint) (token-in principal) (recipient principal))
    (if (is-eq token-in (contract-of token-x))
      (swap-x-for-y pool-id amount-in u0 recipient)
      (swap-y-for-x pool-id amount-in u0 recipient)
    )
  )

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
  (let
    (
      (pool (unwrap! (map-get? pools {pool-id: pool-id}) ERR_INVALID_POSITION))
      (token-x (get token-x pool))
      (token-y (get token-y pool))
      (fee-bps (get fee-bps pool))
      (current-sqrt-price (get current-sqrt-price pool))
      (liquidity (get liquidity pool))

      ;; Calculate fee
      (fee-amount (/ (* amount-x-in fee-bps) u10000))
      (amount-x-after-fee (- amount-x-in fee-amount))

      (new-sqrt-price (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-new-sqrt-price current-sqrt-price liquidity amount-x-after-fee) ERR_SWAP_FAILED))
      (amount-y-out (unwrap! (contract-call? 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.math-lib-advanced calculate-amount-y-out current-sqrt-price new-sqrt-price liquidity) ERR_SWAP_FAILED))

      ;; Update global fee growth
      (new-fee-growth-global-x (+ (get fee-growth-global-x pool) (/ (* fee-amount Q128) liquidity)))
    )
    (asserts! (> amount-x-in u0) ERR_INVALID_AMOUNT)

    ;; Transfer token-x from sender to contract
    (try! (contract-call? token-x transfer amount-x-in tx-sender (as-contract tx-sender)))

    ;; Placeholder for actual swap logic to calculate amount-y-out and new-sqrt-price
    ;; For now, we'll just set a dummy value for amount-y-out
    (var-set amount-y-out (/ amount-x-after-fee u2))

    (asserts! (>= amount-y-out amount-y-min-out) ERR_INSUFFICIENT_OUTPUT)

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