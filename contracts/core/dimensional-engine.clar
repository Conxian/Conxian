;; dimensional-engine.clar
;; Core contract for the dimensional engine

(use-trait dimensional-trait .all-traits.dimensional-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait token-trait .all-traits.sip-010-ft-trait)

(use-trait dimensional_trait .all-traits.dimensional-trait)
(use-trait dimensional-trait .all-traits.dimensional-trait)

;; ===== Type Definitions =====
(define-types
  (position-type (enum
    (LONG)
    (SHORT)
    (PERPETUAL)
    (OPTION)
  ))

  (position-status (enum
    (ACTIVE)
    (LIQUIDATED)
    (CLOSED)
    (SETTLED)
  ))

  (funding-interval (enum
    (HOURLY u6)       ;; 6 blocks
    (DAILY u144)      ;; 144 blocks
    (WEEKLY u1008)    ;; 1008 blocks
  ))
)

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var is-paused bool false)
(define-data-var protocol-fee-rate uint u30)  ;; 0.3%

;; Position data structure
(define-map positions {owner: principal, id: uint} {
  collateral: uint,
  size: int,
  entry-price: uint,
  entry-time: uint,
  last-funding: uint,
  last-updated: uint,
  position-type: position-type,
  status: position-status,
  funding-interval: funding-interval,
  max-leverage: uint,
  maintenance-margin: uint,
  time-decay: (optional uint),
  volatility: (optional uint),
  is-hedged: bool,
  tags: (list 10 (string-utf8 32)),
  version: uint,
  metadata: (optional (string-utf8 1024))
})

;; ===== Core Functions =====
(define-public (open-position
    (collateral-amount uint)
    (leverage uint)
    (position-type position-type)
    (slippage-tolerance uint)
    (token principal)
    (funding-interval funding-interval)
  )
  (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (price (unwrap! (contract-call? .oracle-adapter get-price token) (err u4001)))
    (min-amount-out (/ (* price (- u10000 slippage-tolerance)) u10000))
    (is-long (or (is-eq position-type LONG) (is-eq position-type PERPETUAL)))
  )
    (asserts! (not (var-get is-paused)) (err u4000))
    (asserts! (>= leverage u100) (err u1005))

    ;; Transfer collateral from user
    (try! (contract-call? token transfer collateral-amount tx-sender (as-contract tx-sender)))

    ;; Calculate position size
    (let (
      (position-size (/ (* collateral-amount leverage) u100))
      (signed-size (if is-long position-size (* position-size -1)))
    )
      ;; Store position
      (map-set positions {
        owner: tx-sender,
        id: position-id
      } {
        collateral: collateral-amount,
        size: signed-size,
        entry-price: price,
        entry-time: current-block,
        last-funding: current-block,
        last-updated: current-block,
        position-type: position-type,
        status: (position-status ACTIVE),
        funding-interval: funding-interval,
        max-leverage: u2000,  ;; Default 20x
        maintenance-margin: u500,  ;; 5%
        time-decay: none,
        volatility: none,
        is-hedged: false,
        tags: [],
        version: u1,
        metadata: none
      })

      ;; Increment position ID
      (var-set next-position-id (+ position-id u1))

      (ok position-id)
    )
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-position (owner principal) (position-id uint))
  (ok (map-get? positions {owner: owner, id: position-id}))
)

(define-read-only (get-owner)
  (ok (var-get owner))
)

;; ===== Admin Functions =====
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))
    (var-set owner new-owner)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u1000))
    (var-set is-paused paused)
    (ok true)
  )
)
