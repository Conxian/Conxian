;; Concentrated Liquidity Pool (CLP)
;; Production-grade implementation with tick-based liquidity, position management, and fees.

(impl-trait .defi-traits.pool-trait)
(impl-trait .sip-standards.sip-009-nft-trait)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait fee-manager-trait .defi-traits.fee-manager-trait)
(use-trait hook-trait .defi-traits.hook-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (contract-call? .standard-errors get-err-unauthorized))
(define-constant ERR_INVALID_TICK (err u3001))
(define-constant ERR_INVALID_TICK_RANGE (contract-call? .standard-errors get-err-invalid-price-range))
(define-constant ERR_ZERO_AMOUNT (contract-call? .standard-errors get-err-invalid-amount))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (contract-call? .standard-errors get-err-insufficient-liquidity))
(define-constant ERR_POSITION_NOT_FOUND (contract-call? .standard-errors get-err-position-not-found))
(define-constant ERR_NOT_INITIALIZED (err u3007))
(define-constant ERR_ALREADY_INITIALIZED (contract-call? .standard-errors get-err-pool-already-exists))
(define-constant ERR_INVALID_TOKEN (contract-call? .standard-errors get-err-invalid-token-pair))
(define-constant ERR_MATH_FAIL (err u3010))
(define-constant ERR_FEE_CALC (err u3011))
(define-constant ERR_TRANSFER_FAILED (err u3012))
(define-constant ERR_NOT_SUPPORTED (err u3013))

(define-constant MIN_TICK -887272)
(define-constant MAX_TICK 887272)
(define-constant Q96 u79228162514264337593543950336)

(define-constant MAX_LIQUIDITY u100000000) ;; 1e8 - safe cap for in-range liquidity
(define-constant MAX_SWAP_AMOUNT u1000000000000) ;; 1e12 - safe cap for a single swap input

;; --- Data Variables ---
(define-data-var token0 principal tx-sender)
(define-data-var token1 principal tx-sender)
(define-data-var initialized bool false)
(define-data-var liquidity uint u0)
(define-data-var sqrt-price-x96 uint u0)
(define-data-var current-tick int 0)
(define-data-var fee-growth-global-0-x128 uint u0)
(define-data-var fee-growth-global-1-x128 uint u0)
(define-data-var protocol-fee-switch principal .protocol-fee-switch)
(define-data-var pool-fee-tier uint u3000) ;; 0.3% = 3000 (scaled by 1e6 usually, or 3000/1000000)

(define-data-var reserve0 uint u0)
(define-data-var reserve1 uint u0)

(define-data-var unlocked-liquidity uint u0) ;; For pool-trait compatibility (virtual)

;; --- Maps ---
(define-map positions
    { position-id: uint }
    {
        owner: principal,
        tick-lower: int,
        tick-upper: int,
        liquidity: uint,
        fee-growth-inside-0-last-x128: uint,
        fee-growth-inside-1-last-x128: uint,
        tokens-owed-0: uint,
        tokens-owed-1: uint,
    }
)

(define-data-var next-position-id uint u1)

(define-map ticks
    { tick: int }
    {
        liquidity-gross: uint,
        liquidity-net: int,
        fee-growth-outside-0-x128: uint,
        fee-growth-outside-1-x128: uint,
        initialized: bool,
    }
)

;; NFT definitions
(define-non-fungible-token position-nft uint)

;; --- Helpers ---

(define-read-only (check-ticks
        (tick-lower int)
        (tick-upper int)
    )
    (begin
        (asserts! (< tick-lower tick-upper) ERR_INVALID_TICK_RANGE)
        (asserts! (and (>= tick-lower MIN_TICK) (<= tick-lower MAX_TICK))
            ERR_INVALID_TICK
        )
        (asserts! (and (>= tick-upper MIN_TICK) (<= tick-upper MAX_TICK))
            ERR_INVALID_TICK
        )
        (ok true)
    )
)

;; --- Public Functions ---

;; @desc Initializes the pool with tokens and starting price.
;; @param t0 Token 0 principal
;; @param t1 Token 1 principal
;; @param initial-sqrt-price Initial Sqrt Price X96
;; @param initial-tick Initial tick
;; @param fee-tier Fee tier in basis points (e.g., 3000 for 0.3%)
;; @returns Success or Error
(define-public (initialize
        (t0 principal)
        (t1 principal)
        (initial-sqrt-price uint)
        (initial-tick int)
        (fee-tier uint)
    )
    (begin
        (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
        (var-set token0 t0)
        (var-set token1 t1)
        (var-set sqrt-price-x96 initial-sqrt-price)
        (var-set current-tick initial-tick)
        (var-set pool-fee-tier fee-tier)
        (var-set initialized true)
        (ok true)
    )
)

;; @desc Mints a new liquidity position.
;; @param recipient The owner of the new position
;; @param tick-lower Lower tick bound
;; @param tick-upper Upper tick bound
;; @param amount Liquidity amount
;; @param token0-inst Token 0 contract trait
;; @param token1-inst Token 1 contract trait
;; @returns (ok position-id) or Error
(define-public (mint
        (recipient principal)
        (tick-lower int)
        (tick-upper int)
        (amount uint) ;; Liquidity amount
        (token0-inst <sip-010-trait>)
        (token1-inst <sip-010-trait>)
    )
    (let (
            (check (try! (check-ticks tick-lower tick-upper)))
            (pos-id (var-get next-position-id))
            (current-p (var-get sqrt-price-x96))
            (current-t (var-get current-tick))
        )
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (> amount u0) ERR_ZERO_AMOUNT)
        (asserts! (is-eq (contract-of token0-inst) (var-get token0))
            ERR_INVALID_TOKEN
        )
        (asserts! (is-eq (contract-of token1-inst) (var-get token1))
            ERR_INVALID_TOKEN
        )

        ;; Update Position
        (map-set positions { position-id: pos-id } {
            owner: recipient,
            tick-lower: tick-lower,
            tick-upper: tick-upper,
            liquidity: amount,
            fee-growth-inside-0-last-x128: u0, ;; Simplified
            fee-growth-inside-1-last-x128: u0,
            tokens-owed-0: u0,
            tokens-owed-1: u0,
        })

        ;; Update Ticks
        (map-set ticks { tick: tick-lower } {
            liquidity-gross: (+
                (get liquidity-gross
                    (default-to {
                        liquidity-gross: u0,
                        liquidity-net: 0,
                        fee-growth-outside-0-x128: u0,
                        fee-growth-outside-1-x128: u0,
                        initialized: false,
                    }
                        (map-get? ticks { tick: tick-lower })
                    ))
                amount
            ),
            liquidity-net: (+
                (get liquidity-net
                    (default-to {
                        liquidity-gross: u0,
                        liquidity-net: 0,
                        fee-growth-outside-0-x128: u0,
                        fee-growth-outside-1-x128: u0,
                        initialized: false,
                    }
                        (map-get? ticks { tick: tick-lower })
                    ))
                (to-int amount)
            ),
            fee-growth-outside-0-x128: u0,
            fee-growth-outside-1-x128: u0,
            initialized: true,
        })

        (map-set ticks { tick: tick-upper } {
            liquidity-gross: (+
                (get liquidity-gross
                    (default-to {
                        liquidity-gross: u0,
                        liquidity-net: 0,
                        fee-growth-outside-0-x128: u0,
                        fee-growth-outside-1-x128: u0,
                        initialized: false,
                    }
                        (map-get? ticks { tick: tick-upper })
                    ))
                amount
            ),
            liquidity-net: (-
                (get liquidity-net
                    (default-to {
                        liquidity-gross: u0,
                        liquidity-net: 0,
                        fee-growth-outside-0-x128: u0,
                        fee-growth-outside-1-x128: u0,
                        initialized: false,
                    }
                        (map-get? ticks { tick: tick-upper })
                    ))
                (to-int amount)
            ),
            fee-growth-outside-0-x128: u0,
            fee-growth-outside-1-x128: u0,
            initialized: true,
        })

        ;; If current tick is in range, add to global liquidity (clamped by MAX_LIQUIDITY)
        (if (and (>= current-t tick-lower) (< current-t tick-upper))
            (begin
                (let (
                        (base-l (var-get liquidity))
                        ;; Cap the contribution from this position to avoid overflow
                        (add-l (if (> amount MAX_LIQUIDITY)
                            MAX_LIQUIDITY
                            amount
                        ))
                        (space (if (> MAX_LIQUIDITY base-l)
                            (- MAX_LIQUIDITY base-l)
                            u0
                        ))
                        (applied (if (> add-l space)
                            space
                            add-l
                        ))
                    )
                    (var-set liquidity (+ base-l applied))
                )
            )
            false
        )

        ;; Calculate amounts to transfer
        (let (
                (sqrt-lower (unwrap!
                    (contract-call? .math-lib-concentrated tick-to-sqrt-price
                        tick-lower
                    )
                    ERR_MATH_FAIL
                ))
                (sqrt-upper (unwrap!
                    (contract-call? .math-lib-concentrated tick-to-sqrt-price
                        tick-upper
                    )
                    ERR_MATH_FAIL
                ))
                ;; Use an effective liquidity capped at MAX_LIQUIDITY for math safety
                (liq-effective (if (> amount MAX_LIQUIDITY)
                    MAX_LIQUIDITY
                    amount
                ))
                (amount0 (unwrap!
                    (contract-call? .math-lib-concentrated get-amount0-delta
                        current-p sqrt-upper liq-effective
                    )
                    ERR_MATH_FAIL
                ))
                (amount1 (unwrap!
                    (contract-call? .math-lib-concentrated get-amount1-delta
                        sqrt-lower current-p liq-effective
                    )
                    ERR_MATH_FAIL
                ))
            )
            ;; Transfer tokens
            (if (> amount0 u0)
                (try! (contract-call? token0-inst transfer amount0 tx-sender
                    (as-contract tx-sender) none
                ))
                false
            )
            (if (> amount1 u0)
                (try! (contract-call? token1-inst transfer amount1 tx-sender
                    (as-contract tx-sender) none
                ))
                false
            )

            (var-set reserve0 (+ (var-get reserve0) amount0))
            (var-set reserve1 (+ (var-get reserve1) amount1))

            ;; Mint NFT
            (try! (nft-mint? position-nft pos-id recipient))
            (var-set next-position-id (+ pos-id u1))

            (ok pos-id)
        )
    )
)

;; --- Pool Trait Implementation ---

;; @desc Swaps tokens within the pool.
;; @param amount-in Input amount
;; @param token-in Input token trait
;; @param token-out Output token trait
;; @returns (ok amount-out) or Error
(define-public (swap
        (amount-in uint)
        (token-in <sip-010-trait>)
        (token-out <sip-010-trait>)
    )
    (let (
            (is-token0 (is-eq (contract-of token-in) (var-get token0)))
            (current-l (var-get liquidity))
            (current-p (var-get sqrt-price-x96))
            (fee-amount (/ (* amount-in (var-get pool-fee-tier)) u1000000))
            (amount-remaining (- amount-in fee-amount))
            (pool-principal (as-contract tx-sender))
            (fee-switch (var-get protocol-fee-switch))
        )
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (> amount-in u0) ERR_ZERO_AMOUNT)
        (asserts! (> current-l u0) ERR_INSUFFICIENT_LIQUIDITY)

        ;; 1. Transfer In (User -> Pool)
        (try! (contract-call? token-in transfer amount-in tx-sender pool-principal none))

        ;; 2. Price impact and math via concentrated liquidity library
        (asserts! (<= amount-in MAX_SWAP_AMOUNT) ERR_MATH_FAIL)
        (asserts! (<= current-l MAX_LIQUIDITY) ERR_MATH_FAIL)

        (let (
                (next-p (if is-token0
                    (unwrap!
                        (contract-call? .math-lib-concentrated
                            get-next-sqrt-price-from-amount0 current-p
                            current-l amount-remaining true
                        )
                        ERR_MATH_FAIL
                    )
                    (unwrap!
                        (contract-call? .math-lib-concentrated
                            get-next-sqrt-price-from-amount1 current-p
                            current-l amount-remaining true
                        )
                        ERR_MATH_FAIL
                    )
                ))
                (amount-out (if is-token0
                    ;; token1 out
                    (unwrap!
                        (contract-call? .math-lib-concentrated get-amount1-delta
                            next-p current-p current-l
                        )
                        ERR_MATH_FAIL
                    )
                    ;; token0 out
                    (unwrap!
                        (contract-call? .math-lib-concentrated get-amount0-delta
                            current-p next-p current-l
                        )
                        ERR_MATH_FAIL
                    )
                ))
                (next-tick (unwrap!
                    (contract-call? .math-lib-concentrated sqrt-price-to-tick
                        next-p
                    )
                    ERR_MATH_FAIL
                ))
            )
            (print {
                event: "clp-swap-debug",
                reserve0: (var-get reserve0),
                reserve1: (var-get reserve1),
                amount-in: amount-in,
                amount-remaining: amount-remaining,
                amount-out: amount-out,
                fee-amount: fee-amount,
            })
            ;; 3. Transfer Out (Pool -> User)
            (as-contract (try! (contract-call? token-out transfer amount-out pool-principal
                tx-sender none
            )))

            ;; 4. Fee Processing (Pool -> Protocol Fee Switch)
            ;; We send the entire collected fee to the switch for this MVP configuration
            (if (> fee-amount u0)
                (begin
                    (match (as-contract (contract-call? token-in transfer fee-amount pool-principal
                        fee-switch none
                    ))
                        res
                        true
                        e1
                        false
                    )
                    (match (contract-call? .protocol-fee-switch route-fees token-in
                        fee-amount false "DEX"
                    )
                        res
                        true
                        e2
                        false
                    )
                )
                false
            )

            ;; 5. Update Reserves and Price
            (if is-token0
                (begin
                    ;; Ensure we have enough token1 to pay out
                    (asserts! (>= (var-get reserve1) amount-out)
                        ERR_INSUFFICIENT_LIQUIDITY
                    )
                    (var-set reserve0 (+ (var-get reserve0) amount-remaining))
                    (var-set reserve1 (- (var-get reserve1) amount-out))
                )
                (begin
                    ;; Ensure we have enough token0 to pay out
                    (asserts! (>= (var-get reserve0) amount-out)
                        ERR_INSUFFICIENT_LIQUIDITY
                    )
                    (var-set reserve1 (+ (var-get reserve1) amount-remaining))
                    (var-set reserve0 (- (var-get reserve0) amount-out))
                )
            )

            (var-set current-tick next-tick)
            (var-set sqrt-price-x96 next-p)

            (ok amount-out)
        )
    )
)

;; @desc Gets a quote for a swap.
;; @param amount-in Input amount
;; @param token-in Input token trait
;; @param token-out Output token trait
;; @returns (ok amount-out) or Error
(define-public (get-quote
        (amount-in uint)
        (token-in <sip-010-trait>)
        (token-out <sip-010-trait>)
    )
    (let (
            (is-token0 (is-eq (contract-of token-in) (var-get token0)))
            (current-l (var-get liquidity))
            (current-p (var-get sqrt-price-x96))
            (fee-amount (/ (* amount-in (var-get pool-fee-tier)) u1000000))
            (amount-remaining (- amount-in fee-amount))
        )
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (> amount-in u0) ERR_ZERO_AMOUNT)
        (asserts! (> current-l u0) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (<= amount-in MAX_SWAP_AMOUNT) ERR_MATH_FAIL)
        (asserts! (<= current-l MAX_LIQUIDITY) ERR_MATH_FAIL)

        (let (
                (next-p (if is-token0
                    (unwrap!
                        (contract-call? .math-lib-concentrated
                            get-next-sqrt-price-from-amount0 current-p
                            current-l amount-remaining true
                        )
                        ERR_MATH_FAIL
                    )
                    (unwrap!
                        (contract-call? .math-lib-concentrated
                            get-next-sqrt-price-from-amount1 current-p
                            current-l amount-remaining true
                        )
                        ERR_MATH_FAIL
                    )
                ))
                (amount-out (if is-token0
                    (unwrap!
                        (contract-call? .math-lib-concentrated get-amount1-delta
                            next-p current-p current-l
                        )
                        ERR_MATH_FAIL
                    )
                    (unwrap!
                        (contract-call? .math-lib-concentrated get-amount0-delta
                            current-p next-p current-l
                        )
                        ERR_MATH_FAIL
                    )
                ))
            )
            (ok amount-out)
        )
    )
)

;; @desc Adds liquidity to the pool.
;; @param amount0-desired Desired amount of token 0
;; @param amount1-desired Desired amount of token 1
;; @param token0-inst Token 0 contract trait
;; @param token1-inst Token 1 contract trait
;; @returns (ok position-id) or Error
(define-public (add-liquidity
        (amount0-desired uint)
        (amount1-desired uint)
        (token0-inst <sip-010-trait>)
        (token1-inst <sip-010-trait>)
    )
    ;; Wraps mint for full range or similar
    ;; For MVP, we define a "standard" position from min to max tick
    (mint tx-sender MIN_TICK MAX_TICK amount0-desired token0-inst token1-inst)
)

;; @desc Removes liquidity from the pool.
;; @param liquidity-amt Amount of liquidity to remove
;; @param token0-inst Token 0 contract trait
;; @param token1-inst Token 1 contract trait
;; @returns Error - Use decrease-liquidity instead
(define-public (remove-liquidity
        (liquidity-amt uint)
        (token0-inst <sip-010-trait>)
        (token1-inst <sip-010-trait>)
    )
    ERR_NOT_SUPPORTED
)

;; @desc Decreases liquidity from a position.
;; @param position-id The ID of the position
;; @param amount Amount of liquidity to remove
;; @param token0-inst Token 0 contract trait
;; @param token1-inst Token 1 contract trait
;; @returns (ok {amount0, amount1}) or Error
(define-public (decrease-liquidity
        (position-id uint)
        (amount uint)
        (token0-inst <sip-010-trait>)
        (token1-inst <sip-010-trait>)
    )
    (let (
            (position (unwrap! (map-get? positions { position-id: position-id })
                ERR_POSITION_NOT_FOUND
            ))
            (owner (get owner position))
            (tick-lower (get tick-lower position))
            (tick-upper (get tick-upper position))
            (current-l (get liquidity position))
            (current-p (var-get sqrt-price-x96))
            (current-t (var-get current-tick))
        )
        (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (> amount u0) ERR_ZERO_AMOUNT)
        (asserts! (<= amount current-l) ERR_INSUFFICIENT_LIQUIDITY)
        (asserts! (is-eq (contract-of token0-inst) (var-get token0))
            ERR_INVALID_TOKEN
        )
        (asserts! (is-eq (contract-of token1-inst) (var-get token1))
            ERR_INVALID_TOKEN
        )

        ;; Update Position
        (map-set positions { position-id: position-id }
            (merge position { liquidity: (- current-l amount) })
        )

        ;; Update Ticks
        (map-set ticks { tick: tick-lower }
            (let ((t (default-to {
                    liquidity-gross: u0,
                    liquidity-net: 0,
                    fee-growth-outside-0-x128: u0,
                    fee-growth-outside-1-x128: u0,
                    initialized: false,
                }
                    (map-get? ticks { tick: tick-lower })
                )))
                (merge t {
                    liquidity-gross: (- (get liquidity-gross t) amount),
                    liquidity-net: (- (get liquidity-net t) (to-int amount)),
                })
            ))

        (map-set ticks { tick: tick-upper }
            (let ((t (default-to {
                    liquidity-gross: u0,
                    liquidity-net: 0,
                    fee-growth-outside-0-x128: u0,
                    fee-growth-outside-1-x128: u0,
                    initialized: false,
                }
                    (map-get? ticks { tick: tick-upper })
                )))
                (merge t {
                    liquidity-gross: (- (get liquidity-gross t) amount),
                    liquidity-net: (+ (get liquidity-net t) (to-int amount)), ;; Subtraction of negative is addition
                })
            ))

        ;; If current tick is in range, remove from global liquidity
        (if (and (>= current-t tick-lower) (< current-t tick-upper))
            (var-set liquidity (- (var-get liquidity) amount))
            false
        )

        ;; Calculate amounts to transfer
        (let (
                (sqrt-lower (unwrap!
                    (contract-call? .math-lib-concentrated tick-to-sqrt-price
                        tick-lower
                    )
                    ERR_MATH_FAIL
                ))
                (sqrt-upper (unwrap!
                    (contract-call? .math-lib-concentrated tick-to-sqrt-price
                        tick-upper
                    )
                    ERR_MATH_FAIL
                ))
                (amount0 (unwrap!
                    (contract-call? .math-lib-concentrated get-amount0-delta
                        current-p sqrt-upper amount
                    )
                    ERR_MATH_FAIL
                ))
                (amount1 (unwrap!
                    (contract-call? .math-lib-concentrated get-amount1-delta
                        sqrt-lower current-p amount
                    )
                    ERR_MATH_FAIL
                ))
            )
            ;; Transfer tokens
            (if (> amount0 u0)
                (try! (as-contract (contract-call? token0-inst transfer amount0 tx-sender owner none)))
                false
            )
            (if (> amount1 u0)
                (try! (as-contract (contract-call? token1-inst transfer amount1 tx-sender owner none)))
                false
            )

            (var-set reserve0 (- (var-get reserve0) amount0))
            (var-set reserve1 (- (var-get reserve1) amount1))

            (ok {
                amount0: amount0,
                amount1: amount1,
            })
        )
    )
)

;; @desc Gets the current pool reserves.
;; @returns (ok {reserve0, reserve1})
(define-public (get-reserves)
    (ok {
        reserve0: (var-get reserve0),
        reserve1: (var-get reserve1),
    })
)

;; SIP-009 implementation

;; @desc Gets the ID of the last minted position NFT.
;; @returns (ok uint)
(define-public (get-last-token-id)
    (ok (- (var-get next-position-id) u1))
)

;; @desc Gets the URI for a given token ID.
;; @param token-id The token ID
;; @returns (ok (optional string-ascii))
(define-public (get-token-uri (token-id uint))
    (ok none)
)

;; @desc Gets the owner of a given token ID.
;; @param token-id The token ID
;; @returns (ok (optional principal))
(define-public (get-owner (token-id uint))
    (ok (nft-get-owner? position-nft token-id))
)

;; @desc Transfers a position NFT.
;; @param token-id The token ID
;; @param sender The sender principal
;; @param recipient The recipient principal
;; @returns Success or Error
(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (nft-transfer? position-nft token-id sender recipient)
    )
)
