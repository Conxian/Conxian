

;; concentrated-liquidity-pool.clar

;; Implements a concentrated liquidity pool for the Conxian DEX.

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait pool-trait .all-traits.pool-trait)
(use-trait math-trait .all-traits.math-trait)
(use-trait error-codes-trait .all-traits.error-codes-trait)
(use-trait sip-009-nft-trait .all-traits.sip-009-nft-trait)

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

;; ---------------------------------------------------------------------------

;; Private helpers

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
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err u404)))
        (pos-id (var-get next-position-id))
        (liquidity u100)) 

;; placeholder
    (var-set next-position-id (+ pos-id u1))
    (map-set positions { position-id: pos-id }
      { owner: recipient, pool-id: pool-id, tick-lower: tick-lower, tick-upper: tick-upper,
        liquidity: liquidity, amount-x: amount-x-desired, amount-y: amount-y-desired,
        fee-growth-inside-last-x: u0, fee-growth-inside-last-y: u0 })
    (try! (mint-position recipient pos-id))
    (try! (update-liquidity-and-fees tick-lower (to-int liquidity)
                                     (get fee-growth-global-x pool) (get fee-growth-global-y pool)
                                     (get current-tick pool)))
    (try! (update-liquidity-and-fees tick-upper (to-int (- u0 liquidity))
                                     (get fee-growth-global-x pool) (get fee-growth-global-y pool)
                                     (get current-tick pool)))
    (ok { tokens-minted: liquidity, token-a-used: amount-x-desired,
          token-b-used: amount-y-desired, position-id: pos-id })))

(define-public (remove-liquidity (position-id uint) (amount-x-min uint) (amount-y-min uint) (recipient principal))
  (let ((pos (unwrap! (map-get? positions { position-id: position-id }) (err u404))))
    (asserts! (is-eq tx-sender (get owner pos)) (err u403))
    (map-delete positions { position-id: position-id })
    (try! (burn-position tx-sender position-id))
    (let ((pool (unwrap! (map-get? pools { pool-id: (get pool-id pos) }) (err u404))))
      (try! (update-liquidity-and-fees (get tick-lower pos) (to-int (- u0 (get liquidity pos)))
                                       (get fee-growth-global-x pool) (get fee-growth-global-y pool)
                                       (get current-tick pool)))
      (try! (update-liquidity-and-fees (get tick-upper pos) (to-int (get liquidity pos))
                                       (get fee-growth-global-x pool) (get fee-growth-global-y pool)
                                       (get current-tick pool))))
    (ok { amount-x: u100, amount-y: u100 }))) 

;; placeholder

;; @desc Retrieves the total liquidity supply for a given pool.
;; @param pool-id The ID of the pool.
;; @returns An `(ok uint)` result containing the total liquidity, or an error.
(define-public (get-total-supply (pool-id uint))
  (match (map-get? pools {pool-id: pool-id})
    pool (ok (get liquidity pool))
    (err u404) ;; Using u404 as a placeholder for ERR_POOL_NOT_FOUND
  )
)

;; Swap

;; ---------------------------------------------------------------------------
(define-public (swap (pool-id uint) (token-x <sip-010-ft-trait>) (token-y <sip-010-ft-trait>)
                     (zero-for-one bool) (amount-specified uint) (limit-sqrt-price uint))
  (let ((pool (unwrap! (map-get? pools { pool-id: pool-id }) (err u404)))
        (token-x-principal (contract-of token-x))
        (token-y-principal (contract-of token-y))
        (fee-bps (get fee-bps pool))
        (current-sqrt-price (get current-sqrt-price pool))
        (current-tick (get current-tick pool))
        (liquidity (get liquidity pool))
        (fee-growth-global-x (get fee-growth-global-x pool))
        (fee-growth-global-y (get fee-growth-global-y pool)))
    (asserts! (is-eq token-x-principal (get token-x pool)) (err u500))
    (asserts! (is-eq token-y-principal (get token-y pool)) (err u500))
    (asserts! (> amount-specified u0) (err u400))
    (if zero-for-one
      (asserts! (> current-sqrt-price limit-sqrt-price) (err u600))
      (asserts! (< current-sqrt-price limit-sqrt-price) (err u600)))
    

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
      (ok u1))))

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

;; Pool creation

;; ---------------------------------------------------------------------------
(define-public (create-pool (token-a <sip-010-ft-trait>) (token-b <sip-010-ft-trait>)
                            (factory-address principal) (fee-bps uint) (tick-spacing uint)
                            (start-tick int) (end-tick int) (initial-price uint))
  (let ((pool-id (var-get next-pool-id)))
    (asserts! (is-eq tx-sender factory-address) (err u403))
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
