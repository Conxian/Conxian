;; dimensional-engine.clar
;; Core contract for the dimensional engine

(use-trait dimensional-trait .all-traits.dimensional-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait risk-trait .all-traits.risk-trait)
(use-trait token-trait .all-traits.sip-010-ft-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1000))
(define-constant ERR_PAUSED (err u4000))
(define-constant ERR_ORACLE_FAILURE (err u4001))
(define-constant ERR_INVALID_LEVERAGE (err u1005))
(define-constant ERR_INVALID_POSITION (err u1006))
(define-constant ERR_POSITION_NOT_FOUND (err u1007))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1008))
(define-constant ERR_INVALID_SIZE (err u1009))
(define-constant ERR-POSITION-NOT-ACTIVE (err u4003))
(define-constant MAX_LEVERAGE u2000)
(define-constant MAINTENANCE_MARGIN u500)

;; Position constants
(define-constant MIN_LEVERAGE u100)
(define-constant DEFAULT_MAX_LEVERAGE u2000)  ;; 20x
(define-constant DEFAULT_MAINTENANCE_MARGIN u500)  ;; 5%
(define-constant DEFAULT_PROTOCOL_FEE u30)  ;; 0.3%
(define-constant SLIPPAGE_PRECISION u10000)
(define-constant LEVERAGE_PRECISION u100)

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

(define-data-var owner principal CONTRACT_OWNER)
(define-data-var next-position-id uint u0)
(define-data-var is-paused bool false)
(define-data-var protocol-fee-rate uint DEFAULT_PROTOCOL_FEE)
(define-data-var total-positions-opened uint u0)
(define-data-var total-volume uint u0)

(define-data-var max-leverage uint u2000)  ;; 20x
(define-data-var maintenance-margin uint u500)  ;; 5%
(define-data-var liquidation-threshold uint u8000)  ;; 80%
(define-data-var max-position-size uint u1000000000000)  ;; 1M with 6 decimals

(define-data-var min-liquidation-reward uint u100)  ;; 0.1%
(define-data-var max-liquidation-reward uint u1000) ;; 1%
(define-data-var insurance-fund principal tx-sender)

(define-data-var funding-interval uint u144)  ;; Default to daily funding
(define-data-var max-funding-rate uint u100)  ;; 1% max funding rate
(define-data-var funding-rate-sensitivity uint u500)  ;; 5% sensitivity

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map positions 
  { owner: principal, id: uint } 
  {
    collateral: uint,
    size: int,
    entry-price: uint,
    entry-time: uint,
    last-funding: uint,
    last-updated: uint,
    position-type: (string-ascii 16),
    status: (string-ascii 16),
    funding-interval: uint,
    max-leverage: uint,
    maintenance-margin: uint,
    time-decay: (optional uint),
    volatility: (optional uint),
    is-hedged: bool,
    tags: (list 10 (string-utf8 32)),
    version: uint,
    metadata: (optional (string-utf8 1024)),
    realized-pnl: int,
    fees-paid: uint,
    token: principal
  }
)

(define-map user-stats
  { user: principal }
  {
    total-positions: uint,
    active-positions: uint,
    total-volume: uint,
    total-fees: uint
  }
)

(define-map position-events
  {owner: principal, position-id: uint, timestamp: uint}
  {action: (string-ascii 20), data: (string-utf8 1024), block-height: uint, tx-sender: principal}
)

(define-map liquidations {
  position-id: uint,
  timestamp: uint
} {
  liquidator: principal,
  collateral-reclaimed: uint,
  reward: uint,
  price: uint,
  pnl: int
})

(define-map funding-rate-history {
  asset: principal,
  timestamp: uint
} {
  rate: int,  ;; Funding rate in basis points (1 = 0.01%)
  index-price: uint,
  open-interest-long: uint,
  open-interest-short: uint
})

(define-map last-funding-update {
  asset: principal
} {
  timestamp: uint,
  cumulative-funding: int
})

(define-public (validate-position
    (position {collateral: uint, size: int, entry-price: uint})
    (current-price uint)
  )
  (begin
    (let (
      (size-abs-i (abs-int (get size position)))
      (size-abs (to-uint size-abs-i))
      (collateral (get collateral position))
      (notional-value (/ (* size-abs current-price) (pow u10 u8)))  ;; Adjust for decimals
      (leverage (/ (* notional-value u100) collateral))
    )
      ;; Validate leverage
      (asserts! (<= leverage (var-get max-leverage)) (err u2000))

      ;; Validate position size
      (asserts! (<= size-abs (var-get max-position-size)) (err u2001))

      ;; Validate margin requirements
      (let ((initial-margin-required (/ (* notional-value (var-get maintenance-margin)) u10000)))
        (asserts! (>= collateral initial-margin-required) (err u2002))
      )

      (ok true)
    )
  )
)

(define-read-only (get-liquidation-price
    (position {collateral: uint, size: int, entry-price: uint})
  )
  (begin
    (let (
      (size-i (get size position))
      (collateral (get collateral position))
      (is-long (> size-i 0))
      (size-abs (to-uint (abs-int size-i)))

      (liquidation-price
        (if is-long
          ;; Long position liquidation price
          (/ (* (var-get liquidation-threshold) collateral) size-abs)
          ;; Short position liquidation price
          (/ (* collateral (var-get liquidation-threshold))
             (- (* size-abs (var-get liquidation-threshold)) (* collateral u10000)))
        )
      )
    )
      (ok liquidation-price)
    )
  )
)

(define-public (liquidate-position
    (position-owner principal)
    (position-id uint)
    (max-slippage uint)
  )
  (begin
    (let (
        (position (unwrap! (get-position position-owner position-id) (err u4004)))
        (token (get token position))
        (price (unwrap! (contract-call? .oracle-adapter .oracle-trait.get-price token) (err u4005)))
        (caller tx-sender)
        (current-block block-height)
    )
    ;; Verify position can be liquidated
    (asserts! (is-eq (get status position) "ACTIVE") (err u4007))

    ;; Check if position is underwater
    (let (
      (margin-ratio (calculate-margin-ratio position price))
      (maintenance-margin (get maintenance-margin position))
    )
      (asserts! (< margin-ratio maintenance-margin) ERR_POSITION_SAFE)

      ;; Calculate liquidation reward (capped between min and max)
      (let* (
        (collateral-value (get collateral position))
        (reward-amount (min
          (max
            (/ (* collateral-value (var-get min-liquidation-reward)) u10000)
            (var-get min-liquidation-reward)
          )
          (var-get max-liquidation-reward)
        ))
        (remaining-collateral (- collateral-value reward-amount))
      )
        ;; Transfer reward to liquidator via SIP-010
        (try! (as-contract (contract-call? (get token position) .sip-010-ft-trait.transfer reward-amount (as-contract tx-sender) caller none)))

        ;; Transfer remaining collateral to insurance fund
        (try! (as-contract (contract-call? (get token position) .sip-010-ft-trait.transfer remaining-collateral (as-contract tx-sender) (var-get insurance-fund) none)))

        ;; Close the position
        (try! (close-position position-owner position-id u0))

        ;; Record liquidation
        (map-set liquidations {
          position-id: position-id,
          timestamp: current-block
        } {
          liquidator: caller,
          collateral-reclaimed: collateral-value,
          reward: reward-amount,
          price: price,
          pnl: (calculate-pnl (get size position) (get entry-price position) price)
        })

        (ok true)
      )
    )
  )
 )
)

(define-public (update-funding-rate
    (asset principal)
  )
  (begin
    (let (
      (current-time block-height)
      (last-update (default-to
        {timestamp: u0, cumulative-funding: 0}
        (map-get? last-funding-update {asset: asset})
      ))
    )
      ;; Check if enough time has passed since last update
      (asserts!
        (>= (- current-time (get last-update timestamp)) (var-get funding-interval))
        (err u5001)
      )

      ;; Get current index price and TWAP
      (let (
        (index-price (unwrap! (contract-call? .oracle-adapter .oracle-trait.get-price asset) (err u5003)))
        (twap (unwrap! (contract-call? .oracle-adapter .oracle-trait.get-twap asset (var-get funding-interval)) (err u5004)))

        ;; Get open interest (simplified - in a real implementation, this would query position data)
        (open-interest (get-open-interest asset))
        (oi-long (get open-interest long))
        (oi-short (get open-interest short))

        ;; Calculate funding rate based on premium to index
        (premium (calculate-premium index-price twap))
        (funding-rate (calculate-funding-rate premium oi-long oi-short))

        ;; Cap funding rate
        (capped-rate (max
          (min funding-rate (var-get max-funding-rate))
          (* (var-get max-funding-rate) -1)
        ))

        ;; Calculate cumulative funding
        (new-cumulative (+ (get last-update cumulative-funding) capped-rate))
      )
        ;; Update funding rate history
        (map-set funding-rate-history {asset: asset, timestamp: current-time} {
          rate: capped-rate,
          index-price: index-price,
          open-interest-long: oi-long,
          open-interest-short: oi-short
        })

        ;; Update last funding update
        (map-set last-funding-update {asset: asset} {
          timestamp: current-time,
          cumulative-funding: new-cumulative
        })

        (ok {
          funding-rate: capped-rate,
          index-price: index-price,
          timestamp: current-time,
          cumulative-funding: new-cumulative
        })
      )
    )
  )
)

(define-public (apply-funding-to-position
    (position-owner principal)
    (position-id uint)
  )
  (begin
    (let (
      (position (unwrap! (get-position position-owner position-id) (err u5005)))
      (current-time block-height)
      (asset (get asset position))
      (last-update (unwrap! (map-get? last-funding-update {asset: asset}) (err u5006)))
      (position-type (get status position))
    )
      ;; Only perpetuals have funding
      (asserts! (is-eq position-type "PERPETUAL") (err u5007))

      ;; Calculate funding payment
      (let* (
        (size (abs-int (get size position)))
        (funding-rate (get last-update cumulative-funding))
        (funding-payment (/ (* size funding-rate) u10000))  ;; Funding rate is in basis points

        ;; Adjust position collateral
        (new-collateral (- (get collateral position) funding-payment))
      )
        ;; Update position collateral
        (try! (update-position
          position-owner
          position-id
          {collateral: (some new-collateral)}
        ))

        (ok {
          funding-rate: funding-rate,
          funding-payment: funding-payment,
          new-collateral: new-collateral,
          timestamp: current-time
        })
      )
    )
  )
)

(define-private (calculate-premium
    (index-price uint)
    (twap uint)
  )
  (if (> twap u0)
    (/ (* (- index-price twap) u10000) twap)  ;; Premium in basis points
    0
  )
)

(define-private (calculate-funding-rate
    (premium int)
    (oi-long uint)
    (oi-short uint)
  )
  (let (
    (oi-diff (abs (- oi-long oi-short)))
    (oi-total (+ oi-long oi-short))
    (sensitivity (var-get funding-rate-sensitivity))
  )
    (if (> oi-total u0)
      (let (
        (imbalance (/ (* oi-diff u10000) oi-total))
        (funding-rate (/ (* premium (+ u10000 (/ (* imbalance sensitivity) u100))) u10000))
      )
        funding-rate
      )
      0
    )
  )
)

(define-private (get-open-interest (asset principal))
  ;; In a real implementation, this would query position data
  {
    long: u1000000,
    short: u800000
  }
)

;; =============================================================================
;; PRIVATE HELPER FUNCTIONS
;; =============================================================================

(define-private (calculate-position-size (collateral uint) (leverage uint))
  (begin
    "Calculate position size from collateral and leverage"
    (/ (* collateral leverage) LEVERAGE_PRECISION)
  )
)

(define-private (calculate-protocol-fee (amount uint))
  (begin
    "Calculate protocol fee for given amount"
    (/ (* amount (var-get protocol-fee-rate)) u10000)
  )
)

(define-private (update-user-stats (user principal) (volume uint) (fee uint) (is-opening bool))
  (begin
    "Update user statistics"
    (let (
      (stats (default-to
        { total-positions: u0, active-positions: u0, total-volume: u0, total-fees: u0 }
        (map-get? user-stats { user: user })
      ))
    )
      (map-set user-stats
        { user: user }
        {
          total-positions: (if is-opening (+ (get total-positions stats) u1) (get total-positions stats)),
          active-positions: (if is-opening
            (+ (get active-positions stats) u1)
            (if (> (get active-positions stats) u0) (- (get active-positions stats) u1) u0)
          ),
          total-volume: (+ (get total-volume stats) volume),
          total-fees: (+ (get total-fees stats) fee)
        }
      )
    )
  )
)

(define-private (validate-leverage (leverage uint))
  (begin
    "Validate leverage is within acceptable range"
    (and
      (>= leverage MIN_LEVERAGE)
      (<= leverage DEFAULT_MAX_LEVERAGE)
    )
  )
)

(define-private (calculate-pnl (position-size int) (entry-price uint) (current-price uint))
  (begin
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
)

(define-private (emit-position-event
  (position-owner principal)
  (position-id uint)
  (action (string-ascii 20))
  (data (string-utf8 1024))
)
  (begin
    (map-set position-events
      {owner: position-owner, position-id: position-id, timestamp: block-height}
      {action: action, data: data, block-height: block-height, tx-sender: tx-sender}
    )
  )
)

(define-private (abs-int (x int))
  (begin
    (if (>= x 0) x (- 0 x))
  )
)

;; =============================================================================
;; POSITION MANAGEMENT
;; =============================================================================

(define-public (create-position
    (position-owner principal)
    (collateral-amount uint)
    (leverage uint)
    (pos-type (string-ascii 20))
    (token <token-trait>)
    (slippage-tolerance uint)
    (funding-int (string-ascii 20))
  )
  (begin
    (let (
      (position-id (var-get next-position-id))
      (current-block block-height)
      (token-principal (contract-of token))
      (price (unwrap! (contract-call? .oracle-adapter .oracle-trait.get-price token-principal) (err ERR-ORACLE-FAILURE)))
      (position-size (calculate-position-size collateral-amount leverage))
    )
      ;; Validations
      (asserts! (not (var-get is-paused)) (err ERR-PAUSED))
      (asserts! (<= leverage MAX-LEVERAGE) (err ERR-INVALID-LEVERAGE))

      ;; Transfer collateral from user
      (try! (contract-call? token .sip-010-ft-trait.transfer collateral-amount position-owner (as-contract tx-sender) none))

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
          maintenance-margin: MAINTENANCE_MARGIN,
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
        (try! (validate-position new-position price))

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
)

(define-public (close-position
    (position-owner principal)
    (position-id uint)
    (slippage-tolerance uint)
  )
  (begin
    (let (
      (position (unwrap! (map-get? positions {owner: position-owner, id: position-id}) (err ERR-POSITION-NOT-FOUND)))
      (current-block block-height)
      (price (unwrap! (contract-call? .oracle-adapter .oracle-trait.get-price (get token position)) (err ERR-ORACLE-FAILURE)))
      (pnl (calculate-pnl (get size position) (get entry-price position) price))
      (final-amount (if (>= pnl 0)
                        (+ (get collateral position) (to-uint pnl))
                        (- (get collateral position) (to-uint (- 0 pnl)))))
    )
      ;; Validations
      (asserts! (is-eq (get status position) "ACTIVE") (err ERR-POSITION-NOT-ACTIVE))
      (asserts! (is-eq tx-sender position-owner) (err ERR-UNAUTHORIZED))

      ;; Transfer funds back to user
      (try! (as-contract (contract-call? (get token position) .sip-010-ft-trait.transfer final-amount tx-sender position-owner none)))

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
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-position (position-owner principal) (position-id uint))
  (begin
    "Get position details"
    (ok (map-get? positions { owner: position-owner, id: position-id }))
  )
)

(define-read-only (get-user-stats (user principal))
  (begin
    "Get user statistics"
    (ok (map-get? user-stats { user: user }))
  )
)

(define-read-only (get-owner)
  (begin
    "Get contract owner"
    (ok (var-get owner))
  )
)

(define-read-only (get-next-position-id)
  (begin
    "Get next position ID"
    (ok (var-get next-position-id))
  )
)

(define-read-only (is-contract-paused)
  (begin
    "Check if contract is paused"
    (ok (var-get is-paused))
  )
)

(define-read-only (get-protocol-fee-rate)
  (begin
    "Get protocol fee rate"
    (ok (var-get protocol-fee-rate))
  )
)

(define-read-only (get-global-stats)
  (begin
    "Get global contract statistics"
    (ok {
      total-positions: (var-get total-positions-opened),
      total-volume: (var-get total-volume),
      next-position-id: (var-get next-position-id)
    })
  )
)

(define-read-only (calculate-position-value (position-owner principal) (position-id uint) (current-price uint))
  (begin
    "Calculate current position value and PnL"
    (match (map-get? positions { owner: position-owner, id: position-id })
      position (let (
        (entry-price (get entry-price position))
        (position-size (if (> (get size position) 0) (to-uint (get size position)) (to-uint (- 0 (get size position)))))
        (is-long (> (get size position) 0))
        (price-diff (if is-long
          (if (>= current-price entry-price) (- current-price entry-price) (- entry-price current-price))
          (if (>= entry-price current-price) (- entry-price current-price) (- current-price entry-price))
        ))
        (pnl-unsigned (/ (* position-size price-diff) entry-price))
        (pnl (if (and is-long (>= current-price entry-price))
          (to-int pnl-unsigned)
          (if (and (not is-long) (>= entry-price current-price))
            (to-int pnl-unsigned)
            (- 0 (to-int pnl-unsigned))
          )
        ))
      )
        (ok {
          collateral: (get collateral position),
          unrealized-pnl: pnl,
          position-value: (if (>= pnl 0)
            (+ (get collateral position) (to-uint pnl))
            (if (>= (get collateral position) (to-uint (- 0 pnl)))
              (- (get collateral position) (to-uint (- 0 pnl)))
              u0
            )
          )
        })
      )
      (err ERR-POSITION-NOT_FOUND)
    )
  )
)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-owner (new-owner principal))
  (begin
    "Transfer contract ownership"
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_AUTHORIZED)
    (var-set owner new-owner)
    (print { event: "owner-changed", old-owner: tx-sender, new-owner: new-owner })
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    "Pause or unpause contract"
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_AUTHORIZED)
    (var-set is-paused paused)
    (print { event: "pause-status-changed", paused: paused })
    (ok true)
  )
)

(define-public (set-protocol-fee-rate (new-rate uint))
  (begin
    "Update protocol fee rate"
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_POSITION) ;; Max 10%
    (var-set protocol-fee-rate new-rate)
    (print { event: "fee-rate-changed", new-rate: new-rate })
    (ok true)
  )
)
