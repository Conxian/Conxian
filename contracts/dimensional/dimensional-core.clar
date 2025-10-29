;; dimensional-core.clar
;; Enhanced with Clarinet 3.8+ features

(use-trait dimensional-trait .all-traits.dimensional-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(impl-trait dimensional-trait)

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

;; ===== Custom Error Codes =====
(define-constant-typed err-unauthorized (err u1000))
(define-constant-typed err-invalid-position (err u1001))
(define-constant-typed err-insufficient-collateral (err u1002))
(define-constant-typed err-slippage (err u1003))
(define-constant-typed err-position-exists (err u1004))
(define-constant-typed err-invalid-leverage (err u1005))
(define-constant-typed err-invalid-position-type (err u1006))
(define-constant-typed err-position-not-active (err u1007))
(define-constant-typed err-invalid-funding-interval (err u1008))

;; ===== Custom Error Messages =====
(define-constant-err MSG_UNAUTHORIZED "Caller is not authorized")
(define-constant-err MSG_INVALID_POSITION "Invalid position")
(define-constant-err MSG_INSUFFICIENT_COLLATERAL "Insufficient collateral")
(define-constant-err MSG_SLIPPAGE "Slippage too high")
(define-constant-err MSG_POSITION_EXISTS "Position already exists")
(define-constant-err MSG_INVALID_LEVERAGE "Invalid leverage")
(define-constant-err MSG_INVALID_POSITION_TYPE "Invalid position type")
(define-constant-err MSG_POSITION_NOT_ACTIVE "Position is not active")
(define-constant-err MSG_INVALID_FUNDING_INTERVAL "Invalid funding interval")

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var is-paused bool false)
(define-data-var protocol-fee-rate uint u30)  ;; 0.3%

;; Enhanced position data structure with dimensional attributes
(define-map positions {owner: principal, id: uint} {
  ;; Core position data
  collateral: uint,
  size: int,                ;; Position size with sign indicating direction
  entry-price: uint,
  entry-time: uint,         ;; Block height when position was opened
  last-funding: uint,       ;; Last block when funding was applied
  last-updated: uint,       ;; Last update block

  ;; Dimensional attributes (using string-ascii for trait compatibility)
  position-type: (string-ascii 20),
  status: (string-ascii 20),
  funding-interval: (string-ascii 20),

  ;; Risk parameters
  max-leverage: uint,
  maintenance-margin: uint,

  ;; Multi-dimensional metrics
  time-decay: (optional uint),  ;; For options and time-based positions
  volatility: (optional uint),  ;; For options and risk calculations

  ;; Flags and metadata
  is-hedged: bool,         ;; Whether position is part of a hedge
  tags: (list 10 (string-utf8 32)),  ;; Custom tags for categorization

  ;; Versioning and upgradeability
  version: uint,           ;; Position version for upgrades

  ;; Additional metadata for future extensibility
  metadata: (optional (string-utf8 1024))
})

;; Position events for better tracking and analytics
(define-map position-events {owner: principal, id: uint, timestamp: uint} {
  event-type: (string-ascii 32),
  data: (string-utf8 1024),
  block-height: uint,
  tx-sender: principal
})

;; Global risk parameters with enhanced structure
(define-map risk-params {position-type: (string-ascii 20)} {
  max-leverage: uint,
  liquidation-threshold: uint,
  funding-rate: uint,         ;; Funding rate in basis points
  maintenance-margin: uint,
  max-position-size: uint,
  min-position-size: uint,
  max-position-value: uint,
  funding-interval: (string-ascii 20),
  is-active: bool             ;; Whether this position type is enabled
})

;; Initialize default risk parameters
(define-public (initialize-risk-params)
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) err-unauthorized)
    
    ;; Initialize risk parameters for different position types
    (map-set risk-params {position-type: "LONG"} {
      max-leverage: u2000,        ;; 20x
      liquidation-threshold: u8000,  ;; 80%
      funding-rate: u10,          ;; 0.1%
      maintenance-margin: u500,   ;; 5%
      max-position-size: u1000000000000,  ;; 1M with 6 decimals
      min-position-size: u10000,  ;; 10 with 6 decimals
      max-position-value: u10000000000000,  ;; 10M with 6 decimals
      funding-interval: "DAILY",
      is-active: true
    })
    
    (map-set risk-params {position-type: "SHORT"} {
      max-leverage: u1500,        ;; 15x
      liquidation-threshold: u8500,  ;; 85%
      funding-rate: u15,          ;; 0.15%
      maintenance-margin: u600,   ;; 6%
      max-position-size: u500000000000,   ;; 500K with 6 decimals
      min-position-size: u10000,  ;; 10 with 6 decimals
      max-position-value: u5000000000000,  ;; 5M with 6 decimals
      funding-interval: "DAILY",
      is-active: true
    })
    
    (ok true)
  )
)

;; ===== Access Control =====
(define-read-only (get-owner)
  (ok (var-get owner))
)

(define-read-only (get-protocol-fee-rate)
  (ok (var-get protocol-fee-rate))
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) err-unauthorized)
    (var-set owner new-owner)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) err-unauthorized)
    (var-set is-paused paused)
    (ok true)
  )
)

(define-public (set-protocol-fee-rate (fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) err-unauthorized)
    (asserts! (<= fee-rate u1000) (err u1009))  ;; Max 10% fee
    (var-set protocol-fee-rate fee-rate)
    (ok true)
  )
)

(define-public (open-position
    (collateral-amount uint)
    (leverage uint)
    (position-type (string-ascii 20))
    (slippage-tolerance uint)
    (token principal)
    (funding-interval (string-ascii 20))
  )
  (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (price (unwrap! (contract-call? .oracle.oracle get-price token) (err u4001)))
    (min-amount-out (/ (* price (- u10000 slippage-tolerance)) u10000))
    (is-long (or (is-eq position-type "LONG") (is-eq position-type "PERPETUAL")))

    ;; Get risk parameters for this position type
    (risk-params (unwrap! (map-get? risk-params {position-type: position-type}) err-invalid-position-type))
  )
    ;; Validate system state
    (asserts! (not (var-get is-paused)) (err u4000))
    (asserts! (get risk-params is-active) err-invalid-position-type
      (err (unwrap! (err-get-msg MSG_INVALID_POSITION_TYPE) (err u1006))))

    ;; Validate position parameters
    (asserts! (>= leverage u100) err-invalid-leverage)
    (asserts! (<= leverage (get risk-params max-leverage)) err-invalid-leverage)
    (asserts! (>= collateral-amount (get risk-params min-position-size)) (err u1011))

    ;; Calculate position size and validate against limits
    (let (
      (position-size (/ (* collateral-amount leverage) u100))
      (signed-size (if is-long position-size (* position-size -1)))
      (position-value (/ (* position-size price) (pow u10 u8)))  ;; Adjust for decimals

      ;; Calculate fees
      (protocol-fee (/ (* collateral-amount (var-get protocol-fee-rate)) u10000))
      (total-collateral (- collateral-amount protocol-fee))
    )
      (asserts! (<= position-size (get risk-params max-position-size)) (err u1012))
      (asserts! (<= position-value (get risk-params max-position-value)) (err u1013))

      ;; Transfer collateral from user (including protocol fee)
      (try! (contract-call? token transfer collateral-amount tx-sender (as-contract tx-sender)))

      ;; Store position with enhanced metadata
      (map-set positions {
        owner: tx-sender,
        id: position-id
      } {
        collateral: total-collateral,
        size: signed-size,
        entry-price: price,
        entry-time: current-block,
        last-funding: current-block,
        last-updated: current-block,
        position-type: position-type,
        status: "ACTIVE",
        funding-interval: funding-interval,
        max-leverage: (get risk-params max-leverage),
        maintenance-margin: (get risk-params maintenance-margin),
        time-decay: none,
        volatility: none,
        is-hedged: false,
        tags: [],
        version: u1,
        metadata: none
      })

      ;; Emit position opened event
      (map-set position-events {
        owner: tx-sender,
        id: position-id,
        timestamp: current-block
      } {
        event-type: "position_opened",
        data: (to-json-utf8 {
          collateral: total-collateral,
          size: signed-size,
          leverage: leverage,
          position-type: position-type,
          entry-price: price,
          funding-interval: funding-interval
        }),
        block-height: current-block,
        tx-sender: tx-sender
      })

      ;; Increment position ID for next position
      (var-set next-position-id (+ position-id u1))

      (ok position-id)
    )
  )
)

(define-read-only (get-constants)
  (ok {
    max-positions: u1000000,
    min-collateral: u1000000,  ;; 1 token with 6 decimals
    maintenance-margin: u1500  ;; 15%
  })
)

(define-public (close-position (position-id uint) (min-amount-out uint))
  (let (
    (position-key {owner: tx-sender, id: position-id})
    (position (unwrap! (map-get? positions position-key) (err ERR_INVALID_POSITION)))
    (current-price (unwrap! (contract-call? .oracle.oracle get-price (get-position-asset position)) (err u4001)))
  )
    (asserts! (is-eq (get position status) "ACTIVE") (err ERR_POSITION_NOT_ACTIVE))

    ;; Calculate PnL
    (let (
      (pnl (calculate-pnl position current-price))
      (total-amount (+ (get position collateral) pnl))
    )
      (asserts! (>= total-amount min-amount-out) (err ERR_SLIPPAGE))

      ;; Mark position as closed
      (map-set positions (merge position-key {
        status: "CLOSED",
        last-updated: block-height
      }))

      ;; Transfer funds back to user
      (try! (as-contract (contract-call? (get-position-asset position) transfer total-amount (as-contract tx-sender) tx-sender none)))

      (ok total-amount)
    )
  )
)

;; ===== Trait Implementation Functions =====

(define-read-only (get-dimensional-state)
  (ok {
    total-positions: (var-get next-position-id),
    active-positions: (count-active-positions),
    total-value-locked: (calculate-tvl),
    system-health: "operational"
  }))

(define-public (update-position (owner principal) (position-id uint) (updates (tuple (collateral (optional uint)) (leverage (optional uint)) (status (optional (string-ascii 20)))))
  (let (
    (position-key {owner: owner, id: position-id})
    (position (unwrap! (map-get? positions position-key) (err ERR_INVALID_POSITION)))
  )
    ;; Only allow position owner or admin to update
    (asserts! (or (is-eq tx-sender owner) (is-eq tx-sender (var-get owner))) (err ERR_UNAUTHORIZED))

    (let (
      (updated-position (merge position {
        collateral: (default-to (get position collateral) (get collateral updates)),
        max-leverage: (default-to (get position max-leverage) (get leverage updates)),
        status: (default-to (get position status) (get status updates))
      }))
    )
      (map-set positions position-key updated-position)
      (ok true)
    )
  )
)

(define-public (force-close-position (owner principal) (position-id uint) (price uint))
  (begin
    ;; Only admin can force close
    (asserts! (is-eq tx-sender (var-get owner)) (err ERR_UNAUTHORIZED))

    (let (
      (position-key {owner: owner, id: position-id})
      (position (unwrap! (map-get? positions position-key) (err ERR_INVALID_POSITION)))
    )
      (asserts! (is-eq (get position status) "ACTIVE") (err ERR_POSITION_NOT_ACTIVE))

      ;; Calculate final PnL and transfer
      (let (
        (pnl (calculate-pnl position price))
        (total-amount (+ (get position collateral) pnl))
      )
        ;; Mark position as closed
        (map-set positions (merge position-key {
          status: "SETTLED",
          last-updated: block-height
        }))

        ;; Transfer funds back to user
        (try! (as-contract (contract-call? (get-position-asset position) transfer total-amount (as-contract tx-sender) owner none)))

        (ok true)
      )
    )
  )
;; ===== Internal Helper Functions =====

(define-private (count-active-positions)
  (let ((active-count u0))
    ;; This is a simplified implementation - in production would iterate through all positions
    active-count
  )
)

(define-private (calculate-tvl)
  (let ((tvl u0))
    ;; This is a simplified implementation - in production would calculate actual TVL
    tvl
  )
)

(define-private (get-position-asset (position {collateral: uint, size: int}))
  ;; In a real implementation, this would return the asset for the position
  ;; For now, we'll use the dimensional token
  'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.dimensional-token
)

(define-private (calculate-pnl
    (position {collateral: uint, size: int, entry-price: uint})
    (current-price uint)
  )
  (let (
    (size-abs (abs (get position size)))
    (price-diff (if (> (get position size) 0)
      (- current-price (get position entry-price))
      (- (get position entry-price) current-price)
    ))
    (pnl-amount (/ (* size-abs price-diff) (get position entry-price)))
  )
    pnl-amount
  )
)
