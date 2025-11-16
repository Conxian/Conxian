;; @desc This contract is responsible for all aspects of position management,
;; including opening, closing, and updating positions. It also handles the
;; logic for calculating position value and P&L.

(use-trait position-manager-trait .position-manager-trait.position-manager-trait)
(use-trait oracle-trait .oracle-aggregator-v2-trait.oracle-aggregator-v2-trait)
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait rbac-trait .base-traits.rbac-trait)

(impl-trait .position-manager-trait.position-manager-trait)

;; @constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u8001))
(define-constant ERR_POSITION_NOT_FOUND (err u4000))
(define-constant ERR_INVALID_LEVERAGE (err u4001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u4002))
(define-constant ERR_POSITION_NOT_ACTIVE (err u4003))

;; @data-vars
(define-data-var next-position-id uint u0)
(define-map positions {id: uint} {
  owner: principal,
  asset: principal,
  collateral: uint,
  size: uint,
  entry-price: uint,
  leverage: uint,
  is-long: bool,
  funding-rate: int,
  last-updated: uint,
  stop-loss: (optional uint),
  take-profit: (optional uint),
  is-active: bool
})
(define-map user-positions {user: principal, asset: principal, position-id: uint} bool)
(define-map active-positions {asset: principal, is-long: bool, position-id: uint} bool)

;; --- Public Functions ---
(define-public (open-position (asset principal) (collateral uint) (leverage uint) (is-long bool) (stop-loss (optional uint)) (take-profit (optional uint)))
  (let (
    (position-id (var-get next-position-id))
    (current-time block-height)
    (price (try! (get-price asset)))
    (position-size (* collateral leverage))
  )
    (map-set positions {id: position-id} {
      owner: tx-sender,
      asset: asset,
      collateral: collateral,
      size: position-size,
      entry-price: price,
      leverage: leverage,
      is-long: is-long,
      funding-rate: 0,
      last-updated: current-time,
      stop-loss: stop-loss,
      take-profit: take-profit,
      is-active: true
    })
    (map-set user-positions {user: tx-sender, asset: asset, position-id: position-id} true)
    (map-set active-positions {asset: asset, is-long: is-long, position-id: position-id} true)
    (var-set next-position-id (+ position-id u1))
    (ok position-id)
  )
)

(define-public (close-position (position-id uint) (slippage (optional uint)))
  (let (
    (position (try! (get-position position-id)))
    (current-time block-height)
    (price (try! (get-price (get position asset))))
    (entry-price (get position entry-price))
    (collateral (get position collateral))
    (is-long (get position is-long))
    (size (get position size))
    (price-diff (if is-long
      (- price entry-price)
      (- entry-price price)
    ))
    (pnl (/ (* size price-diff) entry-price))
    (total-returned (+ collateral pnl))
  )
    (asserts! (get position is-active) ERR_POSITION_NOT_ACTIVE)
    (map-set positions {id: position-id} (merge position {is-active: false, last-updated: current-time}))
    (map-delete active-positions {asset: (get position asset), is-long: is-long, position-id: position-id})
    (ok {collateral-returned: total-returned, pnl: pnl})
  )
)

(define-read-only (get-position (position-id uint))
  (match (map-get? positions {id: position-id})
    position (ok position)
    (err ERR_POSITION_NOT_FOUND)
  )
)

(define-public (update-position (position-id uint) (collateral (optional uint)) (leverage (optional uint)) (stop-loss (optional uint)) (take-profit (optional uint)))
    (let (
        (position (try! (get-position position-id)))
    )
        (asserts! (is-eq tx-sender (get position owner)) ERR_UNAUTHORIZED)
        (let (
            (new-collateral (default-to (get position collateral) collateral))
            (new-leverage (default-to (get position leverage) leverage))
            (new-stop-loss (default-to (get position stop-loss) stop-loss))
            (new-take-profit (default-to (get position take-profit) take-profit))
        )
            (map-set positions {id: position-id} (merge position {
                collateral: new-collateral,
                leverage: new-leverage,
                stop-loss: new-stop-loss,
                take-profit: new-take-profit,
                last-updated: block-height
            }))
            (ok true)
        )
    )
)


;; --- Private Functions ---
(define-private (get-price (asset principal))
  (contract-call? .oracle-aggregator-v2-trait get-real-time-price asset)
)
