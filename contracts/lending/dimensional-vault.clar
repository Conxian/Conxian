;; dimensional-vault.clar
;; Unified lending vault with risk-adjusted parameters

(use-trait vault .all-traits.vault-trait)
(use-trait dimensional-core .all-traits.dimensional-core-trait)
(use-trait risk-oracle .all-traits.risk-oracle-trait)
(impl-trait vault)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_INVALID_ASSET (err u9001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u9002))
(define-constant ERR_INVALID_AMOUNT (err u9003))
(define-constant ERR_POSITION_UNHEALTHY (err u9004))
(define-constant ERR_VAULT_PAUSED (err u9005))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var is-paused bool false)
(define-data-var oracle principal)
(define-data-var risk-engine principal)

;; Vault state
(define-map vault-state {
  total-supply: uint,
  total-borrows: uint,
  total-reserves: uint,
  last-updated: uint,
  borrow-index: uint
} {
  total-supply: u0,
  total-borrows: u0,
  total-reserves: u0,
  last-updated: u0,
  borrow-index: u1e18
})

;; User balances
(define-map user-supply {user: principal} uint)
(define-map user-borrows {user: principal} uint)
(define-map user-index {user: principal} uint)

;; Asset configuration
(define-map asset-config {asset: principal} {
  is-listed: bool,
  collateral-factor: uint,
  reserve-factor: uint,
  liquidation-bonus: uint
})

;; ===== Core Functions =====
(define-public (supply (amount uint) (supplier principal))
  (begin
    (asserts! (not (var-get is-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount 0) ERR_INVALID_AMOUNT)
    
    (let (
      (asset (contract-caller))
      (config (unwrap! (map-get? asset-config {asset: asset}) ERR_INVALID_ASSET))
    )
      ;; Accrue interest
      (accrue-interest)
      
      ;; Transfer tokens from user
      (try! (contract-call? asset transfer-from amount supplier (as-contract tx-sender)))
      
      ;; Update state
      (let (
        (current-supply (default-to u0 (map-get? user-supply {user: supplier})))
        (new-supply (+ current-supply amount))
      )
        (map-set user-supply {user: supplier} new-supply)
        (vault-update-supply amount 'add)
      )
      
      (ok true)
    )
  )
)

(define-public (borrow (amount uint) (borrower principal))
  (begin
    (asserts! (not (var-get is-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount 0) ERR_INVALID_AMOUNT)
    
    (let (
      (asset (contract-caller))
      (config (unwrap! (map-get? asset-config {asset: asset}) ERR_INVALID_ASSET))
      (available-liquidity (get-available-liquidity asset))
    )
      (asserts! (>= available-liquidity amount) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Check borrowing power
      (let (
        (borrow-ok (contract-call? risk-oracle check-borrow-power borrower amount))
      )
        (asserts! borrow-ok ERR_POSITION_UNHEALTHY)
      )
      
      ;; Update state
      (let (
        (current-borrow (default-to u0 (map-get? user-borrows {user: borrower})))
        (new-borrow (+ current-borrow amount))
      )
        (map-set user-borrows {user: borrower} new-borrow)
        (vault-update-borrow amount 'add)
      )
      
      ;; Transfer tokens to user
      (try! (contract-call? asset transfer amount borrower))
      
      (ok true)
    )
  )
)

;; ===== Internal Functions =====
(define-private (accrue-interest)
  (let (
    (current-block block-height)
    (state (var-get vault-state))
    (last-updated (get state 'last-updated))
  )
    (when (> current-block last-updated)
      (let (
        (borrow-rate (contract-call? risk-oracle get-borrow-rate (get state 'utilization)))
        (block-delta (- current-block last-updated))
        
        ;; Calculate interest
        (interest-accumulated 
          (/ (* (get state 'total-borrows) borrow-rate block-delta) u10000)
        )
        (new-total-borrows (+ (get state 'total-borrows) interest-accumulated))
        
        ;; Update borrow index
        (borrow-index-increase 
          (if (> (get state 'total-supply) 0)
            (/ (* interest-accumulated u1e18) (get state 'total-supply))
            u0
          )
        )
        (new-borrow-index (+ (get state 'borrow-index) borrow-index-increase))
      )
        ;; Update state
        (var-set vault-state (merge state {
          'total-borrows: new-total-borrows,
          'borrow-index: new-borrow-index,
          'last-updated: current-block
        }))
      )
    )
  )
)

(define-read-only (get-available-liquidity (asset principal))
  (let (
    (balance (contract-call? asset balance-of (as-contract tx-sender)))
    (total-borrows (get (var-get vault-state) 'total-borrows))
  )
    (- balance total-borrows)
  )
)

(define-private (vault-update-supply (amount uint) (op (string-ascii 10)))
  (let (
    (state (var-get vault-state))
    (new-supply 
      (if (is-eq op "add") 
        (+ (get state 'total-supply) amount)
        (- (get state 'total-supply) amount)
      )
    )
  )
    (var-set vault-state (merge state {
      'total-supply: new-supply,
      'last-updated: block-height
    }))
  )
)

(define-private (vault-update-borrow (amount uint) (op (string-ascii 10)))
  (let (
    (state (var-get vault-state))
    (new-borrows 
      (if (is-eq op "add")
        (+ (get state 'total-borrows) amount)
        (- (get state 'total-borrows) amount)
      )
    )
  )
    (var-set vault-state (merge state {
      'total-borrows: new-borrows,
      'last-updated: block-height
    }))
  )
)

;; ===== Admin Functions =====
(define-public (set-oracle (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set oracle new-oracle)
    (ok true)
  )
)

(define-public (set-risk-engine (engine principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set risk-engine engine)
    (ok true)
  )
)

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set is-paused paused)
    (ok true)
  )
)

(define-public (configure-asset 
    (asset principal)
    (config {
      is-listed: bool,
      collateral-factor: uint,
      reserve-factor: uint,
      liquidation-bonus: uint
    })
  )
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (map-set asset-config {asset: asset} config)
    (ok true)
  )
)
