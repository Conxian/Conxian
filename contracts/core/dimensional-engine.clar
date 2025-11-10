;; dimensional-engine.clar
;; Core contract for the dimensional engine

(use-trait dimensional-trait .all-traits.dimensional-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait risk-trait .all-traits.risk-trait)
(use-trait token-trait .all-traits.sip-010-ft-trait)
(use-trait finance-metrics-trait .all-traits.finance-metrics-trait)

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

(define-map internal-balances principal uint)

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
      (position (unwrap! (contract-call? .dimensional-core get-position position-owner position-id) (err u5005)))
      (current-time block-height)
      (asset (get-position-asset position-id))
      (last-update (unwrap! (map-get? last-funding-update {asset: asset}) (err u5006)))
      (position-type (get status position))
    )
      ;; Only perpetuals have funding
      (asserts! (is-eq position-type "PERPETUAL") (err u5007))

      ;; Calculate funding payment
      (let* (
        (size (abs (get size position)))
        (funding-rate (get cumulative-funding last-update))
        (funding-payment (/ (* size funding-rate) u10000))  ;; Funding rate is in basis points

        ;; Adjust position collateral
        (new-collateral (- (get collateral position) funding-payment))
      )
        ;; Update position collateral
        (try! (contract-call? .dimensional-core update-position
          position-owner
          position-id
          {collateral: (some new-collateral), leverage: none, status: none}
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

(define-private (get-position-asset (position-id uint))
  ;; Helper function to get the asset for a position
  ;; In a real implementation, this would look up the asset in the position data
  ;; For now, we'll use a placeholder
  .stx
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

(define-private (abs (n int))
  (if (< n 0) (- 0 n) n)
)

(define-private (get-open-interest (asset principal))
  ;; In a real implementation, this would query position data
  {
    long: u1000000,
    short: u800000
  }
)

;; =============================================================================
;; INTERNAL LEDGER
;; =============================================================================

(define-public (deposit-funds (amount uint) (token <sip-010-ft-trait>))
  (begin
    (let ((user tx-sender))
      ;; Transfer the tokens from the user to this contract
      (try! (contract-call? token transfer amount user (as-contract tx-sender) none))

      ;; Update the user's internal balance
      (let ((current-balance (default-to u0 (map-get? internal-balances user))))
        (map-set internal-balances user (+ current-balance amount))
        (ok true)
      )
    )
  )
)

(define-public (withdraw-funds (amount uint) (token <sip-010-ft-trait>))
  (begin
    (let ((user tx-sender))
      (let ((current-balance (default-to u0 (map-get? internal-balances user))))
        ;; Check for sufficient balance
        (asserts! (>= current-balance amount) (err ERR-INSUFFICIENT-COLLATERAL))

        ;; Transfer the tokens from this contract to the user
        (try! (as-contract (contract-call? token transfer amount tx-sender user none)))

        ;; Update the user's internal balance
        (map-set internal-balances user (- current-balance amount))
        (ok true)
      )
    )
  )
)

;; =============================================================================
;; FACADE FUNCTIONS
;; =============================================================================

(define-public (create-position (collateral-amount uint) (leverage uint) (pos-type (string-ascii 20)) (token <token-trait>) (slippage-tolerance uint) (funding-int (string-ascii 20)))
  (contract-call? .dimensional-core open-position collateral-amount leverage pos-type slippage-tolerance (contract-of token) funding-int u1)
)

(define-public (close-position (position-id uint) (slippage-tolerance uint))
  (let (
    (price (unwrap! (contract-call? .oracle-adapter get-price (get-position-asset position-id)) (err u4001)))
    (min-amount-out (/ (* price (- u10000 slippage-tolerance)) u10000))
  )
    (contract-call? .dimensional-core close-position position-id min-amount-out)
  )
)

(define-public (liquidate-position (position-owner principal) (position-id uint) (max-slippage uint))
  (contract-call? .risk-liquidation-engine liquidate-position position-owner position-id max-slippage)
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-position (position-owner principal) (position-id uint))
  (contract-call? .dimensional-core get-position position-owner position-id)
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
