;; ============================================================
;; DIMENSIONAL ENGINE (v3.9.0+)
;; ============================================================
;; Core contract for the dimensional engine

(use-trait oracle-trait .oracle-aggregator-v2-trait.oracle-aggregator-v2-trait)
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait risk-trait .risk-trait.risk-trait)
(use-trait finance-metrics-trait .finance-metrics-trait.finance-metrics-trait)
(use-trait math-utils .math-trait.math-trait)

;; CONSTANTS
;; CONSTANTS
;; =============================================================================

;; Import constants from math-utils
(use-constants 
  PRECISION 
  PERCENTAGE_PRECISION 
  MATH_OVERFLOW 
  DIVISION_BY_ZERO 
  REENTRANCY_GUARD
  from_contract .math-utils)

;; Protocol-specific constants
(define-constant MIN_LEVERAGE u100)
(define-constant DEFAULT_MAX_LEVERAGE u2000) ;; 20x
(define-constant DEFAULT_MAINTENANCE_MARGIN u500) ;; 5%
(define-constant DEFAULT_PROTOCOL_FEE u30) ;; 0.3%
(define-constant SLIPPAGE_PRECISION u10000)
(define-constant LEVERAGE_PRECISION u100)
(define-constant FUNDING_INTERVAL u144) ;; Default to daily funding
(define-constant MAX_FUNDING_RATE u100) ;; 1% max funding rate
(define-constant FUNDING_RATE_SENSITIVITY u500) ;; 5% sensitivity
(define-constant LIQUIDATION_THRESHOLD u8000) ;; 80%
(define-constant MAX_POSITION_SIZE u1000000000000) ;; 1M with 6 decimals
(define-constant MIN_LIQUIDATION_REWARD u100) ;; 0.1%
(define-constant MAX_LIQUIDATION_REWARD u1000)  ;; 1%

;; =============================================================================
;; DATA VARIABLES
;; =============================================================================

;; Position management
(define-data-var next-position-id uint u0)
(define-data-var protocol-fee-rate uint DEFAULT_PROTOCOL_FEE)
(define-data-var total-positions-opened uint u0)
(define-data-var total-volume uint u0)

;; Risk parameters
(define-data-var max-leverage uint DEFAULT_MAX_LEVERAGE)
(define-data-var maintenance-margin uint DEFAULT_MAINTENANCE_MARGIN)
(define-data-var liquidation-threshold uint LIQUIDATION_THRESHOLD)
(define-data-var max-position-size uint MAX_POSITION_SIZE)
(define-data-var min-liquidation-reward uint MIN_LIQUIDATION_REWARD)
(define-data-var max-liquidation-reward uint MAX_LIQUIDATION_REWARD)
(define-data-var insurance-fund principal tx-sender)

;; Funding parameters
(define-data-var funding-interval uint FUNDING_INTERVAL)
(define-data-var max-funding-rate uint MAX_FUNDING_RATE)
(define-data-var funding-rate-sensitivity uint FUNDING_RATE_SENSITIVITY)

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

;; Position data structure
(define-map positions {
  id: uint
} {
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

;; Track user positions by asset
(define-map user-positions {
  user: principal,
  asset: principal,
  position-id: uint
} bool)

;; Track active positions by asset and direction
(define-map active-positions {
  asset: principal,
  is-long: bool,
  position-id: uint
} bool)


(define-public (update-funding-rate (asset principal))
  (begin
    (try! (check-role ROLE_OPERATOR))
    (try! (when-not-paused))
    
    (let (
      (current-time block-height)
      (last-update (default-to
        {timestamp: u0, cumulative-funding: 0}
        (map-get? last-funding-update {asset: asset})
      ))
    )
      ;; Check if enough time has passed since last update
      (try! (require! 
        (>= (- current-time (get last-update timestamp)) (var-get funding-interval))
        (err u1001)
      ))

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
    (try! (when-not-paused))
    (try! (with-reentrancy-guard (lambda () (ok true))))
    (try! (validate-positive-amount amount))
    (try! (validate-positive-amount amount))
    
    (let ((user tx-sender))
      ;; Transfer the tokens from the user to this contract
      (try! (contract-call? token transfer amount user (as-contract tx-sender) none))
      
      ;; Update internal balance
      (let ((current-balance (default-to u0 (map-get? internal-balances user))))
        (map-set internal-balances user (+ current-balance amount))
      )
      
      (ok true)
    )
  )
)

(define-public (withdraw-funds (amount uint) (token <sip-010-ft-trait>))
  (begin
    (try! (when-not-paused))
    (try! (validate-positive-amount amount))
    
    (let ((user tx-sender)
          (current-balance (default-to u0 (map-get? internal-balances user))))
      
      ;; Check sufficient balance
      (try! (require! 
        (>= current-balance amount)
        (err u2001)
      ))
      
      ;; Update internal balance before transfer to prevent reentrancy
      (map-set internal-balances user (- current-balance amount))
      
      ;; Transfer tokens back to user
      (try! (as-contract (contract-call? token transfer amount tx-sender user none)))
      
      (ok true)
    )
  )
)

      ;; Update the user's internal balance
      (let ((current-balance (default-to u0 (map-get? internal-balances user))))
        (map-set internal-balances user (+ current-balance amount))
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
    (try! (transfer-ownership new-owner))
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (try! (if paused (pause) (unpause)))
    (ok true)
  )
)

(define-public (set-protocol-fee-rate (new-rate uint))
  (begin
    (try! (check-role ROLE_ADMIN))
    (try! (require! 
      (and (>= new-rate u0) (<= new-rate u1000)) ;; 0-10% max fee
      (err u1001)
    ))
    
    (var-set protocol-fee-rate new-rate)
    (ok true)
  )
)

(define-public (set-risk-parameters 
    (new-max-leverage uint)
    (new-maintenance-margin uint)
    (new-liquidation-threshold uint)
  )
  (begin
    (try! (check-role ROLE_ADMIN))
    (try! (require! 
      (and
        (>= new-max-leverage MIN_LEVERAGE)
        (<= new-max-leverage u5000) ;; 50x max leverage
        (> new-maintenance-margin u0)
        (< new-maintenance-margin u10000) ;; 100% max
        (> new-liquidation-threshold new-maintenance-margin)
        (<= new-liquidation-threshold u10000) ;; 100% max
      )
      (err u1001)
    ))
    
    (var-set max-leverage new-max-leverage)
    (var-set maintenance-margin new-maintenance-margin)
    (var-set liquidation-threshold new-liquidation-threshold)
    
    (ok true)
  )
)

(define-public (set-funding-parameters 
    (new-funding-interval uint)
    (new-max-funding-rate uint)
    (new-sensitivity uint)
  )
  (begin
    (try! (check-role ROLE_ADMIN))
    (try! (require! 
      (and
        (> new-funding-interval u0)
        (> new-max-funding-rate u0)
        (> new-sensitivity u0)
      )
      (err u1001)
    ))
    
    (var-set funding-interval new-funding-interval)
    (var-set max-funding-rate new-max-funding-rate)
    (var-set funding-rate-sensitivity new-sensitivity)
    
    (ok true)
  )
)

(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (begin
    (try! (check-role ROLE_ADMIN))
    (try! (require! 
      (and
        (> min-reward u0)
        (<= min-reward max-reward)
        (<= max-reward u5000) ;; 50% max reward
      )
      (err u1001)
    ))
    
    (var-set min-liquidation-reward min-reward)
    (var-set max-liquidation-reward max-reward)
    
    (ok true)
  )
)

(define-public (set-insurance-fund (fund principal))
  (begin
    (try! (check-role ROLE_ADMIN))
    (try! (validate-address fund))
    
    (var-set insurance-fund fund)
    (ok true)
  )
)

;; =============================================================================
;; POSITION MANAGEMENT
;; =============================================================================

(define-public (open-position 
    (asset principal)
    (collateral uint)
    (leverage uint)
    (is-long bool)
    (stop-loss (optional uint))
    (take-profit (optional uint))
  )
  (let (
    (position-id (var-get next-position-id))
    (current-time block-height)
  )
    (try! (when-not-paused))
    (try! (validate-positive-amount collateral))
    (try! (validate-positive-amount leverage))
    
    ;; Validate leverage
    (try! (require! 
      (and 
        (>= leverage MIN_LEVERAGE) 
        (<= leverage (var-get max-leverage))
      )
      (err u1001)
    ))
    
    ;; Calculate position size and fees
    (let (
      (position-size (* collateral leverage))
      (fee (/ (* position-size (var-get protocol-fee-rate)) u10000))
      (total-cost (+ collateral fee))
    )
      ;; Check if user has sufficient balance
      (try! (require! 
        (>= (default-to u0 (map-get? internal-balances tx-sender)) total-cost)
        (err u2001)
      ))
      
      ;; Get current price from oracle (simplified - would use actual oracle in production)
      (let ((price (try! (get-price asset))))
        ;; Create new position
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
        
        ;; Update user's position tracking
        (map-set user-positions {
          user: tx-sender,
          asset: asset,
          position-id: position-id
        } true)
        
        ;; Update active positions
        (map-set active-positions {
          asset: asset,
          is-long: is-long,
          position-id: position-id
        } true)
        
        ;; Update state variables
        (var-set next-position-id (+ position-id u1))
        (var-set total-positions-opened (+ (var-get total-positions-opened) u1))
        (var-set total-volume (+ (var-get total-volume) position-size))
        
        ;; Deduct collateral and fees from user's internal balance
        (let ((current-balance (default-to u0 (map-get? internal-balances tx-sender))))
          (map-set internal-balances tx-sender (- current-balance total-cost))
        )
        
        ;; Emit event
        (emit-position-opened position-id tx-sender asset collateral position-size 
          leverage is-long price)
        
        (ok position-id)
      )
    )
  )
)

(define-public (close-position (position-id uint) (slippage (optional uint)))
  (let (
    (position (try! (get-position position-id)))
    (current-time block-height)
  )
    (try! (when-not-paused))
    
    ;; Check position exists and is active
    (try! (require! 
      (get position is-active)
      (err u1001)
    ))
    
    ;; Check caller is position owner or has permission
    (try! (require! 
      (or 
        (is-eq tx-sender (get position 'owner))
        (is-ok (contract-call? .rbac-contract has-role ROLE_LIQUIDATOR tx-sender))
      )
      (err u1000)
    ))
    
    ;; Get current price and calculate P&L
    (let* (
      (price (try! (get-price (get position 'asset))))
      (entry-price (get position 'entry-price))
      (size (get position 'size))
      (collateral (get position collateral))
      (is-long (get position is-long))
      
      ;; Simplified P&L calculation (would include funding in production)
      (price-diff (if is-long 
        (- price entry-price)
        (- entry-price price)
      ))
      (pnl (/ (* size price-diff) entry-price))
      (total-returned (+ collateral pnl))
      
      ;; Apply slippage check if provided
      (min-returned (if (is-none slippage) 
        u0 
        (/ (* total-returned (- u10000 (unwrap-panic slippage))) u10000)
      ))
    )
      ;; Check if position is liquidatable (simplified)
      (when (< total-returned (* collateral (var-get liquidation-threshold)) u10000)
        (try! (require! 
          (is-eq tx-sender (get position owner))
          (err u1001)
        ))
      )
      
      ;; Mark position as closed
      (map-set positions {id: position-id} (merge (unwrap-panic position) {
        is-active: false,
        last-updated: current-time
      }))
      
      ;; Remove from active positions
      (map-delete active-positions {
        asset: (get position asset),
        is-long: is-long,
        position-id: position-id
      })
      
      ;; Transfer funds back to user (or liquidator)
      (let ((recipient (if (>= pnl u0) 
        (get position owner) 
        (var-get insurance-fund)
      )))
        (map-set internal-balances recipient 
          (+ (default-to u0 (map-get? internal-balances recipient)) total-returned)
        )
      )
      
      ;; Emit event
      (emit-position-closed position-id (get position owner) total-returned pnl price)
      
      (ok {
        collateral-returned: total-returned,
        pnl: pnl
      })
    )
  )
)

;; =============================================================================
;; VIEW FUNCTIONS
;; =============================================================================

(define-read-only (get-position (position-id uint))
  (let ((position (unwrap! (map-get? positions {id: position-id}) 
    (err ERR_POSITION_NOT_FOUND)
  )))
    (ok position)
  )
)

(define-read-only (get-open-interest (asset principal))
  (let (
    (long-positions (filter 
      (lambda ((pos {is-long: bool, position-id: uint, active: bool})) 
        (and (get pos active) (get pos is-long))
      )
      (map (lambda ((key {asset: principal, is-long: bool, position-id: uint}) 
        (let ((pos (unwrap! (map-get? positions {id: (get key position-id)}) false)))
          (if pos {
            is-long: (get key is-long),
            position-id: (get key position-id),
            active: (get pos is-active)
          } false)
        )
      )) (map-keys active-positions))
    ))
    
    (short-positions (filter 
      (lambda ((pos {is-long: bool, position-id: uint, active: bool})) 
        (and (get pos active) (not (get pos is-long)))
      )
      (map (lambda ((key {asset: principal, is-long: bool, position-id: uint}) 
        (let ((pos (unwrap! (map-get? positions {id: (get key position-id)}) false)))
          (if pos {
            is-long: (get key is-long),
            position-id: (get key position-id),
            active: (get pos is-active)
          } false)
        )
      )) (map-keys active-positions))
    ))
    
    (long-oi (fold (lambda (acc {position-id: uint}) 
      (+ acc (get (unwrap! (map-get? positions {id: position-id}) (err ERR_POSITION_NOT_FOUND)) size))
    ) u0 (map (lambda (p) {position-id: (get p position-id)}) long-positions)))
    
    (short-oi (fold (lambda (acc {position-id: uint}) 
      (+ acc (get (unwrap! (map-get? positions {id: position-id}) (err ERR_POSITION_NOT_FOUND)) size))
    ) u0 (map (lambda (p) {position-id: (get p position-id)}) short-positions)))
  )
    (ok {
      long: long-oi,
      short: short-oi
    })
  )
)

(define-read-only (get-protocol-stats)
  (ok {
    total-positions-opened: (var-get total-positions-opened),
    total-volume: (var-get total-volume),
    total-fees-collected: u0,  ;; Would track this in production
    total-value-locked: (fold 
      (lambda (acc {user: principal, balance: uint}) (+ acc balance))
      u0
      (map 
        (lambda ((user principal)) 
          {user: user, balance: (default-to u0 (map-get? internal-balances user))}
        )
        (map get (map-keys internal-balances) (repeat (length (map-keys internal-balances)) user))
      )
    )
  })
)

;; =============================================================================
;; INTERNAL HELPERS
;; =============================================================================

(define-private (get-price (asset principal))
  (ok u1000000)  ;; Simplified - would use oracle in production
)

(define-private (validate-position-params (collateral uint) (leverage uint))
  (try! (validate-positive-amount collateral))
  (try! (validate-positive-amount leverage))
  
  (try! (require! 
    (and 
      (>= leverage MIN_LEVERAGE) 
      (<= leverage (var-get max-leverage))
    )
    (err u1001)
  ))
  
  (ok true)
)

(define-private (calculate-liquidation-price (position {entry-price: uint, leverage: uint, is-long: bool}))
  (let (
    (m-margin (var-get maintenance-margin))
    (entry-price (get position entry-price))
    (leverage (get position leverage))
    (is-long (get position is-long))
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