;; yield-optimizer.clar
;; The central brain of the Conxian yield system.
;; This contract dynamically analyzes and allocates funds across various yield-generating
;; strategies to maximize returns for the protocol.

;; --- Traits ---
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(use-trait vault-trait .vault-trait.vault-trait)
(use-trait strategy-trait .strategy-trait.strategy-trait)
(use-trait metrics-trait .metrics-trait.metrics-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u8001))
(define-constant ERR_STRATEGY_ALREADY_EXISTS (err u8002))
(define-constant ERR_STRATEGY_NOT_FOUND (err u8003))
(define-constant ERR_REBALANCE_FAILED (err u8006))
(define-constant ERR_INVALID_CONTRACT (err u8007))
(define-constant ERR_METRICS_CALL_FAILED (err u8008))

;; --- Data Variables ---
(define-data-var admin principal tx-sender)
(define-data-var vault-contract principal tx-sender)
(define-data-var metrics-contract (contract-of metrics-trait) (as-contract tx-sender))
(define-data-var strategy-count uint u0)

;; --- Maps ---
(define-map strategies uint (tuple
  (contract principal)
  (is-active bool)
))

(define-map asset-allocation principal (tuple
  (strategy principal)
  (amount uint)
))

;; === ADMIN FUNCTIONS ===
;; @desc Sets the contract administrator.
;; @param new-admin The principal of the new administrator.
;; @returns An `(ok bool)` result indicating success, or an error.
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

;; @desc Sets the vault and metrics contracts.
;; @param vault The principal of the vault contract.
;; @param metrics The principal of the metrics contract.
;; @returns An `(ok bool)` result indicating success, or an error.
(define-public (set-contracts (vault principal) (metrics (contract-of metrics-trait)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set vault-contract vault)
    (var-set metrics-contract metrics)
    (ok true)))

(define-public (add-strategy (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((id (var-get strategy-count)))
      (map-set strategies id (tuple
        (contract contract)
        (is-active true)
      ))
      (var-set strategy-count (+ id u1))
      (ok id))))

;; @desc Toggles the active status of a registered strategy.
;; @param id (uint) The ID of the strategy to toggle.
;; @param is-active (bool) The new active status (true for active, false for inactive).
;; @return (response bool) An (ok true) response if the status was successfully toggled, or an error if unauthorized or the strategy is not found.
(define-public (toggle-strategy-status (id uint) (is-active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((strategy-data (unwrap! (map-get? strategies id) ERR_STRATEGY_NOT_FOUND)))
      (map-set strategies id (merge strategy-data (tuple (is-active is-active))))
      (ok true))))

;; === PRIVATE HELPERS ===
(define-private (find-best-strategy-iter (id uint) (best-so-far (tuple (contract principal) (apy uint) (yield-efficiency uint) (vault-performance uint))))
  (if (>= id (var-get strategy-count))
    (ok best-so-far)
    (match (map-get? strategies id)
      (some strategy-data)
      (if (get is-active strategy-data)
        (let (
          (apy (try! (contract-call? (var-get metrics-contract) get-apy (get contract strategy-data))))
          (yield-efficiency (try! (contract-call? (var-get metrics-contract) get-yield-efficiency (get contract strategy-data))))
          (vault-performance (try! (contract-call? (var-get metrics-contract) get-vault-performance (get contract strategy-data))))
          (current-score (+ apy yield-efficiency vault-performance))
          (memo-score (+ (get apy best-so-far) (get yield-efficiency best-so-far) (get vault-performance best-so-far)))
        )
          (if (> current-score memo-score)
            (find-best-strategy-iter (+ id u1) (tuple (contract (get contract strategy-data)) (apy apy) (yield-efficiency yield-efficiency) (vault-performance vault-performance)))
            (find-best-strategy-iter (+ id u1) best-so-far)
          )
        )
        (find-best-strategy-iter (+ id u1) best-so-far)
      )
      none (find-best-strategy-iter (+ id u1) best-so-far)
    )
  )
)

;; @desc Finds the best active strategy based on APY.
;; @return (response { contract: principal, apy: uint }) A response containing the contract principal of the best strategy and its APY.
(define-private (find-best-strategy)
  (find-best-strategy-iter u0 (tuple (contract (as-contract tx-sender)) (apy u0) (yield-efficiency u0) (vault-performance u0)))
)

;; === CORE OPTIMIZER LOGIC ===
;; @desc Optimizes and rebalances the allocation of a specific asset across strategies.
;; @param asset (<sip-010-ft-trait>) The asset trait to optimize.
;; @return (response bool) An (ok true) response if the optimization and rebalancing was successful, or an error otherwise.
(define-public (optimize-and-rebalance (asset (contract-of sip-010-ft-trait)))
  (let ((current-allocation (default-to (tuple (strategy (as-contract tx-sender)) (amount u0)) (map-get? asset-allocation (contract-of asset))))
        (current-strategy (get strategy current-allocation))
        (best-strategy-info (try! (find-best-strategy))))

    (if (not (is-eq current-strategy (get contract best-strategy-info)))
      (begin
        (let ((vault (var-get vault-contract))
              (total-balance (try! (contract-call? vault get-total-balance asset))))

          ;; Withdraw from old strategy
          (if (not (is-eq current-strategy (as-contract tx-sender)))
            (try! (contract-call? vault withdraw-from-strategy asset (get amount current-allocation) current-strategy))
            (print "No current strategy to withdraw from.")
          )

          ;; Deposit to new best strategy
          (try! (contract-call? vault deposit-to-strategy asset total-balance (get contract best-strategy-info)))

          ;; Update allocation map
          (map-set asset-allocation (contract-of asset) (tuple
            (strategy (get contract best-strategy-info))
            (amount total-balance)
          ))

          (print (tuple (event "rebalanced") (from current-strategy) (to (get contract best-strategy-info)) (amount total-balance)))
          (ok true)
        )
      )
      (ok false) ;; No rebalance needed
    )
  )
)
