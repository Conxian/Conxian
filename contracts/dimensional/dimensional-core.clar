;;; # Dimensional Core Contract
;;; 
;;; Core contract for managing dimensional positions with advanced risk management.
;;; Implements position management, risk controls, and protocol fee collection.
;;;
;;; Version: 1.0.0
;;; Conforms to: Clarinet SDK 3.9+, Nakamoto Standard

;; Standard traits
(use-trait oracle-trait .oracle-pricing.oracle-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait finance-metrics-trait .math-utilities.finance-metrics-trait)
(use-trait pausable-trait .core-protocol.pausable-trait)
(use-trait access-control-trait .core-protocol.rbac-trait)
(use-trait circuit-breaker-trait .monitoring-security-traits.circuit-breaker-trait)

;; ===== Constants =====
(define-constant CONTRACT_VERSION "1.0.0")
(define-constant MAX_LEVERAGE u100)  ;; 100x max leverage
(define-constant MIN_COLLATERAL u1000)  ;; Minimum collateral amount
(define-constant PROTOCOL_FEE_DENOMINATOR u10000)  ;; Basis points (1 = 0.01%)

;; ===== Type Definitions =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var next-position-id uint u0)
(define-data-var protocol-fee-rate uint u30)  ;; 0.3% in basis points (30/10000)
(define-data-var dimensional-token principal tx-sender)
(define-data-var total-value-locked uint u0)
(define-data-var total-positions-opened uint u0)
(define-data-var total-positions-closed uint u0)


;; ===== Error Codes (Dimensional Core: 2000-2099) =====
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_INVALID_POSITION (err u2002))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u2003))
(define-constant ERR_SLIPPAGE (err u2004))
(define-constant ERR_POSITION_EXISTS (err u2005))
(define-constant ERR_INVALID_LEVERAGE (err u2006))
(define-constant ERR_INVALID_POSITION_TYPE (err u2007))
(define-constant ERR_POSITION_NOT_ACTIVE (err u2008))
(define-constant ERR_INVALID_FUNDING_INTERVAL (err u2009))
(define-constant ERR_ORACLE_ERROR (err u2010))
(define-constant ERR_INVALID_AMOUNT (err u2011))
(define-constant ERR_POSITION_LIQUIDATED (err u2012))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u2013))
(define-constant ERR_UNWRAP_FAILED (err u2018))

;; ===== Custom Error Messages =====
(define-constant MSG-UNAUTHORIZED "Caller is not authorized")
(define-constant MSG-INVALID_POSITION "Invalid position")
(define-constant MSG-INSUFFICIENT_COLLATERAL "Insufficient collateral")
(define-constant MSG-SLIPPAGE "Slippage too high")
(define-constant MSG-POSITION_EXISTS "Position already exists")
(define-constant MSG-INVALID_LEVERAGE "Invalid leverage")
(define-constant MSG-INVALID_POSITION_TYPE "Invalid position type")
(define-constant MSG-POSITION_NOT_ACTIVE "Position is not active")
(define-constant MSG-INVALID_FUNDING_INTERVAL "Invalid funding interval")
(define-constant MSG-ORACLE_ERROR "Oracle error")

;; ===== Position Data Structure =====
;; ===== Data Structures =====
(define-data-var positions-version uint u1)

(define-map positions {owner: principal, id: uint} {
  collateral: uint,                ;; Collateral amount in base token
  size: int,                      ;; Position size (positive for long, negative for short)
  entry-price: uint,              ;; Entry price with oracle precision
  entry-time: uint,               ;; Block height when position was opened
  last-funding: uint,             ;; Last funding payment block
  last-updated: uint,             ;; Last update block
  position-type: (string-ascii 20), ;; "LONG" | "SHORT" | "PERPETUAL"
  status: (string-ascii 20),      ;; "ACTIVE" | "CLOSED" | "LIQUIDATED"
  funding-interval: (string-ascii 20),  ;; "HOURLY" | "DAILY" | "WEEKLY"
  max-leverage: uint,             ;; Maximum allowed leverage (1-100x)
  maintenance-margin: uint,       ;; Maintenance margin in basis points
  time-decay: (optional uint),    ;; Time decay factor if applicable
  volatility: (optional uint),    ;; Volatility factor if applicable
  is-hedged: bool,               ;; If position is hedged against other positions
  tags: (list 10 (string-utf8 32)), ;; Position tags for categorization
  version: uint,                  ;; Schema version for future upgrades
  metadata: (optional (string-utf8 1024)) ;; Additional metadata
})

;; Track position IDs by owner for efficient lookup
(define-map position-ids principal (list 1000 uint))

;; Track open positions by token for risk management
(define-map token-positions principal {long: uint, short: uint})

;; ===== Access Control & System Settings =====
(define-read-only (get-owner)
  (ok (var-get owner)))

(define-read-only (get-protocol-fee-rate)
  (ok (var-get protocol-fee-rate)))

(define-read-only (get-oracle-contract)
  (ok (var-get oracle-contract-principal)))

(define-read-only (get-total-positions)
  (ok {
    total-opened: (var-get total-positions-opened),
    total-closed: (var-get total-positions-closed),
    active: (- (var-get total-positions-opened) (var-get total-positions-closed)),
  })
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (ok true)
  ))


(define-public (set-oracle-contract (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (ok true)
    (ok true)
  )
)

(define-public (set-protocol-fee-rate (fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (<= fee-rate u1000) (err u2016)) ;; Max 10% fee
    (var-set protocol-fee-rate fee-rate)
    (ok true)
  )
)

(define-public (set-dimensional-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dimensional-token token)
    (ok true)
  )
)

(define-read-only (get-position
    (owner principal)
    (position-id uint)
  )
  (map-get? positions {
    owner: owner,
    id: position-id,
  })
)

;; Get oracle price - requires oracle trait parameter
;; NOTE: Public (not read-only) because match with contract-call requires mutable context
(define-public (get-oracle-price
    (token principal)
    (oracle <oracle-trait>)
  )
  (contract-call? oracle get-price token)
)

(define-public (get-dimensional-state)
  (ok {
    total-positions: (var-get next-position-id),
    active-positions: (unwrap! (count-active-positions) ERR_UNWRAP_FAILED),
    total-value-locked: (unwrap! (calculate-tvl) ERR_UNWRAP_FAILED),
    system-health: "operational"
  }))

(define-public (open-position
    (collateral-amount uint)
    (leverage uint)
    (position-type (string-ascii 20))
    (slippage-tolerance uint)
    (token principal)
    (funding-interval (string-ascii 20))
    (tags (list 10 (string-utf8 32)))
    (metadata (optional (string-utf8 1024)))
    (token-trait <sip-010-ft-trait>)
    (oracle-trait <oracle-trait>)
  )
  (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (size (* collateral-amount leverage))
    (is-long (or (is-eq position-type "LONG") (is-eq position-type "PERPETUAL")))
    (size (* collateral-amount leverage))
    (min-amount-out (/ (* price (- u10000 slippage-tolerance)) u10000))
  )
    ;; Input validation
    (asserts! (> collateral-amount MIN_COLLATERAL) (err ERR_INVALID_AMOUNT))
    (asserts! (and (>= leverage u1) (<= leverage MAX_LEVERAGE)) ERR_INVALID_LEVERAGE)
    (asserts! (or 
      (is-eq position-type "LONG") 
      (is-eq position-type "SHORT")
      (is-eq position-type "PERPETUAL")
    ) ERR_INVALID_POSITION_TYPE)
        collateral-amount
    
    ;; Transfer collateral from user
        none
    
    ;; Create position
    (map-set positions 
      {owner: tx-sender, id: position-id}
      {
        collateral: collateral-amount,
        size: (if is-long size (* size -1)),
        entry-price: price,
        entry-time: current-block,
        last-funding: current-block,
        last-updated: current-block,
        position-type: position-type,
        status: "ACTIVE",
        funding-interval: funding-interval,
        max-leverage: leverage,
        maintenance-margin: u500,  ;; 5% maintenance margin
        time-decay: none,
        volatility: none,
        is-hedged: false,
        tags: tags,
        version: (var-get positions-version),
        metadata: metadata
      }
    )
    
    ;; Update position tracking
    (var-set next-position-id (+ position-id u1))
    (var-set total-positions-opened (+ (var-get total-positions-opened) u1))
    (var-set total-value-locked (+ (var-get total-value-locked) collateral-amount))
    
    (ok position-id)
  )
)

(define-public (close-position
    (position-id uint)
    (slippage-tolerance uint)
    (token-trait <sip-010-ft-trait>)(oracle <oracle-trait>)
  )
  (let (
    (position (unwrap! (get-position tx-sender position-id) (err ERR_INVALID_POSITION)))
    (current-price (try! (get-oracle-price (var-get dimensional-token) oracle)))
    (pnl (calculate-pnl position current-price))
    (fees (calculate-fees position))
    (total-amount (- pnl fees))
    (min-amount-out (/ (* total-amount (- u10000 slippage-tolerance)) u10000))
  )
    (asserts! (is-eq (get status position) "ACTIVE") ERR_POSITION_NOT_ACTIVE)
    
    ;; Update position status
    (map-set positions 
      {owner: tx-sender, id: position-id}
      (merge position {
        status: "CLOSED",
        last-updated: block-height
      })
    )
    
    ;; Transfer funds to user
    (asserts! (is-eq (contract-of token-trait) (var-get dimensional-token))
      ERR_UNAUTHORIZED
    )
(try! (as-contract (contract-call? token-trait transfer total-amount tx-sender tx-sender none)))
    
    ;; Update TVL and position counts
    (var-set total-value-locked (- (var-get total-value-locked) (get collateral position)))
    (var-set total-positions-closed (+ (var-get total-positions-closed) u1))
    
    (ok true)
  )
)

(define-private (calculate-pnl (position {collateral: uint, size: int, entry-price: uint}) (current-price uint))
  (let (
    (size (get size position))
    (is-long (> size 0))
    (size-abs (if (>= size 0)
      (to-uint size)
      (to-uint (* size -1))
    ))
    (price-diff (if is-long 
      (- (get entry-price position) current-price)
        (- current-price (get entry-price position))
        u0)
      (if (>= (get entry-price position) current-price)
        (- (get entry-price position) current-price)
        u0)
    ))
    (pnl-amount (/ (* size-abs price-diff) (get entry-price position)))
  )
    (if is-long 
      (+ (get collateral position) pnl-amount)
      (if (>= (get collateral position) pnl-amount)
        (- (get collateral position) pnl-amount)
        u0
      )
    )
  )
)

(define-private (calculate-fees (position {collateral: uint, size: int, entry-time: uint}))
  (let (
    (position-duration (- block-height (get entry-time position)))
    (fee-rate (var-get protocol-fee-rate))
    (size-abs (abs (get size position)))
  )
    (/ (* size-abs fee-rate position-duration) u10000)
  )
)

(define-private (calculate-liquidation-price (position {entry-price: uint, leverage: uint, is-long: bool}))
  "@dev Calculates the liquidation price for a given position"
  (let (
    (entry-price (get position entry-price))
    (leverage (get position leverage))
    (is-long (get position is-long))
    (m-margin (get position maintenance-margin))
  )
    (if is-long
      ;; Long position: liq_price = entry_price * (1 - 1/leverage + maintenance_margin)
      (* entry-price
        (/
          (+
            (- (* leverage u10000) u10000)
            m-margin
          )
          (* leverage u10000)
        )
      )
      ;; Short position: liq_price = entry_price * (1 + 1/leverage - maintenance_margin)
      (* entry-price
        (/
          (-
            (+ (* leverage u10000) u10000)
            m-margin
          )
          (* leverage u10000)
        )
      )
    )
  )
)

(define-public (liquidate-position (owner principal) (position-id uint) (oracle-trait <oracle-trait>))
  "@dev Liquidate an undercollateralized position"
  (let (
    (position (unwrap! (get-position owner position-id) (err ERR_INVALID_POSITION)))
    (pnl (calculate-pnl position current-price))
    (collateral-value (get collateral position))
    (maintenance-margin (/ (* collateral-value (get maintenance-margin position)) u10000))
    (pnl (calculate-pnl position current-price))
  )
    (asserts! (is-eq (get status position) "ACTIVE") ERR_POSITION_NOT_ACTIVE)
    (asserts! (< pnl maintenance-margin) (err ERR_INSUFFICIENT_COLLATERAL))

    ;; Update position status to liquidated
    (map-set positions
      {owner: owner, id: position-id}
      (merge position {
        status: "LIQUIDATED",
        last-updated: block-height
      })
    )

    ;; Update TVL and position counts
    (var-set total-value-locked (- (var-get total-value-locked) collateral-value))
    (var-set total-positions-closed (+ (var-get total-positions-closed) u1))

    (ok true)
  )
)

(define-read-only (get-health-factor (owner principal) (position-id uint) (oracle-trait <oracle-trait>))
  "@dev Returns the health factor of a position (0-10000, where < 10000 means liquidatable)"
  (let (
    (position (unwrap! (get-position owner position-id) (err ERR_INVALID_POSITION)))
    (current-price (try! (get-oracle-price (var-get dimensional-token) oracle-trait)))
    (collateral-value (get collateral position))
    (pnl (calculate-pnl position current-price))
    (maintenance-margin (/ (* collateral-value (get maintenance-margin position)) u10000))
  )
    (if (is-eq (get status position) "ACTIVE")
      (ok (/ (* pnl u100) maintenance-margin))
      (ok u0)
    )
  )
)

(define-read-only (calculate-tvl)
  (ok (var-get total-value-locked)))

(define-read-only (count-active-positions)
  (ok (- (var-get total-positions-opened) (var-get total-positions-closed))))

;; ===== Circuit Breaker Implementation =====
(define-read-only (circuit-breaker-status)
  "@dev Returns the circuit breaker status"
  (ok {
    is-open: false,
    reason: "",
    last-updated: block-height
  }))

;; ===== Pausable Implementation =====
(define-data-var pausable-contract principal tx-sender)

(define-public (check-not-paused (pausable <pausable-trait>))
  "@dev Check if the contract is not paused"
  (begin
    (asserts! (is-eq (contract-of pausable) (var-get pausable-contract)) (err u3001))
    (match (contract-call? pausable is-paused)
      is-paused? (if is-paused? (err u3001) (ok true))
      (err u3002)
    )
  )
)

;; ===== Initialization =====
(define-public (initialize (new-owner principal) (oracle principal))
  "@dev Initialize the contract (can only be called once)"
  (begin
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_UNAUTHORIZED)
    
    (var-set owner new-owner)
    (ok true)
    (var-set protocol-fee-rate u30)  ;; 0.3%
    
    (ok true)
  )
)
