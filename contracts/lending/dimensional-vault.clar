;; dimensional-vault.clar (Refactored)
;; This contract acts as a facade for the dimensional vault, delegating logic to specialized contracts.

(use-trait vault-trait .vault-trait)
(use-trait dimensional-trait .dimensional.dimensional-trait)
(use-trait dim-registry-trait .dimensional.dim-registry-trait)
(use-trait interest-rate-model-trait .interest-rate-model.interest-rate-model-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_INVALID_ASSET (err u9001))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u9002))
(define-constant ERR_INVALID_AMOUNT (err u9003))
(define-constant ERR_POSITION_UNHEALTHY (err u9004))
(define-constant ERR_VAULT_PAUSED (err u9005))

;; ===== Data Variables =====

;; @desc The principal of the contract owner.
(define-data-var owner principal tx-sender)
;; @desc A boolean indicating if the vault is paused.
(define-data-var is-paused bool false)
;; @desc The principal of the dimensional engine contract.
(define-data-var dimensional-engine principal tx-sender)
;; @desc The principal of the dimensional registry contract.
(define-data-var dim-registry principal tx-sender)
;; @desc The principal of the interest rate model contract.
(define-data-var interest-rate-model principal .interest-rate-model)

;; @desc Stores the current state of the vault.
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

;; @desc Stores the supply balance for each user.
(define-map user-supply {user: principal} uint)
;; @desc Stores the borrow balance for each user.
(define-map user-borrows {user: principal} uint)
;; @desc Stores the borrow index for each user.
(define-map user-index {user: principal} uint)

;; ===== Core Functions =====

;; @desc Supplies an asset to the vault.
;; @param amount uint The amount to supply.
;; @param supplier principal The user supplying the asset.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (supply (amount uint) (supplier principal))
  (begin
    (asserts! (not (var-get is-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (asset (contract-caller))
      (config (unwrap! (map-get? asset-config {asset: asset}) ERR_INVALID_ASSET))
    )
      (try! (accrue-interest))
      (try! (as-contract (contract-call? asset transfer amount supplier (as-contract tx-sender))))
      
      (let (
        (current-supply (default-to u0 (map-get? user-supply {user: supplier})))
        (new-supply (+ current-supply amount))
      )
        (map-set user-supply {user: supplier} new-supply)
        (try! (vault-update-supply amount "add"))
      )
      
      (ok true)
    )
  )
)

;; @desc Borrows an asset from the vault.
;; @param amount uint The amount to borrow.
;; @param borrower principal The user borrowing the asset.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (borrow (amount uint) (borrower principal))
  (begin
    (asserts! (not (var-get is-paused)) ERR_VAULT_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (asset (contract-caller))
      (config (unwrap! (contract-call? (var-get dim-registry) get-asset-config asset) ERR_INVALID_ASSET))
      (available-liquidity (try! (get-available-liquidity asset)))
    )
      (asserts! (>= available-liquidity amount) ERR_INSUFFICIENT_LIQUIDITY)
      
      (let (
        (borrow-ok (unwrap! (contract-call? (var-get dimensional-engine) check-borrow-power borrower amount) (err ERR_POSITION_UNHEALTHY)))
      )
        (asserts! borrow-ok ERR_POSITION_UNHEALTHY)
      )
      
      (let (
        (current-borrow (default-to u0 (map-get? user-borrows {user: borrower})))
        (new-borrow (+ current-borrow amount))
      )
        (map-set user-borrows {user: borrower} new-borrow)
        (try! (vault-update-borrow amount "add"))
      )
      
      (try! (as-contract (contract-call? asset transfer amount tx-sender borrower)))
      
      (ok true)
    )
  )
)

;; ===== Internal Functions =====

;; @desc Accrues interest on the total borrows.
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
        (borrow-rate (unwrap! (contract-call? (var-get interest-rate-model) get-borrow-rate utilization) (err u0)))
        (block-delta (- current-block last-updated))
        
        (interest-accumulated 
          (/ (* (get total-borrows state) borrow-rate block-delta) u10000)
        )
        (new-total-borrows (+ (get total-borrows state) interest-accumulated))
        
        (borrow-index-increase 
          (if (> (get total-supply state) 0)
            (/ (* interest-accumulated u1000000000000000000) (get total-supply state))
            u0
          )
        )
        (new-borrow-index (+ (get borrow-index state) borrow-index-increase))
      )
        (var-set vault-state (merge state {
          total-borrows: new-total-borrows,
          borrow-index: new-borrow-index,
          last-updated: current-block
        }))
        (ok true)
      )
      (ok true)
    )
  )
)

;; @desc Gets the available liquidity for an asset.
;; @param asset principal The asset's contract principal.
;; @returns (response uint uint) The available liquidity.
(define-read-only (get-available-liquidity (asset principal))
  (let (
    (balance (unwrap! (contract-call? asset get-balance (as-contract tx-sender)) (err u0)))
    (total-borrows (get total-borrows (var-get vault-state)))
  )
    (ok (- balance total-borrows))
  )
)

;; @desc Updates the total supply of the vault.
;; @param amount uint The amount to add or remove.
;; @param op (string-ascii 10) The operation ("add" or "remove").
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
    (ok true)
  )
)

;; @desc Updates the total borrows of the vault.
;; @param amount uint The amount to add or remove.
;; @param op (string-ascii 10) The operation ("add" or "remove").
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
    (ok true)
  )
)

;; ===== Admin Functions =====

;; @desc Sets the dimensional engine contract address.
;; @param engine principal The new dimensional engine contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-dimensional-engine (engine principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dimensional-engine engine)
    (ok true)
  )
)

;; @desc Sets the dimensional registry contract address.
;; @param registry principal The new dimensional registry contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-dim-registry (registry principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set dim-registry registry)
    (ok true)
  )
)

;; @desc Pauses or unpauses the vault.
;; @param paused bool The new paused status.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set is-paused paused)
    (ok true)
  )
)

;; @desc Sets the interest rate model contract address.
;; @param model principal The new interest rate model contract principal.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (set-interest-rate-model (model principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set interest-rate-model model)
    (ok true)
  )
)
