;; cxd-bonding-curve-amm.clar
;; Minimal placeholder implementation for CXD bonding curve AMM

(use-trait token-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait governance-token-trait .governance-token-trait.governance-token-trait)
(use-trait price-initializer-trait .price-initializer-trait.price-initializer-trait)

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_INPUT (err u1001))
(define-constant ERR_NOT_INITIALIZED (err u1002))
(define-constant ERR_PAUSED (err u1003))
(define-constant ERR_NO_LIQUIDITY (err u1004))
(define-constant PRECISION u1000000)

(define-data-var contract-owner principal tx-sender)
(define-data-var is-initialized bool false)
(define-data-var is-paused bool false)
(define-data-var cxd-token (optional principal) none)
(define-data-var stx-token (optional principal) none)
(define-data-var price-initializer (optional principal) none)
(define-data-var protocol-fee-receiver (optional principal) none)
(define-data-var fee-rate uint u3000)
(define-data-var cached-price (optional uint) none)
(define-data-var cached-min-price (optional uint) none)
(define-data-var cached-last-updated (optional uint) none)

(define-map reserves { token: principal } { amount: uint })


(define-private (ensure-owner (caller principal))
  (asserts! (is-eq caller (var-get contract-owner)) ERR_UNAUTHORIZED))

(define-private (ensure-initialized)
  (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED))

(define-private (ensure-not-paused)
  (asserts! (not (var-get is-paused)) ERR_PAUSED))

(define-private (get-reserve (token principal))
  (match (map-get? reserves { token: token })
    reserve (get reserve amount)
    u0))

(define-private (set-reserve (token principal) (amount uint))
  (map-set reserves { token: token } { amount: amount }))

(define-private (update-price-cache (price-data (tuple (price uint) (min-price uint) (last-updated uint))))
  (begin
    (var-set cached-price (some (get price price-data)))
    (var-set cached-min-price (some (get min-price price-data)))
    (var-set cached-last-updated (some (get last-updated price-data)))
    price-data))

(define-public (initialize
  (cxd principal)
  (stx principal)
  (initializer principal)
  (fee-recipient principal))
  (begin
    (ensure-owner tx-sender)
    (asserts! (not (var-get is-initialized)) ERR_INVALID_INPUT)
    (var-set cxd-token (some cxd))
    (var-set stx-token (some stx))
    (var-set price-initializer (some initializer))
    (let ((price-data (try! (contract-call? initializer get-price-with-minimum))))
      (update-price-cache price-data))
    (var-set protocol-fee-receiver (some fee-recipient))
    (var-set is-initialized true)
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (ensure-owner tx-sender)
    (asserts! (not (is-eq new-owner tx-sender)) ERR_INVALID_INPUT)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (refresh-price)
  (begin
    (ensure-initialized)
    (let ((initializer (unwrap! (var-get price-initializer) ERR_NOT_INITIALIZED)))
      (let ((price-data (try! (contract-call? initializer get-price-with-minimum))))
        (update-price-cache price-data)
        (ok true)))))

(define-read-only (get-price)
  (let ((price-opt (var-get cached-price))
        (min-price-opt (var-get cached-min-price))
        (last-updated-opt (var-get cached-last-updated)))
    (asserts! (and (is-some price-opt) (and (is-some min-price-opt) (is-some last-updated-opt))) ERR_NOT_INITIALIZED)
    (ok {
      price: (unwrap-panic price-opt),
      min-price: (unwrap-panic min-price-opt),
      last-updated: (unwrap-panic last-updated-opt)
    })))

(define-read-only (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint))
  (if (or (is-eq reserve-in u0) (is-eq reserve-out u0))
    (err ERR_NO_LIQUIDITY)
    (ok (/ (* amount-in reserve-out) (+ reserve-in amount-in)))))

(define-read-only (get-amount-in (amount-out uint) (reserve-in uint) (reserve-out uint))
  (if (or (is-eq reserve-in u0) (>= amount-out reserve-out))
    (err ERR_INVALID_INPUT)
    (ok (/ (* amount-out reserve-in) (- reserve-out amount-out)))))

(define-public (swap (token-in principal) (amount-in uint) (min-amount-out uint))
  (begin
    (ensure-initialized)
    (ensure-not-paused)
    (asserts! (> amount-in u0) ERR_INVALID_INPUT)
    (let ((cxd (unwrap! (var-get cxd-token) ERR_NOT_INITIALIZED))
          (stx (unwrap! (var-get stx-token) ERR_NOT_INITIALIZED)))
      (asserts! (or (is-eq token-in cxd) (is-eq token-in stx)) ERR_INVALID_INPUT)
      (let ((token-out (if (is-eq token-in cxd) stx cxd))
            (reserve-in (get-reserve token-in))
            (reserve-out (get-reserve token-out)))
        (let ((amount-out (unwrap! (get-amount-out amount-in reserve-in reserve-out) ERR_NO_LIQUIDITY)))
          (asserts! (>= amount-out min-amount-out) ERR_INVALID_INPUT)
          (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
          (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))
          (set-reserve token-in (+ reserve-in amount-in))
          (set-reserve token-out (if (> reserve-out amount-out) (- reserve-out amount-out) u0))
          (print {
            token_in: token-in,
            amount_in: amount-in,
            token_out: token-out,
            amount_out: amount-out,
            fee: u0
          })
          (ok amount-out))))))

(define-public (add-liquidity (token principal) (amount uint))
  (begin
    (ensure-initialized)
    (ensure-not-paused)
    (asserts! (> amount u0) ERR_INVALID_INPUT)
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    (set-reserve token (+ (get-reserve token) amount))
    (print {
      event: "liquidity",
      provider: tx-sender,
      token: token,
      amount: amount,
      shares: amount
    })
    (ok amount)))

(define-public (set-fee-rate (new-fee uint))
  (begin
    (ensure-owner tx-sender)
    (asserts! (<= new-fee PRECISION) ERR_INVALID_INPUT)
    (var-set fee-rate new-fee)
    (ok true)))

(define-public (pause (should-pause bool))
  (begin
    (ensure-owner tx-sender)
    (var-set is-paused should-pause)
    (ok true)))

(define-read-only (get-reserves)
  (let ((cxd (unwrap! (var-get cxd-token) ERR_NOT_INITIALIZED))
        (stx (unwrap! (var-get stx-token) ERR_NOT_INITIALIZED)))
    (ok {
      cxd-reserve: (get-reserve cxd),
      stx-reserve: (get-reserve stx),
      fee-rate: (var-get fee-rate),
      is-paused: (var-get is-paused)
    })))

(define-read-only (sqrt (value uint))
  (if (or (<= value u1) (>= value u340282366920938463463374607431768211455))
    value
    (let ((guess (/ value u2)))
      (/ (+ guess (/ value guess)) u2))))
