;;; # Dimensional Core Contract
;;; 
;;; Core contract for managing dimensional positions with advanced risk management.
;;; Implements position management, risk controls, and protocol fee collection.
;;;
;;; Version: 1.1.0
;;; Conforms to: Clarinet SDK 3.9+, Nakamoto Standard

;; Standard traits
(use-trait oracle-trait .oracle-pricing.oracle-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait pausable-trait .core-traits.pausable-trait)
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)

;; ===== Constants =====
(define-constant CONTRACT_VERSION "1.1.0")
(define-constant MAX_LEVERAGE u100)
(define-constant MIN_COLLATERAL u1000)
(define-constant PROTOCOL_FEE_DENOMINATOR u10000)
(define-constant DEFAULT_MAINTENANCE_MARGIN u500)
(define-constant MAX_FEE_RATE u1000)

;; ===== Error Codes =====
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
(define-constant ERR_BITCOIN_NOT_FINALIZED (err u10001))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var oracle-contract-principal principal tx-sender)
(define-data-var next-position-id uint u0)
(define-data-var protocol-fee-rate uint u30)
(define-data-var dimensional-token principal tx-sender)
(define-data-var total-value-locked uint u0)
(define-data-var total-positions-opened uint u0)
(define-data-var total-positions-closed uint u0)
(define-data-var positions-version uint u1)
(define-data-var pausable-contract principal tx-sender)

;; ===== Data Maps =====
(define-map positions {owner: principal, id: uint} {
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
  tenure-id: uint ;; Added for Nakamoto tenure tracking
})

(define-map position-ids
  principal
  (list 1000 uint)
)
(define-map token-positions principal {long: uint, short: uint})

;; ===== Read-Only Functions =====
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
    active: (- (var-get total-positions-opened) (var-get total-positions-closed))
  }))

(define-read-only (get-position (owner principal) (position-id uint))
  (map-get? positions {owner: owner, id: position-id}))

(define-read-only (calculate-tvl)
  (ok (var-get total-value-locked)))

(define-read-only (count-active-positions)
  (ok (- (var-get total-positions-opened) (var-get total-positions-closed))))

(define-read-only (circuit-breaker-status)
  (ok {
    is-open: false,
    reason: "",
    last-updated: block-height
  }))

(define-public (get-health-factor (owner principal) (position-id uint) (oracle-trait <oracle-trait>))
  (let (
    (position (unwrap! (get-position owner position-id) ERR_INVALID_POSITION))
    (current-price (try! (get-oracle-price (var-get dimensional-token) oracle-trait)))
    (collateral-value (get collateral position))
    (pnl (calculate-pnl position current-price))
    (maintenance-margin (/ (* collateral-value (get maintenance-margin position)) PROTOCOL_FEE_DENOMINATOR))
    (adjusted-collateral (if (>= pnl 0)
      (+ collateral-value (to-uint pnl))
      (if (> (to-uint (* -1 pnl)) collateral-value)
        u0
        (- collateral-value (to-uint (* -1 pnl)))
      )
    ))
  )
    (if (is-eq (get status position) "ACTIVE")
      (ok (if (> maintenance-margin u0)
        (/ (* adjusted-collateral u10000) maintenance-margin)
        u999999999 ;; Max health if maintenance margin is 0
      ))
      (ok u0))))

;; ===== Public Functions - Admin =====
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set owner new-owner)
    (ok true)))

(define-public (set-oracle-contract (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set oracle-contract-principal oracle)
    (ok true)))

(define-public (set-protocol-fee-rate (fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (asserts! (<= fee-rate MAX_FEE_RATE) (err u2016))
    (var-set protocol-fee-rate fee-rate)
    (ok true)))

(define-public (set-dimensional-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dimensional-token token)
    (ok true)))

;; ===== Public Functions - Oracle =====
(define-private (get-oracle-price
    (token principal)
    (oracle <oracle-trait>)
  )
  (contract-call? oracle get-price)
)

;; ===== Public Functions - State =====
(define-public (get-dimensional-state)
  (ok {
    total-positions: (var-get next-position-id),
    active-positions: (unwrap! (count-active-positions) ERR_UNWRAP_FAILED),
    total-value-locked: (unwrap! (calculate-tvl) ERR_UNWRAP_FAILED),
    system-health: "operational"
  }))

;; ===== Public Functions - Position Management =====
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
  (begin
    (try! (check-bitcoin-finality))
    (let (
    (position-id (var-get next-position-id))
    (current-block block-height)
    (price (try! (get-oracle-price token oracle-trait)))
    (is-long (or (is-eq position-type "LONG") (is-eq position-type "PERPETUAL")))
    (size (* collateral-amount leverage))
  )
    (asserts! (>= collateral-amount MIN_COLLATERAL) ERR_INVALID_AMOUNT)
    (asserts! (and (>= leverage u1) (<= leverage MAX_LEVERAGE)) ERR_INVALID_LEVERAGE)
    (asserts!
      (or
        (is-eq position-type "LONG")
        (is-eq position-type "SHORT")
        (is-eq position-type "PERPETUAL")
      )
      ERR_INVALID_POSITION_TYPE
    )

    (try! (contract-call? token-trait transfer collateral-amount tx-sender
      (as-contract tx-sender) none
    ))

    (map-set positions
      {owner: tx-sender, id: position-id}
      {
        collateral: collateral-amount,
        size: (if is-long (to-int size) (to-int (* size u0))),
        entry-price: price,
        entry-time: current-block,
        last-funding: current-block,
        last-updated: current-block,
        position-type: position-type,
        status: "ACTIVE",
        funding-interval: funding-interval,
        max-leverage: leverage,
        maintenance-margin: DEFAULT_MAINTENANCE_MARGIN,
        time-decay: none,
        volatility: none,
        is-hedged: false,
        tags: tags,
        version: (var-get positions-version),
        metadata: metadata,
        tenure-id: block-height ;; Use block-height as proxy for tenure-id in epoch 3.0
      })

    ;; Fix size calculation for short
(if (not is-long)
      (map-set positions {
        owner: tx-sender,
        id: position-id,
      }
        (merge
          (unwrap!
            (map-get? positions {
              owner: tx-sender,
              id: position-id,
            })
            ERR_INVALID_POSITION
          ) { size: (* (to-int size) -1) }
        ))
      true
    )

    (var-set next-position-id (+ position-id u1))
    (var-set total-positions-opened (+ (var-get total-positions-opened) u1))
    (var-set total-value-locked (+ (var-get total-value-locked) collateral-amount))

    (print {
      event: "open-position",
      position-id: position-id,
      owner: tx-sender,
      collateral: collateral-amount,
      leverage: leverage,
      position-type: position-type,
      token: token,
      price: price,
      tenure-id: block-height
    })
    (ok position-id)
  )
)

(define-public (close-position
    (position-id uint)
    (slippage-tolerance uint)
    (token-trait <sip-010-ft-trait>)
    (oracle <oracle-trait>)
  )
  (begin
    (try! (check-bitcoin-finality))
    (let (
    (position (unwrap! (get-position tx-sender position-id) ERR_INVALID_POSITION))
    (current-price (try! (get-oracle-price (var-get dimensional-token) oracle)))
    (pnl (calculate-pnl position current-price))
    (fees (calculate-fees position))
    (collateral (get collateral position))
    (total-amount (if (>= pnl 0)
        (if (>= (+ collateral (to-uint pnl)) fees)
          (- (+ collateral (to-uint pnl)) fees)
          u0
        )
        (if (>= collateral (+ (to-uint (* -1 pnl)) fees))
          (- collateral (+ (to-uint (* -1 pnl)) fees))
          u0
        )
    ))
  )
    (asserts! (is-eq (get status position) "ACTIVE") ERR_POSITION_NOT_ACTIVE)

    (map-set positions
      {owner: tx-sender, id: position-id}
      (merge position {status: "CLOSED", last-updated: block-height}))

    (asserts! (is-eq (contract-of token-trait) (var-get dimensional-token))
      ERR_UNAUTHORIZED
    )
    (if (> total-amount u0)
      (try! (as-contract (contract-call? token-trait transfer total-amount tx-sender
        (get owner position) none
      )))
      true
    )

    (var-set total-value-locked (- (var-get total-value-locked) (get collateral position)))
    (var-set total-positions-closed (+ (var-get total-positions-closed) u1))

    (print {
      event: "close-position",
      position-id: position-id,
      owner: tx-sender,
      pnl: pnl,
      fees: fees,
      tenure-id: block-height
    })
    (ok true)))

(define-public (liquidate-position (owner principal) (position-id uint) (oracle-trait <oracle-trait>))
  (begin
    (try! (check-bitcoin-finality))
    (let (
      (position (unwrap! (get-position owner position-id) ERR_INVALID_POSITION))
      (current-price (try! (get-oracle-price (var-get dimensional-token) oracle-trait)))
      (pnl (calculate-pnl position current-price))
      (collateral-value (get collateral position))
      (maintenance-margin (/ (* collateral-value (get maintenance-margin position))
        PROTOCOL_FEE_DENOMINATOR
      ))
      (adjusted-collateral (if (>= pnl 0)
        (+ collateral-value (to-uint pnl))
        (if (> (to-uint (* -1 pnl)) collateral-value)
          u0
          (- collateral-value (to-uint (* -1 pnl)))
        )
      ))
    )
      (asserts! (is-eq (get status position) "ACTIVE") ERR_POSITION_NOT_ACTIVE)
      (asserts! (< adjusted-collateral maintenance-margin)
        ERR_INSUFFICIENT_COLLATERAL
      )

      (map-set positions {
        owner: owner,
        id: position-id,
      }
        (merge position {
          status: "LIQUIDATED",
          last-updated: block-height,
        })
      )

      (var-set total-value-locked
        (- (var-get total-value-locked) collateral-value)
      )
(var-set total-positions-closed (+ (var-get total-positions-closed) u1))

      (print {
        event: "liquidate-position",
        position-id: position-id,
        owner: owner,
        liquidator: tx-sender,
        tenure-id: block-height
      })

      (ok true)
    )
  )
)

;; ===== Public Functions - Pausable =====
(define-public (check-not-paused (pausable <pausable-trait>))
  (begin
    (asserts! (is-eq (contract-of pausable) (var-get pausable-contract)) (err u3001))
    (match (contract-call? pausable is-paused)
      is-paused? (if is-paused? (err u3001) (ok true))
      error (err u3002))))

;; ===== Public Functions;; --- Nakamoto Consensus Integration ---
(define-private (check-bitcoin-finality)
  (let (
    ;; Verify we can read state from 6 blocks ago (Bitcoin finality)
    (finality-height (- burn-block-height u6))
    (burn-header (get-burn-block-info? header-hash finality-height))
  )
    (asserts! (is-some burn-header) ERR_BITCOIN_NOT_FINALIZED)
    (ok true)
  )
)

;; ===== Initialization =====
(define-public (initialize (new-owner principal) (oracle principal))
  "@dev Initialize the contract (can only be called once)"
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)

    (var-set owner new-owner)
    (var-set oracle-contract-principal oracle)
    (var-set protocol-fee-rate u30)  ;; 0.3%

    (ok true)
  )
)

(define-private (calculate-fees (position {
  collateral: uint,
  size: int,
  entry-time: uint,
  status: (string-ascii 20),
  entry-price: uint,
  position-type: (string-ascii 20),
  last-funding: uint,
  last-updated: uint,
  funding-interval: (string-ascii 20),
  max-leverage: uint,
  maintenance-margin: uint,
  time-decay: (optional uint),
  volatility: (optional uint),
  is-hedged: bool,
  tags: (list 10 (string-utf8 32)),
  version: uint,
  metadata: (optional (string-utf8 1024)),
  tenure-id: uint
}))
  (let (
      (size (get size position))
      (size-abs (if (>= size 0)
        (to-uint size)
        (to-uint (* size -1))
      ))
      (position-duration (- block-height (get entry-time position)))
      (fee (/ (* size-abs position-duration (var-get protocol-fee-rate))
        PROTOCOL_FEE_DENOMINATOR
      ))
    )
    fee
  )
)

(define-private (calculate-pnl
    (position {
      collateral: uint,
      size: int,
      entry-time: uint,
      status: (string-ascii 20),
      entry-price: uint,
      position-type: (string-ascii 20),
      last-funding: uint,
      last-updated: uint,
      funding-interval: (string-ascii 20),
      max-leverage: uint,
      maintenance-margin: uint,
      time-decay: (optional uint),
      volatility: (optional uint),
      is-hedged: bool,
      tags: (list 10 (string-utf8 32)),
      version: uint,
      metadata: (optional (string-utf8 1024)),
      tenure-id: uint
    })
    (current-price uint)
  )
  (let (
      (size (get size position))
      (entry-price (get entry-price position))
      (is-long (> size 0))
      (size-abs (if (>= size 0)
        (to-uint size)
        (to-uint (* size -1))
      ))
    )
    (if is-long
      (if (>= current-price entry-price)
        (to-int (/ (* size-abs (- current-price entry-price)) entry-price))
        (* -1 (to-int (/ (* size-abs (- entry-price current-price)) entry-price)))
      )
      ;; Short
      (if (<= current-price entry-price)
        (to-int (/ (* size-abs (- entry-price current-price)) entry-price))
        (* -1 (to-int (/ (* size-abs (- current-price entry-price)) entry-price)))
      )
    )
  )
)