;; position-manager.clar
;; Manages all position types in the dimensional engine

(use-trait risk-trait .all-traits.risk-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait token-trait .all-traits.sip-010-ft-trait)

;; ===== Constants =====
(define-constant ERR-PAUSED u4000)
(define-constant ERR-ORACLE-FAILURE u4001)
(define-constant ERR-POSITION-NOT-FOUND u4002)
(define-constant ERR-POSITION-NOT-ACTIVE u4003)
(define-constant ERR-UNAUTHORIZED u4004)
(define-constant ERR-INVALID-LEVERAGE u4005)

(define-constant MAX-LEVERAGE u2000)
(define-constant MAINTENANCE-MARGIN u500)
(define-constant BASIS-POINTS u10000)

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var is-paused bool false)

;; ===== Data Maps =====
(define-map position-events 
  {owner: principal, position-id: uint, timestamp: uint}
  {action: (string-ascii 20), data: (string-utf8 1024), block-height: uint, tx-sender: principal}
)

(define-map positions 
  {owner: principal, id: uint}
  {
    owner: principal,
    id: uint,
    collateral: uint,
    size: int,
    entry-price: uint,
    entry-time: uint,
    last-funding: uint,
    last-updated: uint,
    position-type: (string-ascii 20),
    status: (string-ascii 20),
    funding-interval: (string-ascii 20),
    max-leverage: uint,
    maintenance-margin: uint,
    time-decay: (optional uint),
    volatility: (optional uint),
    is-hedged: bool,
    tags: (list 10 (string-utf8 32)),
    version: uint,
    metadata: (optional (string-utf8 1024)),
    token: principal
  }
)

;; ===== Private Helper Functions =====
(define-private (calculate-position-size (collateral uint) (leverage uint))
  (/ (* collateral leverage) u100)
)

(define-private (calculate-min-amount-out (price uint) (slippage-tolerance uint))
  (/ (* price (- BASIS-POINTS slippage-tolerance)) BASIS-POINTS)
)

(define-private (calculate-pnl (position-size int) (entry-price uint) (current-price uint))
  (let (
    (price-diff (if (>= current-price entry-price)
                    (- current-price entry-price)
                    (- entry-price current-price)))
    (is-profit (>= current-price entry-price))
    (abs-size (if (>= position-size 0) position-size (- 0 position-size)))
    (pnl-value (/ (* (to-uint abs-size) price-diff) entry-price))
  )
    (if (and is-profit (>= position-size 0))
        (to-int pnl-value)
        (if (and (not is-profit) (< position-size 0))
            (to-int pnl-value)
            (- 0 (to-int pnl-value))
        )
    )
  )
)

(define-private (emit-position-event 
  (owner principal) 
  (position-id uint) 
  (action (string-ascii 20)) 
  (data (string-utf8 1024))
)
  (map-set position-events
    {owner: owner, position-id: position-id, timestamp: block-height}
    {action: action, data: data, block-height: block-height, tx-sender: tx-sender}
  )
)

;; ===== Core Public Functions =====
(define-public (create-position
    (position-owner principal)
    (collateral-amount uint)
    (leverage uint)
    (pos-type (string-ascii 20))
    (token <token-trait>)
    (slippage-tolerance uint)
    (funding-int (string-ascii 20))
  )
  (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (token-principal (contract-of token))
    (price (unwrap! (contract-call? .oracle-adapter get-price token-principal) (err ERR-ORACLE-FAILURE)))
    (position-size (calculate-position-size collateral-amount leverage))
  )
    ;; Validations
    (asserts! (not (var-get is-paused)) (err ERR-PAUSED))
    (asserts! (<= leverage MAX-LEVERAGE) (err ERR-INVALID-LEVERAGE))

    ;; Transfer collateral from user
    (try! (contract-call? token transfer collateral-amount position-owner (as-contract tx-sender) none))

    ;; Create position tuple
    (let (
      (new-position {
        owner: position-owner,
        id: position-id,
        collateral: collateral-amount,
        size: (to-int position-size),
        entry-price: price,
        entry-time: current-block,
        last-funding: current-block,
        last-updated: current-block,
        position-type: pos-type,
        status: "ACTIVE",
        funding-interval: funding-int,
        max-leverage: MAX-LEVERAGE,
        maintenance-margin: MAINTENANCE-MARGIN,
        time-decay: none,
        volatility: none,
        is-hedged: false,
        tags: (list ),
        version: u1,
        metadata: none,
        token: token-principal
      })
    )
      ;; Validate with risk manager
      (try! (contract-call? .risk-manager validate-position new-position price))

      ;; Store position
      (map-set positions {owner: position-owner, id: position-id} new-position)

      ;; Emit event
      (emit-position-event position-owner position-id "OPEN" u"Position opened")

      ;; Increment position ID
      (var-set next-position-id (+ position-id u1))

      (ok position-id)
    )
  )
)

(define-public (close-position
    (position-owner principal)
    (position-id uint)
    (slippage-tolerance uint)
  )
  (let (
    (position (unwrap! (map-get? positions {owner: position-owner, id: position-id}) (err ERR-POSITION-NOT-FOUND)))
    (current-block block-height)
    (price (unwrap! (contract-call? .oracle-adapter get-price (get token position)) (err ERR-ORACLE-FAILURE)))
    (pnl (calculate-pnl (get size position) (get entry-price position) price))
    (final-amount (if (>= pnl 0)
                      (+ (get collateral position) (to-uint pnl))
                      (- (get collateral position) (to-uint (- 0 pnl)))))
  )
    ;; Validations
    (asserts! (is-eq (get status position) "ACTIVE") (err ERR-POSITION-NOT-ACTIVE))
    (asserts! (is-eq tx-sender position-owner) (err ERR-UNAUTHORIZED))

    ;; Transfer funds back to user
    (try! (as-contract (contract-call? (get token position) transfer final-amount tx-sender position-owner none)))

    ;; Update position status
    (map-set positions
      {owner: position-owner, id: position-id}
      (merge position {status: "CLOSED", last-updated: current-block})
    )

    ;; Emit event
    (emit-position-event position-owner position-id "CLOSE" u"Position closed")

    (ok true)
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-position (position-owner principal) (position-id uint))
  (ok (map-get? positions {owner: position-owner, id: position-id}))
)

(define-read-only (get-position-events (position-owner principal) (position-id uint) (limit uint))
  (ok (map-get? position-events {owner: position-owner, position-id: position-id, timestamp: block-height}))
)

(define-read-only (get-next-position-id)
  (ok (var-get next-position-id))
)

(define-read-only (is-contract-paused)
  (ok (var-get is-paused))
)

;; ===== Admin Functions =====
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR-UNAUTHORIZED))
    (var-set is-paused paused)
    (ok true)
  )
)
