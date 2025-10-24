;; position-manager.clar
;; Manages all position types in the dimensional engine

(use-trait position-trait .all-traits.position-trait)
(use-trait risk-trait .all-traits.risk-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait token-trait .all-traits.sip-010-ft-trait)

(use-trait position_trait .all-traits.position-trait)
 .all-traits.position-trait)

;; ===== Type Definitions =====
(define-types
  (position-action (enum
    (OPEN)
    (CLOSE)
    (MODIFY)
    (LIQUIDATE)
  ))
)

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var is-paused bool false)

;; Position events
(define-map position-events {
  owner: principal,
  position-id: uint,
  timestamp: uint
} {
  action: position-action,
  data: (string-utf8 1024),
  block-height: uint,
  tx-sender: principal
})

;; Position data structure (redefined for position manager)
(define-map positions {owner: principal, id: uint} {
  owner: principal,
  id: uint,
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
(define-public (create-position
    (owner principal)
    (collateral-amount uint)
    (leverage uint)
    (position-type position-type)
    (token principal)
    (slippage-tolerance uint)
    (funding-interval funding-interval)
  )
  (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (price (unwrap! (contract-call? .oracle-adapter get-price token) (err u4001)))
    (min-amount-out (/ (* price (- u10000 slippage-tolerance)) u10000))
  )
    (asserts! (not (var-get is-paused)) (err u4000))

    ;; Transfer collateral from user
    (try! (contract-call? token transfer collateral-amount owner (as-contract tx-sender)))

    ;; Create position
    (let (
      (position {
        owner: owner,
        id: position-id,
        collateral: collateral-amount,
        size: (/ (* collateral-amount leverage) u100),
        entry-price: price,
        entry-time: current-block,
        last-funding: current-block,
        last-updated: current-block,
        position-type: position-type,
        status: (position-status ACTIVE),
        funding-interval: funding-interval,
        max-leverage: u2000,
        maintenance-margin: u500,
        time-decay: none,
        volatility: none,
        is-hedged: false,
        tags: [],
        version: u1,
        metadata: (some none)
      })
    )
      ;; Validate position with risk manager
      (try! (contract-call? .risk-manager validate-position position price))

      ;; Store position
      (map-set positions {
        owner: owner,
        id: position-id
      } position)

      ;; Emit event
      (map-set position-events {
        owner: owner,
        position-id: position-id,
        timestamp: current-block
      } {
        action: (position-action OPEN),
        data: (to-json-utf8 {
          collateral: collateral-amount,
          leverage: leverage,
          position-type: position-type,
          entry-price: price
        }),
        block-height: current-block,
        tx-sender: tx-sender
      })

      ;; Increment position ID
      (var-set next-position-id (+ position-id u1))

      (ok position-id)
    )
  )
)

(define-public (close-position
    (owner principal)
    (position-id uint)
    (slippage-tolerance uint)
  )
  (let (
    (position (unwrap! (map-get? positions {owner: owner, id: position-id}) (err u4002)))
    (current-block block-height)
    (price (unwrap! (contract-call? .oracle-adapter get-price position.token) (err u4001)))
    (min-amount-out (/ (* price (- u10000 slippage-tolerance)) u10000))

    ;; Calculate PnL
    (pnl (calculate-pnl position price))
    (total-amount (+ position.collateral pnl))
  )
    (asserts! (is-eq (get status position) (position-status ACTIVE)) (err u4003))

    ;; Transfer funds back to user
    (try! (contract-call? position.token transfer total-amount (as-contract tx-sender) owner))

    ;; Update position status
    (map-set positions {
      owner: owner,
      id: position-id
    } (merge position {
      status: (position-status CLOSED),
      last-updated: current-block
    }))

    ;; Emit event
    (map-set position-events {
      owner: owner,
      position-id: position-id,
      timestamp: current-block
    } {
      action: (position-action CLOSE),
      data: (to-json-utf8 {
        exit-price: price,
        pnl: pnl,
        total-amount: total-amount
      }),
      block-height: current-block,
      tx-sender: tx-sender
    })

    (ok true)
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-position (owner principal) (position-id uint))
  (ok (map-get? positions {owner: owner, id: position-id}))
)

(define-read-only (get-position-events (owner principal) (position-id uint) (limit uint))
  (let (
    (events (map-get-range position-events
      {owner: owner, position-id: position-id, timestamp: u0}
      {owner: owner, position-id: position-id, timestamp: block-height}
      limit
    ))
  )
    (ok events)
  )
)

;; ===== Private Functions =====
(define-private (calculate-pnl
    (position {collateral: uint, size: int, entry-price: uint})
    (current-price uint)
  )
  (let (
    (price-diff (- current-price position.entry-price))
    (position-value (/ (* (abs position.size) current-price) (pow u10 u8)))
  )
    (if (> position.size 0)
      ;; Long position
      (+ position.collateral (/ (* position.size price-diff) position.entry-price))
      ;; Short position
      (+ position.collateral (/ (* position.size price-diff) position.entry-price))
    )
  )
)

