;; dimensional-vault.clar
;; Unified lending vault with risk-adjusted parameters

(use-trait vault-trait .vault-trait)
(use-trait dimensional-trait .dimensional.dimensional-trait)
(use-trait dim-registry-trait .dimensional.dim-registry-trait)
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
(define-data-var dimensional-engine principal tx-sender)
(define-data-var dim-registry principal tx-sender)

;; Vault state
(define-data-var vault-state {
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
  borrow-index: u1000000000000000000
})

;; User balances
(define-map user-supply {user: principal} uint)
(define-map user-borrows {user: principal} uint)
(define-map user-index {user: principal} uint)

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
        (vault-update-supply amount "add")
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
      (config (unwrap! (contract-call? (var-get dim-registry) get-asset-config asset) ERR_INVALID_ASSET))
      (available-liquidity (get-available-liquidity asset))
    )
      (asserts! (>= available-liquidity amount) ERR_INSUFFICIENT_LIQUIDITY)
      
      ;; Check borrowing power
      (let (
        (borrow-ok (contract-call? (var-get dimensional-engine) check-borrow-power borrower amount))
      )
        (asserts! borrow-ok ERR_POSITION_UNHEALTHY)
      )
      
      ;; Update state
      (let (
        (current-borrow (default-to u0 (map-get? user-borrows {user: borrower})))
        (new-borrow (+ current-borrow amount))
      )
        (map-set user-borrows {user: borrower} new-borrow)
        (vault-update-borrow amount "add")
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
    (last-updated (get last-updated state))
  )
    (if (> current-block last-updated)
      (let (
        (utilization (let ((ts (get total-supply state)) (tb (get total-borrows state)))
                       (if (> ts u0) (/ (* tb u10000) ts) u0)))
        (borrow-rate (contract-call? (var-get risk-engine) get-borrow-rate utilization))
        (block-delta (- current-block last-updated))
        
        ;; Calculate interest
        (interest-accumulated 
          (/ (* (get total-borrows state) borrow-rate block-delta) u10000)
        )
        (new-total-borrows (+ (get total-borrows state) interest-accumulated))
        
        ;; Update borrow index
        (borrow-index-increase 
          (if (> (get total-supply state) 0)
            (/ (* interest-accumulated u1000000000000000000) (get total-supply state))
            u0
          )
        )
        (new-borrow-index (+ (get borrow-index state) borrow-index-increase))
      )
        ;; Update state
        (var-set vault-state (merge state {
          total-borrows: new-total-borrows,
          borrow-index: new-borrow-index,
          last-updated: current-block
        }))
      )
      true
    )
  )
)

(define-read-only (get-available-liquidity (asset principal))
  (let (
    (balance (contract-call? asset balance-of (as-contract tx-sender)))
    (total-borrows (get total-borrows (var-get vault-state)))
  )
    (- balance total-borrows)
  )
)

(define-private (vault-update-supply (amount uint) (op (string-ascii 10)))
  (let (
    (state (var-get vault-state))
    (new-supply 
      (if (is-eq op "add") 
        (+ (get total-supply state) amount)
        (- (get total-supply state) amount)
      )
    )
  )
    (var-set vault-state (merge state {
      total-supply: new-supply,
      last-updated: block-height
    }))
  )
)

(define-private (vault-update-borrow (amount uint) (op (string-ascii 10)))
  (let (
    (state (var-get vault-state))
    (new-borrows 
      (if (is-eq op "add")
        (+ (get total-borrows state) amount)
        (- (get total-borrows state) amount)
      )
    )
  )
    (var-set vault-state (merge state {
      total-borrows: new-borrows,
      last-updated: block-height
    }))
  )
)

;; ===== Admin Functions =====
(define-public (set-dimensional-engine (engine principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dimensional-engine engine)
    (ok true)
  )
)

(define-public (set-dim-registry (registry principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dim-registry registry)
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
