;; dimensional-engine.clar
;; Core contract for the dimensional engine

(use-trait dimensional-trait .all-traits.dimensional-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait dimensional-engine-trait .all-traits.dimensional-engine-trait)

(impl-trait dimensional-engine-trait)

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
    fees-paid: uint
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

;; =============================================================================
;; PRIVATE HELPER FUNCTIONS
;; =============================================================================

(define-private (calculate-position-size (collateral uint) (leverage uint))
  "Calculate position size from collateral and leverage"
  (/ (* collateral leverage) LEVERAGE_PRECISION)
)

(define-private (calculate-protocol-fee (amount uint))
  "Calculate protocol fee for given amount"
  (/ (* amount (var-get protocol-fee-rate)) u10000)
)

(define-private (update-user-stats (user principal) (volume uint) (fee uint) (is-opening bool))
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

(define-private (validate-leverage (leverage uint))
  "Validate leverage is within acceptable range"
  (and 
    (>= leverage MIN_LEVERAGE)
    (<= leverage DEFAULT_MAX_LEVERAGE)
  )
)

;; =============================================================================
;; POSITION MANAGEMENT
;; =============================================================================

(define-public (open-position
    (collateral-amount uint)
    (leverage uint)
    (position-type (string-ascii 16))
    (slippage-tolerance uint)
    (token <sip-010-ft-trait>)
    (funding-interval uint))
  "Open a new leveraged position with enhanced validation and tracking"
  (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (price (unwrap! (contract-call? .oracle-adapter get-price (contract-of token)) ERR_ORACLE_FAILURE))
    (is-long (or (is-eq position-type "LONG") (is-eq position-type "PERPETUAL")))
    (position-size (calculate-position-size collateral-amount leverage))
    (protocol-fee (calculate-protocol-fee collateral-amount))
    (net-collateral (- collateral-amount protocol-fee))
  )
    ;; Validations
    (asserts! (not (var-get is-paused)) ERR_PAUSED)
    (asserts! (validate-leverage leverage) ERR_INVALID_LEVERAGE)
    (asserts! (> collateral-amount u0) ERR_INVALID_POSITION)
    (asserts! (> net-collateral u0) ERR_INSUFFICIENT_COLLATERAL)
    (asserts! (<= slippage-tolerance SLIPPAGE_PRECISION) ERR_INVALID_POSITION)

    ;; Transfer collateral from user
    (try! (contract-call? token transfer collateral-amount tx-sender (as-contract tx-sender) none))

    ;; Calculate signed size
    (let (
      (signed-size (if is-long (to-int position-size) (- 0 (to-int position-size))))
    )
      (asserts! (not (is-eq signed-size 0)) ERR_INVALID_SIZE)

      ;; Store position
      (map-set positions 
        { owner: tx-sender, id: position-id }
        {
          collateral: net-collateral,
          size: signed-size,
          entry-price: price,
          entry-time: current-block,
          last-funding: current-block,
          last-updated: current-block,
          position-type: position-type,
          status: "ACTIVE",
          funding-interval: funding-interval,
          max-leverage: DEFAULT_MAX_LEVERAGE,
          maintenance-margin: DEFAULT_MAINTENANCE_MARGIN,
          time-decay: none,
          volatility: none,
          is-hedged: false,
          tags: (list),
          version: u1,
          metadata: none,
          realized-pnl: 0,
          fees-paid: protocol-fee
        }
      )

      ;; Update statistics
      (update-user-stats tx-sender position-size protocol-fee true)
      (var-set next-position-id (+ position-id u1))
      (var-set total-positions-opened (+ (var-get total-positions-opened) u1))
      (var-set total-volume (+ (var-get total-volume) position-size))

      (print { 
        event: "position-opened", 
        position-id: position-id, 
        owner: tx-sender, 
        collateral: net-collateral,
        size: signed-size,
        leverage: leverage,
        entry-price: price,
        fee: protocol-fee
      })
      (ok position-id)
    )
  )
)

(define-public (close-position (position-id uint) (token <sip-010-ft-trait>))
  "Close an existing position with PnL calculation"
  (let (
    (position (unwrap! (map-get? positions { owner: tx-sender, id: position-id }) ERR_POSITION_NOT_FOUND))
    (current-price (unwrap! (contract-call? .oracle-adapter get-price (contract-of token)) ERR_ORACLE_FAILURE))
    (entry-price (get entry-price position))
    (position-size (if (> (get size position) 0) (to-uint (get size position)) (to-uint (- 0 (get size position)))))
    (is-long (> (get size position) 0))
  )
    ;; Verify position is active
    (asserts! (is-eq (get status position) "ACTIVE") ERR_INVALID_POSITION)

    ;; Calculate PnL
    (let (
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
      (final-amount (if (>= pnl 0)
        (+ (get collateral position) (to-uint pnl))
        (if (>= (get collateral position) (to-uint (- 0 pnl)))
          (- (get collateral position) (to-uint (- 0 pnl)))
          u0
        )
      ))
    )
      ;; Update position status
      (map-set positions 
        { owner: tx-sender, id: position-id }
        (merge position { 
          status: "CLOSED", 
          last-updated: block-height,
          realized-pnl: pnl
        })
      )

      ;; Return final amount to user
      (if (> final-amount u0)
        (try! (as-contract (contract-call? token transfer final-amount tx-sender tx-sender none)))
        true
      )

      ;; Update user stats
      (update-user-stats tx-sender u0 u0 false)

      (print { 
        event: "position-closed", 
        position-id: position-id, 
        owner: tx-sender,
        exit-price: current-price,
        pnl: pnl,
        final-amount: final-amount
      })
      (ok true)
    )
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-position (owner principal) (position-id uint))
  "Get position details"
  (ok (map-get? positions { owner: owner, id: position-id }))
)

(define-read-only (get-user-stats (user principal))
  "Get user statistics"
  (ok (map-get? user-stats { user: user }))
)

(define-read-only (get-owner)
  "Get contract owner"
  (ok (var-get owner))
)

(define-read-only (get-next-position-id)
  "Get next position ID"
  (ok (var-get next-position-id))
)

(define-read-only (is-contract-paused)
  "Check if contract is paused"
  (ok (var-get is-paused))
)

(define-read-only (get-protocol-fee-rate)
  "Get protocol fee rate"
  (ok (var-get protocol-fee-rate))
)

(define-read-only (get-global-stats)
  "Get global contract statistics"
  (ok {
    total-positions: (var-get total-positions-opened),
    total-volume: (var-get total-volume),
    next-position-id: (var-get next-position-id)
  })
)

(define-read-only (calculate-position-value (owner principal) (position-id uint) (current-price uint))
  "Calculate current position value and PnL"
  (match (map-get? positions { owner: owner, id: position-id })
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
    (err ERR_POSITION_NOT_FOUND)
  )
)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (set-owner (new-owner principal))
  "Transfer contract ownership"
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_AUTHORIZED)
    (var-set owner new-owner)
    (print { event: "owner-changed", old-owner: tx-sender, new-owner: new-owner })
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  "Pause or unpause contract"
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_AUTHORIZED)
    (var-set is-paused paused)
    (print { event: "pause-status-changed", paused: paused })
    (ok true)
  )
)

(define-public (set-protocol-fee-rate (new-rate uint))
  "Update protocol fee rate"
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR_INVALID_POSITION) ;; Max 10%
    (var-set protocol-fee-rate new-rate)
    (print { event: "fee-rate-changed", new-rate: new-rate })
    (ok true)
  )
)
