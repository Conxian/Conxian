;; @desc This contract is responsible for all aspects of position management,
;; including opening, closing, and updating positions. It also handles the
;; logic for calculating position value and P&L.

(use-trait position-manager-trait .dimensional-traits.position-manager-trait)
(use-trait oracle-trait .oracle-pricing.oracle-aggregator-v2-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

(impl-trait .dimensional-traits.position-manager-trait)

;; @constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u8001))
(define-constant ERR_POSITION_NOT_FOUND (err u4000))
(define-constant ERR_INVALID_LEVERAGE (err u4001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u4002))
(define-constant ERR_POSITION_NOT_ACTIVE (err u4003))

;; @data-vars
(define-data-var collateral-manager principal .collateral-manager)
(define-data-var next-position-id uint u0)
(define-map positions
  { id: uint }
  {
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
    is-active: bool,
  }
)
(define-map user-positions
  {
    user: principal,
    asset: principal,
    position-id: uint,
  }
  bool
)
(define-map active-positions
  {
    asset: principal,
    is-long: bool,
    position-id: uint,
  }
  bool
)
(define-map open-interest
  { asset: principal }
  {
    long: uint,
    short: uint,
  }
)

;; --- Public Functions ---
(define-public (open-position
    (asset principal)
    (collateral uint)
    (leverage uint)
    (is-long bool)
    (stop-loss (optional uint))
    (take-profit (optional uint))
  )
  (let (
      (collateral-balance (unwrap!
        (contract-call? .collateral-manager get-balance tx-sender)
        (err u2003)
      ))
      (fee-rate (unwrap!
        (contract-call? .collateral-manager get-protocol-fee-rate)
        (err u2004)
      ))
      (fee (* collateral fee-rate))
      (total-cost (+ collateral fee))
    )
    (asserts! (>= collateral-balance total-cost) (err u2003))
    (try! (contract-call? .collateral-manager withdraw-funds total-cost asset))
    (let (
        (position-id (var-get next-position-id))
        (current-time block-height)
        (price (try! (get-price asset)))
        (position-size (* collateral leverage))
        (current-oi (default-to {
          long: u0,
          short: u0,
        }
          (map-get? open-interest { asset: asset })
        ))
      )
      (map-set positions { id: position-id } {
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
        is-active: true,
      })
      (map-set user-positions {
        user: tx-sender,
        asset: asset,
        position-id: position-id,
      }
        true
      )
      (map-set active-positions {
        asset: asset,
        is-long: is-long,
        position-id: position-id,
      }
        true
      )

      ;; Update Open Interest
      (if is-long
        (map-set open-interest { asset: asset }
          (merge current-oi { long: (+ (get long current-oi) position-size) })
        )
        (map-set open-interest { asset: asset }
          (merge current-oi { short: (+ (get short current-oi) position-size) })
        )
      )

      (var-set next-position-id (+ position-id u1))
      (ok position-id)
    )
  )
)

(define-public (close-position
    (position-id uint)
    (slippage (optional uint))
  )
  (let (
      (position (try! (get-position position-id)))
      (current-time block-height)
      (price (try! (get-price (get asset position))))
      (entry-price (get entry-price position))
      (collateral (get collateral position))
      (is-long (get is-long position))
      (size (get size position))
      (asset (get asset position))
      ;; PnL Calculation
      (price-i (to-int price))
      (entry-i (to-int entry-price))
      (size-i (to-int size))
      (price-diff (if is-long
        (- price-i entry-i)
        (- entry-i price-i)
      ))
      (pnl (/ (* size-i price-diff) entry-i))
      (collateral-i (to-int collateral))
      (total-returned-i (+ collateral-i pnl))
      (total-returned (if (< total-returned-i 0)
        u0
        (to-uint total-returned-i)
      ))
      (current-oi (default-to {
        long: u0,
        short: u0,
      }
        (map-get? open-interest { asset: asset })
      ))
    )
    (asserts! (get is-active position) ERR_POSITION_NOT_ACTIVE)
    (map-set positions { id: position-id }
      (merge position {
        is-active: false,
        last-updated: current-time,
      })
    )
    (map-delete active-positions {
      asset: asset,
      is-long: is-long,
      position-id: position-id,
    })

    ;; Update Open Interest
    (if is-long
      (map-set open-interest { asset: asset }
        (merge current-oi { long: (if (>= (get long current-oi) size)
          (- (get long current-oi) size)
          u0
        ) }
        ))
      (map-set open-interest { asset: asset }
        (merge current-oi { short: (if (>= (get short current-oi) size)
          (- (get short current-oi) size)
          u0
        ) }
        ))
    )
    (try! (as-contract (contract-call? .collateral-manager deposit-funds total-returned
      asset
    )))
    (ok {
      collateral-returned: total-returned,
      pnl: pnl,
    })
  )
)

(define-read-only (get-open-interest (asset principal))
  (ok (default-to {
    long: u0,
    short: u0,
  }
    (map-get? open-interest { asset: asset })
  ))
)

(define-read-only (get-position (position-id uint))
  (match (map-get? positions { id: position-id })
    position (ok position)
    ERR_POSITION_NOT_FOUND
  )
)

(define-public (update-position
    (position-id uint)
    (collateral (optional uint))
    (leverage (optional uint))
    (stop-loss (optional uint))
    (take-profit (optional uint))
  )
  (let ((position (try! (get-position position-id))))
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (let (
        (new-collateral (default-to (get collateral position) collateral))
        (new-leverage (default-to (get leverage position) leverage))
        (new-stop-loss (if (is-some stop-loss)
          stop-loss
          (get stop-loss position)
        ))
        (new-take-profit (if (is-some take-profit)
          take-profit
          (get take-profit position)
        ))
      )
      (map-set positions { id: position-id }
        (merge position {
          collateral: new-collateral,
          leverage: new-leverage,
          stop-loss: new-stop-loss,
          take-profit: new-take-profit,
          last-updated: block-height,
        })
      )
      (ok true)
    )
  )
)

;; --- Private Functions ---
(define-private (get-price (asset principal))
  (match (contract-call? .oracle-aggregator-v2 get-real-time-price asset)
    ok-res (ok ok-res)
    err-code (err err-code)
  )
)
