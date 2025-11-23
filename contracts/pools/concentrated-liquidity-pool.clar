

;; concentrated-liquidity-pool.clar

;; Implements a concentrated liquidity pool for the Conxian DEX.

(use-trait sip-010-ft-trait .01-sip-standards.sip-010-ft-trait)
(use-trait pool-trait .03-defi-primitives.pool-trait)
(use-trait math-trait .10-math-utilities.math-trait)
(use-trait circuit-breaker-trait .09-security-monitoring.circuit-breaker-trait)

;; Error Codes
(define-constant ERR-NOT-AUTHORIZED u1000)
(define-constant ERR-INVALID-POOL-ID u1001)
(define-constant ERR-INVALID-POSITION-ID u1002)
(define-constant ERR-INSUFFICIENT-AMOUNT-X u1003)
(define-constant ERR-INSUFFICIENT-AMOUNT-Y u1004)
(define-constant ERR-INVALID-TICK-RANGE u1005)
(define-constant ERR-SWAP-FAILED u1006)
(define-constant ERR-ZERO-AMOUNT u1007)
(define-constant ERR-PRICE-LIMIT-EXCEEDED u1008)
(define-constant ERR-MATH-ERROR u1009)
(define-constant ERR-TOKEN-MISMATCH u1010)
(define-constant ERR-POOL-ALREADY-EXISTS u1011)
(define-constant ERR-POOL-DOES-NOT-EXIST u1012)
(define-constant ERR-POSITION-DOES-NOT-EXIST u1013)
(define-constant ERR-INVALID-LIQUIDITY u1014)
(define-constant ERR-UNINITIALIZED-TICK u1015)
(define-constant ERR-INVALID-FEE u1016)
(define-constant ERR-INVALID-TICK-SPACING u1017)
(define-constant ERR-INVALID-INITIAL-PRICE u1018)
(define-constant ERR-UNAUTHORIZED-FACTORY u1019)
(define-constant ERR-TRANSFER-FAILED u1020)
(define-constant ERR-MINT-FAILED u1021)
(define-constant ERR-BURN-FAILED u1022)
(define-constant ERR-CIRCUIT-OPEN u1023)

(define-data-var circuit-breaker principal .circuit-breaker)
(define-data-var admin principal tx-sender)
(use-trait sip-009-nft-trait .01-sip-standards.sip-009-nft-trait)
(use-trait rbac-trait .02-core-protocol.rbac-trait)

;; Constants
(define-constant Q128 u340282366920938463463374607431768211455)

;; Data Maps
(define-map pools { pool-id: uint }
  { token-x: principal, token-y: principal, factory: principal, fee-bps: uint,
    tick-spacing: uint, current-tick: int, current-sqrt-price: uint, liquidity: uint,
    fee-growth-global-x: uint, fee-growth-global-y: uint, start-tick: int, end-tick: int })

(define-map positions { position-id: uint }
  { owner: principal, pool-id: uint, tick-lower: int, tick-upper: int, liquidity: uint,
    amount-x: uint, amount-y: uint, fee-growth-inside-last-x: uint, fee-growth-inside-last-y: uint })

(define-map ticks { tick: int }
  { liquidity-gross: uint, liquidity-net: int, fee-growth-outside0: uint,
    fee-growth-outside1: uint, tick-cumulative-outside: uint,
    seconds-per-liquidity-outside: uint, seconds-outside: uint, initialized: bool })

(define-data-var next-pool-id uint u0)
(define-data-var next-position-id uint u0)

;; NFT
(define-non-fungible-token position-nft)

(define-private (mint-position (recipient principal) (position-id uint))
  (nft-mint? position-nft position-id recipient))

(define-private (transfer-position (sender principal) (recipient principal) (position-id uint))
  (nft-transfer? position-nft position-id sender recipient))

(define-private (burn-position (owner principal) (position-id uint))
  (nft-burn? position-nft position-id owner))

(define-private (check-circuit-breaker)
  (contract-call? (var-get circuit-breaker) is-circuit-open)
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

;; ---------------------------------------------------------------------------

;; Private helpers

(define-private (update-liquidity-and-fees-for-range (tick-lower int) (tick-upper int) (liquidity-delta int) (fee-growth-global-x uint) (fee-growth-global-y uint) (current-tick int))
  (begin
    (try! (update-liquidity-and-fees tick-lower liquidity-delta fee-growth-global-x fee-growth-global-y current-tick))
    (try! (update-liquidity-and-fees tick-upper (- i0 liquidity-delta) fee-growth-global-x fee-growth-global-y current-tick))
    (ok true)
  )
)

;; ---------------------------------------------------------------------------
(define-private (update-liquidity-and-fees (tick int) (liquidity-delta int) (fee-growth-global0 uint) (fee-growth-global1 uint) (current-tick int))
  (let ((info (default-to
                { liquidity-gross: u0, liquidity-net: i0, fee-growth-outside0: u0,
                  fee-growth-outside1: u0, tick-cumulative-outside: u0,
                  seconds-per-liquidity-outside: u0, seconds-outside: u0, initialized: false }
                (map-get? ticks { tick: tick }))))
    (map-set ticks { tick: tick }
      (merge info
        { liquidity-gross: (+ (get liquidity-gross info) (abs liquidity-delta)),
          liquidity-net: (+ (get liquidity-net info) liquidity-delta),
          fee-growth-outside0: (if (> tick current-tick)
                                 (get fee-growth-outside0 info)
                                 (- fee-growth-global0 (get fee-growth-outside0 info))),
          fee-growth-outside1: (if (> tick current-tick)
                                 (get fee-growth-outside1 info)
                                 (- fee-growth-global1 (get fee-growth-outside1 info))),
          initialized: true }))
    (ok true)))

;; ---------------------------------------------------------------------------

;; Public liquidity functions

;; ---------------------------------------------------------------------------
(define-public (add-liquidity (pool-id uint) (amount-x-desired uint) (amount-y-desired uint)
                               (amount-x-min uint) (amount-y-min uint) (recipient principal)
                               (tick-lower int) (tick-upper int))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) (err ERR-CIRCUIT-OPEN))
    (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR-POOL-DOES-NOT-EXIST)))
          (pos-id (var-get next-position-id))
          (liquidity u100))

      ;; placeholder
      (var-set next-position-id (+ pos-id u1))
      (map-set positions { position-id: pos-id }
        { owner: recipient, pool-id: pool-id, tick-lower: tick-lower, tick-upper: tick-upper,
          liquidity: liquidity, amount-x: amount-x-desired, amount-y: amount-y-desired,
          fee-growth-inside-last-x: u0, fee-growth-inside-last-y: u0 })
      (try! (mint-position recipient pos-id))
      (try! (update-liquidity-and-fees-for-range tick-lower tick-upper (to-int liquidity)
                                               (get fee-growth-global-x pool) (get fee-growth-global-y pool)
                                               (get current-tick pool)))
      (ok { tokens-minted: liquidity, token-a-used: amount-x-desired,
            token-b-used: amount-y-desired, position-id: pos-id })
    )
  )
)

(define-public (remove-liquidity (position-id uint) (amount-x-min uint) (amount-y-min uint) (recipient principal))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) (err ERR-CIRCUIT-OPEN))
    (let ((pos (unwrap! (map-get? positions { position-id: position-id }) (err ERR-POSITION-DOES-NOT-EXIST)))
          (pool (unwrap! (map-get? pools { pool-id: (get pool-id pos) }) (err u404))))
      (asserts! (is-eq tx-sender (get owner pos)) (err ERR-NOT-AUTHORIZED))
      (map-delete positions { position-id: position-id })
      (try! (burn-position tx-sender position-id))
      (try! (update-liquidity-and-fees-for-range (get tick-lower pos) (get tick-upper pos) (to-int (- u0 (get liquidity pos)))
                                               (get fee-growth-global-x pool) (get fee-growth-global-y pool)
                                               (get current-tick pool)))
      (ok { amount-x: u100, amount-y: u100 })
    )
  )
) 

;; placeholder

;; @desc Get the pool's token pair
;; @returns (response (tuple (token-x principal) (token-y principal)) uint): token pair and error code
(define-read-only (get-tokens (pool-id uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR-POOL-DOES-NOT-EXIST))))
    (ok { token-x: (get token-x pool), token-y: (get token-y pool) })))

;; @desc Get the pool's fee tier
;; @returns (response uint uint): fee in basis points and error code
(define-read-only (get-fee (pool-id uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR-POOL-DOES-NOT-EXIST))))
    (ok (get fee-bps pool))))

;; @desc Get pool liquidity for a token
;; @param token: token to check liquidity for
;; @returns (response uint uint): liquidity amount and error code
(define-read-only (get-liquidity (pool-id uint) (token principal))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR-POOL-DOES-NOT-EXIST))))
    (if (is-eq token (get token-x pool))
      (ok (get liquidity pool))
      (if (is-eq token (get token-y pool))
        (ok (get liquidity pool))
        (err u404)))))

;; Swap

;; ---------------------------------------------------------------------------
(define-public (swap (pool-id uint) (token-x <sip-010-ft-trait>) (token-y <sip-010-ft-trait>)
                     (zero-for-one bool) (amount-specified uint) (limit-sqrt-price uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) (err ERR-CIRCUIT-OPEN))
    (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err ERR-POOL-DOES-NOT-EXIST))))
          (token-x-principal (contract-of token-x))
          (token-y-principal (contract-of token-y))
          (fee-bps (get fee-bps pool))
          (current-sqrt-price (get current-sqrt-price pool))
          (current-tick (get current-tick pool))
          (liquidity (get liquidity pool))
          (fee-growth-global-x (get fee-growth-global-x pool))
          (fee-growth-global-y (get fee-growth-global-y pool)))
      (asserts! (is-eq token-x-principal (get token-x pool)) (err ERR-TOKEN-MISMATCH))
      (asserts! (is-eq token-y-principal (get token-y pool)) (err ERR-TOKEN-MISMATCH))
      (asserts! (> amount-specified u0) (err ERR-ZERO-AMOUNT))
      (if zero-for-one
        (asserts! (> current-sqrt-price limit-sqrt-price) (err ERR-PRICE-LIMIT-EXCEEDED))
        (asserts! (< current-sqrt-price limit-sqrt-price) (err ERR-PRICE-LIMIT-EXCEEDED)))


      ;; placeholder swap logic
      (let ((amount-in amount-specified)
            (amount-out u99)
            (total-fee (/ (* amount-in fee-bps) u10000)))
        (map-set pools { pool-id: pool-id }
          (merge pool
            { current-sqrt-price: limit-sqrt-price,
              current-tick: (unwrap! (contract-call? .math-lib-concentrated get-tick-from-sqrt-price limit-sqrt-price (get tick-spacing pool)) (err u700)),
              fee-growth-global-x: (+ fee-growth-global-x (if zero-for-one total-fee u0)),
              fee-growth-global-y: (+ fee-growth-global-y (if zero-for-one u0 total-fee)) }))
        (if zero-for-one
          (begin
            (try! (contract-call? token-x transfer amount-in tx-sender (as-contract tx-sender)))
            (try! (contract-call? token-y transfer amount-out (as-contract tx-sender) tx-sender)))
          (begin
            (try! (contract-call? token-y transfer amount-in tx-sender (as-contract tx-sender)))
            (try! (contract-call? token-x transfer amount-out (as-contract tx-sender) tx-sender))))
        (print { type: "swap", pool-id: pool-id, zero-for-one: zero-for-one,
                amount-in: amount-in, amount-out: amount-out, next-sqrt-price: limit-sqrt-price })
        (ok u1)
      )
    )
  )
)

;; ---------------------------------------------------------------------------

;; Pool trait adapters

;; ---------------------------------------------------------------------------
(define-public (add-liquidity-trait-adapter (amount-a uint) (amount-b uint) (recipient principal))
  (let ((result (add-liquidity (var-get next-pool-id) amount-a amount-b u0 u0 recipient u0 u0)))
    (match result
      ok-val (ok { tokens-minted: (get tokens-minted ok-val),
                   token-a-used: (get token-a-used ok-val),
                   token-b-used: (get token-b-used ok-val) })
      err-val (err err-val))))

(define-public (remove-liquidity-trait-adapter (amount-lp uint) (sender principal))
  (let ((result (remove-liquidity (var-get next-pool-id) u0 u0 sender)))
    (match result
      ok-val (ok { token-a-withdrawn: (get amount-x ok-val),
                   token-b-withdrawn: (get amount-y ok-val) })
      err-val (err err-val))))

(define-public (swap-trait-adapter (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>)
                                   (amount-in uint) (min-amount-out uint) (recipient principal))
  (let ((pool-id (var-get next-pool-id))
        (pool (unwrap! (map-get? pools { pool-id: pool-id }) (err u404)))
        (zero-for-one (is-eq (contract-of token-in) (get token-x pool))))
    (swap pool-id token-in token-out zero-for-one amount-in u0)))

(define-public (get-reserves-trait-adapter (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>))
  (let ((pool-id (var-get next-pool-id))
        (pool (unwrap! (map-get? pools { pool-id: pool-id }) (err u404))))
    (ok { reserve-a: (get amount-x pool), reserve-b: (get amount-y pool) })))

(define-public (get-total-supply-trait-adapter) (ok u0))

;; ---------------------------------------------------------------------------

(define-read-only (get-sqrt-price-from-tick (tick int))
  (contract-call? .math-lib-concentrated get-sqrt-price-from-tick tick)
)

(define-read-only (get-tick-from-sqrt-price (sqrt-price uint) (tick-spacing uint))
  (contract-call? .math-lib-concentrated get-tick-from-sqrt-price sqrt-price tick-spacing)
)

(define-read-only (calculate-fee-growth-inside (tick-lower int) (tick-upper int) (current-tick int) (fee-growth-global-x uint) (fee-growth-global-y uint))
  (let ((fee-growth-below-x (unwrap-panic (contract-call? .math-lib-concentrated get-fee-growth-outside tick-lower current-tick fee-growth-global-x)))
        (fee-growth-below-y (unwrap-panic (contract-call? .math-lib-concentrated get-fee-growth-outside tick-lower current-tick fee-growth-global-y)))
        (fee-growth-above-x (unwrap-panic (contract-call? .math-lib-concentrated get-fee-growth-outside tick-upper current-tick fee-growth-global-x)))
        (fee-growth-above-y (unwrap-panic (contract-call? .math-lib-concentrated get-fee-growth-outside tick-upper current-tick fee-growth-global-y))))
    (ok {
      fee-growth-inside-x: (- (- fee-growth-global-x fee-growth-below-x) fee-growth-above-x),
      fee-growth-inside-y: (- (- fee-growth-global-y fee-growth-below-y) fee-growth-above-y)
    })
  )
)

;; Pool creation

;; ---------------------------------------------------------------------------
(define-public (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>)
                            (factory-address principal) (fee-bps uint) (tick-spacing uint)
                            (start-tick int) (end-tick int) (initial-price uint))
  (let ((pool-id (var-get next-pool-id)))
    (asserts! (is-eq tx-sender factory-address) (err ERR-UNAUTHORIZED-FACTORY))
    (map-set pools { pool-id: pool-id }
      { token-x: (contract-of token-a), token-y: (contract-of token-b),
        factory: factory-address, fee-bps: fee-bps, tick-spacing: tick-spacing,
        current-tick: start-tick, current-sqrt-price: initial-price, liquidity: u0,
        fee-growth-global-x: u0, fee-growth-global-y: u0,
        start-tick: start-tick, end-tick: end-tick })
    (var-set next-pool-id (+ pool-id u1))
    (ok pool-id)))

;; ---------------------------------------------------------------------------

;; End of Selection
