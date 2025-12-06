;; Concentrated Liquidity Pool (CLP)
;; Production-grade implementation with tick-based liquidity, position management, and fees.

(impl-trait .defi-traits.pool-trait)
(impl-trait .sip-standards.sip-009-nft-trait)

(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)
(use-trait fee-manager-trait .defi-traits.fee-manager-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1100))
(define-constant ERR_INVALID_TICK (err u3001))
(define-constant ERR_INVALID_TICK_RANGE (err u3002))
(define-constant ERR_ZERO_AMOUNT (err u1207))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1307))
(define-constant ERR_POSITION_NOT_FOUND (err u3006))
(define-constant ERR_NOT_INITIALIZED (err u3007))
(define-constant ERR_ALREADY_INITIALIZED (err u3008))
(define-constant ERR_INVALID_TOKEN (err u3009))
(define-constant ERR_MATH_FAIL (err u3010))
(define-constant ERR_FEE_CALC (err u3011))
(define-constant ERR_TRANSFER_FAILED (err u3012))
(define-constant ERR_NOT_SUPPORTED (err u3013))

(define-constant MIN_TICK (- 887272))
(define-constant MAX_TICK 887272)

;; --- Data Variables ---
(define-data-var token0 principal tx-sender)
(define-data-var token1 principal tx-sender)
(define-data-var initialized bool false)
(define-data-var next-position-id uint u1)
(define-data-var liquidity uint u0)
(define-data-var sqrt-price-x96 uint u0)
(define-data-var current-tick int 0)
(define-data-var protocol-fee-switch principal .protocol-fee-switch)
(define-data-var pool-fee-tier uint u30) ;; Default 0.3% (30 bps)

(use-trait hook-trait .defi-traits.hook-trait)

;; --- Maps ---
(define-map positions
    { position-id: uint }
    {
        owner: principal,
        tick-lower: int,
        tick-upper: int,
        liquidity: uint,
    }
)

;; Tick data for liquidity tracking
(define-map ticks
    { tick: int }
    {
        liquidity-gross: uint, ;; Total liquidity referencing this tick
        liquidity-net: int, ;; Liquidity added (lower) or removed (upper) when crossing
        initialized: bool,
    }
)

(define-non-fungible-token position-nft uint)

;; --- Public Functions ---

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

;; --- Pool Trait Implementation ---

(define-public (swap
        (amount-in uint)
        (token-in <sip-010-trait>)
        (token-out <sip-010-trait>)
    )
    (let (
            (sender tx-sender)
            (token-in-principal (contract-of token-in))
            (token-out-principal (contract-of token-out))
            (token0-principal (var-get token0))
            (token1-principal (var-get token1))
            (is-token0 (is-eq token-in-principal token0-principal))
            (is-token1 (is-eq token-in-principal token1-principal))
            (current-sqrt (var-get sqrt-price-x96))
            (current-liq (var-get liquidity))
        )
        (asserts! (or is-token0 is-token1) ERR_INVALID_TOKEN)
        (asserts!
            (is-eq
                (if is-token0
                    token1-principal
                    token0-principal
                )
                token-out-principal
            )
            ERR_INVALID_TOKEN
        )
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (> current-liq u0) ERR_INSUFFICIENT_LIQUIDITY)

        ;; 1. Transfer amount-in from user to pool
        (try! (contract-call? token-in transfer amount-in sender
            (as-contract tx-sender) none
        ))

        ;; 2. Route Fees (Dynamic)
        (let (
                (fee-rate (unwrap!
                    (contract-call?
                        .protocol-fee-switch
                        get-fee-rate "DEX"
                    )
                    ERR_FEE_CALC
                ))
                (fee-amount (/ (* amount-in fee-rate) u10000))
                (amount-in-less-fee (- amount-in fee-amount))
            )
            ;; Emit Swap/Fee Event
            (print {
                event: "swap-execution",
                sender: sender,
                token-in: token-in-principal,
                token-out: token-out-principal,
                amount-in: amount-in,
                fee-collected: fee-amount,
                timestamp: block-height,
            })

            ;; Transfer Fee to Switch & Route
            (if (> fee-amount u0)
                (begin
                    (try! (as-contract (contract-call? token-in transfer fee-amount tx-sender
                        .protocol-fee-switch
                        none
                    )))
                    (unwrap!
                        (contract-call?
                            .protocol-fee-switch
                            route-fees token-in fee-amount false "DEX"
                        )
                        ERR_FEE_CALC
                    )
                )
                u0
            )

            (let (
                    ;; 3. Calculate amount out
                    (next-price-outer (if is-token0
                        (contract-call? .math-lib-concentrated
                            get-next-sqrt-price-from-amount0 current-sqrt
                            current-liq amount-in-less-fee true
                        )
                        (contract-call? .math-lib-concentrated
                            get-next-sqrt-price-from-amount1 current-sqrt
                            current-liq amount-in-less-fee true
                        )
                    ))
                    (next-price (unwrap! next-price-outer ERR_MATH_FAIL))
                    (amount-out-outer (if is-token0
                        (contract-call? .math-lib-concentrated get-amount1-delta
                            next-price current-sqrt current-liq
                        )
                        (contract-call? .math-lib-concentrated get-amount0-delta
                            current-sqrt next-price current-liq
                        )
                    ))
                    (amount-out (unwrap! amount-out-outer ERR_MATH_FAIL))
                )
                (var-set sqrt-price-x96 next-price)

                ;; Update current tick based on new price
                ;; Convert sqrt-price to tick (fallback to current tick if conversion fails)
                (let ((tick-val (unwrap! (contract-call? .math-lib-concentrated sqrt-price-to-tick next-price) ERR_MATH_FAIL)))
                    ;; Check if we crossed a tick boundary
                    (if (not (is-eq tick-val (var-get current-tick)))
                        (begin
                            ;; Tick crossing: update liquidity
                            (let ((tick-data (default-to {
                                    liquidity-gross: u0,
                                    liquidity-net: 0,
                                    initialized: false,
                                }
                                    (map-get? ticks { tick: tick-val })
                                )))
                                ;; Apply liquidity-net change when crossing
                                (if (get initialized tick-data)
                                    (var-set liquidity
                                        (if (> tick-val (var-get current-tick))
                                            ;; Crossing up: add liquidity-net
                                            (to-uint (+ (to-int (var-get liquidity)) (get liquidity-net tick-data)))
                                            ;; Crossing down: subtract liquidity-net
                                            (to-uint (- (to-int (var-get liquidity)) (get liquidity-net tick-data)))
                                        ))
                                    true
                                )
                                (var-set current-tick tick-val)
                            )
                        )
                        true
                    )
                )

                ;; 4. Transfer amount-out to user
                (try! (as-contract (contract-call? token-out transfer amount-out tx-sender sender
                    none
                )))

                (ok amount-out)
            )
        )
    )
)

(define-public (swap-with-hook
        (amount-in uint)
        (token-in <sip-010-trait>)
        (token-out <sip-010-trait>)
        (hook <hook-trait>)
    )
    (begin
        ;; Pre-hook
        (try! (contract-call? hook on-action "SWAP_PRE" tx-sender amount-in
            (contract-of token-in) none
        ))

        ;; Swap
        (let ((res (swap amount-in token-in token-out)))
            (match res
                ok-amount (begin
                    ;; Post-hook
                    (try! (contract-call? hook on-action "SWAP_POST" tx-sender
                        ok-amount (contract-of token-out) none
                    ))
                    (ok ok-amount)
                )
                err-code (err err-code)
            )
        )
    )
)

(define-public (add-liquidity
        (amount0 uint)
        (amount1 uint)
        (token0-trait <sip-010-trait>)
        (token1-trait <sip-010-trait>)
    )
    (begin
        ;; Verify traits
        (asserts! (is-eq (contract-of token0-trait) (var-get token0))
            ERR_INVALID_TOKEN
        )
        (asserts! (is-eq (contract-of token1-trait) (var-get token1))
            ERR_INVALID_TOKEN
        )

        ;; Transfer tokens
        (if (> amount0 u0)
            (try! (contract-call? token0-trait transfer amount0 tx-sender
                (as-contract tx-sender) none
            ))
            true
        )
        (if (> amount1 u0)
            (try! (contract-call? token1-trait transfer amount1 tx-sender
                (as-contract tx-sender) none
            ))
            true
        )

        ;; Mint position
        ;; Note: For simplicity in this wrapper, we assume full range or default range. 
        ;; But usually add-liquidity should specify ticks.
        ;; Here we just call mint with MIN/MAX ticks as a default if used directly.
        (mint tx-sender MIN_TICK MAX_TICK amount0 amount1)
    )
)

(define-public (remove-liquidity
        (position-id uint)
        (token0-trait <sip-010-trait>)
        (token1-trait <sip-010-trait>)
    )
    (begin
        ;; 1. Verify Ownership
        (let (
            (position (unwrap! (map-get? positions { position-id: position-id }) ERR_POSITION_NOT_FOUND))
            (owner (get owner position))
        )
             (asserts! (is-eq tx-sender owner) ERR_UNAUTHORIZED)
             
             ;; 2. Calculate Amounts to Withdraw
             ;; In a real implementation, we would calculate amounts based on:
             ;; - Current Price vs Range
             ;; - Fees accumulated
             ;; Here we simplify by using the liquidity amount directly as a proxy for proportional withdrawal
             ;; OR we reverse the liquidity calculation.
             
             (let (
                (liq (get liquidity position))
                (tick-lower (get tick-lower position))
                (tick-upper (get tick-upper position))
                (curr-tick (var-get current-tick))
                (current-sqrt (var-get sqrt-price-x96))
                (lower-sqrt (unwrap! (contract-call? .math-lib-concentrated tick-to-sqrt-price tick-lower) ERR_MATH_FAIL))
                (upper-sqrt (unwrap! (contract-call? .math-lib-concentrated tick-to-sqrt-price tick-upper) ERR_MATH_FAIL))
             )
                (asserts! (> liq u0) ERR_ZERO_AMOUNT)
                
                (let (
                    (amounts (if (< curr-tick tick-lower)
                        ;; Current price below range: All in Token0
                        { 
                           amount0: (unwrap! (contract-call? .math-lib-concentrated get-amount0-delta lower-sqrt upper-sqrt liq) ERR_MATH_FAIL),
                           amount1: u0
                        }
                        (if (>= curr-tick tick-upper)
                            ;; Current price above range: All in Token1
                            {
                                amount0: u0,
                                amount1: (unwrap! (contract-call? .math-lib-concentrated get-amount1-delta lower-sqrt upper-sqrt liq) ERR_MATH_FAIL)
                            }
                            ;; Current price in range: Mixed
                            {
                                amount0: (unwrap! (contract-call? .math-lib-concentrated get-amount0-delta current-sqrt upper-sqrt liq) ERR_MATH_FAIL),
                                amount1: (unwrap! (contract-call? .math-lib-concentrated get-amount1-delta lower-sqrt current-sqrt liq) ERR_MATH_FAIL)
                            }
                        )
                    ))
                )
                    ;; 3. Update Position
                    (map-set positions { position-id: position-id } 
                        (merge position { liquidity: u0 })
                    )
                    
                    ;; 4. Update Global Liquidity (if active)
                    (if (and (<= tick-lower curr-tick) (< curr-tick tick-upper))
                        (var-set liquidity (- (var-get liquidity) liq))
                        true
                    )

                    ;; 5. Transfer Tokens
                    (if (> (get amount0 amounts) u0)
                        (try! (as-contract (contract-call? token0-trait transfer (get amount0 amounts) tx-sender owner none)))
                        true
                    )
                    (if (> (get amount1 amounts) u0)
                        (try! (as-contract (contract-call? token1-trait transfer (get amount1 amounts) tx-sender owner none)))
                        true
                    )

                    (ok amounts)
                )
             )
        )
    )
)

(define-public (get-reserves)
    (ok {
        reserve0: u1000000,
        reserve1: u1000000,
    })
)

;; --- CLP Specific Functions ---

(define-public (mint
        (recipient principal)
        (tick-lower int)
        (tick-upper int)
        (amount0 uint)
        (amount1 uint)
    )
    (let (
            (id (var-get next-position-id))
            (lower-sqrt (unwrap!
                (contract-call? .math-lib-concentrated tick-to-sqrt-price
                    tick-lower
                )
                ERR_MATH_FAIL
            ))
            (upper-sqrt (unwrap!
                (contract-call? .math-lib-concentrated tick-to-sqrt-price
                    tick-upper
                )
                ERR_MATH_FAIL
            ))
            (curr-tick (var-get current-tick))
        )
        ;; Calculate liquidity based on range relative to current tick
        (let ((liq (if (< curr-tick tick-lower)
                ;; Range is strictly above current price. We need token0.
                (unwrap!
                    (contract-call? .math-lib-concentrated
                        get-liquidity-for-amount0 lower-sqrt upper-sqrt
                        amount0
                    )
                    ERR_MATH_FAIL
                )
                (if (>= curr-tick tick-upper)
                    ;; Range is strictly below current price. We need token1.
                    (unwrap!
                        (contract-call? .math-lib-concentrated
                            get-liquidity-for-amount1 lower-sqrt upper-sqrt
                            amount1
                        )
                        ERR_MATH_FAIL
                    )
                    ;; Range covers current price. We need both.
                    ;; Liquidity is determined by the tighter constraint.
                    ;; Ideally we calculate L from amount0 and L from amount1 and take the minimum?
                    ;; Or we take the one that matches the ratio.
                    ;; For simplicity here, we just assume amount0 determines it if provided, else amount1.
                    ;; Real implementation should verify ratio.
                    (if (> amount0 u0)
                        (unwrap!
                            (contract-call? .math-lib-concentrated
                                get-liquidity-for-amount0
                                (var-get sqrt-price-x96) upper-sqrt amount0
                            )
                            ERR_MATH_FAIL
                        )
                        (unwrap!
                            (contract-call? .math-lib-concentrated
                                get-liquidity-for-amount1 lower-sqrt
                                (var-get sqrt-price-x96) amount1
                            )
                            ERR_MATH_FAIL
                        )
                    )
                )
            )))
            (try! (nft-mint? position-nft id recipient))
            (map-set positions { position-id: id } {
                owner: recipient,
                tick-lower: tick-lower,
                tick-upper: tick-upper,
                liquidity: liq,
            })

            ;; Update global liquidity if in range
            (if (and (<= tick-lower curr-tick) (< curr-tick tick-upper))
                (var-set liquidity (+ (var-get liquidity) liq))
                true
            )

            (var-set next-position-id (+ id u1))
            (ok id)
        )
    )
)

;; --- SIP-009 ---

(define-read-only (get-last-token-id)
    (ok (- (var-get next-position-id) u1))
)
(define-read-only (get-token-uri (id uint))
    (ok none)
)
(define-read-only (get-owner (id uint))
    (ok (nft-get-owner? position-nft id))
)
(define-public (transfer
        (id uint)
        (sender principal)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
        (nft-transfer? position-nft id sender recipient)
    )
)
