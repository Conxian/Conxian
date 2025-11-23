(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait finance-metrics-trait .dex-traits.finance-metrics-trait)
(use-trait rbac-trait .core-protocol.02-core-protocol.rbac-trait-trait)
;; Note: yield-strategy-trait and err-trait need to be added to appropriate modules or created
;; (use-trait yield-strategy-trait .base-traits.yield-strategy-trait)
;; (use-trait err-trait .base-traits.err-trait)

;; yield-optimizer.clar
;; The central brain of the Conxian yield system.
;; This contract dynamically analyzes and allocates funds across various yield-generating
;; strategies to maximize returns for the protocol.

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ACCESS_CONTROL_CONTRACT .access.roles)


;; --- Data Variables ---
(define-data-var vault-contract principal (as-contract tx-sender))
(define-data-var metrics-contract principal (as-contract tx-sender))
(define-data-var strategy-count uint u0)

;; --- Maps ---
(define-map strategies uint (tuple
  (contract principal)
  (is-active bool)
  (apy uint)
  (risk-score uint)
))

(define-map asset-allocation principal (tuple
  (amount uint)
  (last-rebalanced uint)
  (strategy-id uint)
))

;; --- Public Functions ---

;; @notice Initializes the core contract dependencies.
;; @desc Sets the vault and metrics contracts.
;; @param vault The principal of the vault contract.
;; @param metrics The principal of the metrics contract.
;; @returns An `(ok bool)` result indicating success, or an error.
(define-public (set-contracts (vault principal) (metrics principal))
  (begin
    (asserts! (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) (var-get tx-sender)) (err-trait ERR_YIELD_UNAUTHORIZED))
    (var-set vault-contract vault)
    (var-set metrics-contract metrics)
    (ok true)))

;; @notice Adds a new yield strategy to the optimizer, making it available for asset allocation.
;; @desc Adds a new yield strategy to the optimizer.
;; @param strategy-contract The principal of the yield strategy contract.
;; @param apy The annual percentage yield of the strategy.
;; @param risk-score The risk score associated with the strategy.
;; @returns An `(ok uint)` result with the strategy ID, or an error.
(define-public (add-strategy (strategy-contract principal) (apy uint) (risk-score uint))
  (begin
    (asserts! (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) (var-get tx-sender)) (err-trait ERR_YIELD_UNAUTHORIZED))
    (asserts! (is-none (map-get? strategies (var-get strategy-count))) (err-trait ERR_YIELD_STRATEGY_ALREADY_EXISTS))
    (let ((id (var-get strategy-count)))
      (map-set strategies id (tuple
        (contract strategy-contract)
        (is-active true)
        (apy apy)
        (risk-score risk-score)
      ))
      (var-set strategy-count (+ id u1))
      (ok id))))

;; @notice Toggles the active status of a registered strategy, enabling or disabling it for optimization.
;; @desc Toggles the active status of a registered strategy.
;; @param id The ID of the strategy to toggle.
;; @param is-active The new active status (true for active, false for inactive).
;; @returns An `(ok bool)` result indicating success, or an error.
(define-public (toggle-strategy-status (id uint) (is-active bool))
  (begin
    (asserts! (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) (var-get tx-sender)) (err-trait ERR_YIELD_UNAUTHORIZED))
    (let ((strategy-data (unwrap! (map-get? strategies id) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND))))
      (map-set strategies id (merge strategy-data (tuple (is-active is-active))))
      (ok true))))

;; @notice Updates the APY and risk score of an existing strategy, affecting its selection in optimization.
;; @desc Updates the APY and risk score of an existing strategy.
;; @param id The ID of the strategy to update.
;; @param new-apy The new annual percentage yield of the strategy.
;; @param new-risk-score The new risk score associated with the strategy.
;; @returns An `(ok bool)` result indicating success, or an error.
(define-public (update-strategy-parameters (id uint) (new-apy uint) (new-risk-score uint))
  (begin
    (asserts! (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) (var-get tx-sender)) (err-trait ERR_YIELD_UNAUTHORIZED))
    (let ((strategy-data (unwrap! (map-get? strategies id) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND))))
      (map-set strategies id (merge strategy-data (tuple (apy new-apy) (risk-score new-risk-score))))
      (ok true))))

;; @notice Optimizes and rebalances the allocation of a specific asset across strategies to maximize yield.
;; @desc Optimizes and rebalances the allocation of a specific asset across strategies.
;; @param asset The asset trait to optimize.
;; @returns An `(ok bool)` result indicating success, or an error otherwise.
(define-public (optimize-and-rebalance (asset <sip-010-ft-trait>))
  (begin
    (asserts! (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) (var-get tx-sender)) (err-trait ERR_YIELD_UNAUTHORIZED))
    (let (
      (current-block-height (get block-height tx-block-header))
      (asset-principal (contract-of asset))
      (best-strategy-info (try! (find-best-strategy-internal asset)))
      (best-strategy-id (get id best-strategy-info))
      (best-strategy-contract (get contract (unwrap! (map-get? strategies best-strategy-id) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND))))
      (current-allocation (default-to {amount: u0, last-rebalanced: u0, strategy-id: u0} (map-get? asset-allocation asset-principal)))
    )
      (asserts! (not (is-eq (get strategy-id current-allocation) best-strategy-id)) (err-trait ERR_YIELD_OPTIMIZATION_FAILED))

      (let (
        (vault (var-get vault-contract))
        (total-balance (try! (contract-call? vault get-total-balance asset)))
      )
        (if (not (is-eq (get amount current-allocation) u0))
          (try! (contract-call? vault withdraw-from-strategy asset (get amount current-allocation) (get contract (unwrap! (map-get? strategies (get strategy-id current-allocation)) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND)))))
        )

        (try! (contract-call? vault deposit-to-strategy asset total-balance best-strategy-contract))

        (map-set asset-allocation asset-principal {amount: total-balance, last-rebalanced: current-block-height, strategy-id: best-strategy-id})

        (print {event: "rebalanced", asset: asset-principal, from: (get strategy-id current-allocation), to: best-strategy-contract, amount: total-balance, block-height: current-block-height})
        (ok true)
      )
    )
  )
)

;; @notice Auto-compounds the yield for a specific asset by reinvesting earnings into the best performing strategy.
;; @desc Auto-compounds the yield for a specific asset.
;; @param asset The asset trait to auto-compound.
;; @returns An `(ok bool)` result indicating success, or an error.
(define-public (auto-compound (asset <sip-010-ft-trait>))
  (begin
    (asserts! (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) (var-get tx-sender)) (err-trait ERR_YIELD_UNAUTHORIZED))
    (let (
      (asset-principal (contract-of asset))
      (current-block-height (get block-height tx-block-header))
      (best-strategy-info (try! (find-best-strategy-internal asset)))
      (best-strategy-id (get id best-strategy-info))
      (best-strategy-contract (get contract (unwrap! (map-get? strategies best-strategy-id) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND))))
      (current-allocation (default-to {amount: u0, last-rebalanced: u0, strategy-id: u0} (map-get? asset-allocation asset-principal)))
    )
      (asserts! (not (is-eq (get amount current-allocation) u0)) (err-trait ERR_YIELD_NO_ALLOCATION_FOUND))

      ;; Call the compound function on the active strategy
      (try! (contract-call? best-strategy-contract compound asset (get amount current-allocation)))

      (map-set asset-allocation asset-principal {amount: (get amount current-allocation), last-rebalanced: current-block-height, strategy-id: best-strategy-id})

      (print {event: "auto-compound", asset: asset-principal, strategy: best-strategy-contract, amount: (get amount current-allocation), block-height: current-block-height})
      (ok true)
    )
  )
)

;; --- Private Helper Functions ---

;; @desc Finds the best active strategy based on APY and risk.
;; @param asset The asset trait for which to find the best strategy.
;; @returns A response containing the ID and contract principal of the best strategy, or an error.
(define-private (find-best-strategy-internal (asset <sip-010-ft-trait>))
  (let (
    (best-apy u0)
    (best-risk u100000000) ;; Assuming risk score is lower is better
    (best-strategy-id (none))
    (i u0)
  )
    (while (< i (var-get strategy-count))
      (let ((strategy-data (map-get? strategies i)))
        (if (is-some strategy-data)
          (let (
            (unwrapped-strategy (unwrap! strategy-data (err-trait ERR_YIELD_STRATEGY_NOT_FOUND)))
            (is-active (get is-active unwrapped-strategy))
            (current-apy (get apy unwrapped-strategy))
            (current-risk (get risk-score unwrapped-strategy))
          )
            (if is-active
              (if (or (> current-apy best-apy) (and (is-eq current-apy best-apy) (< current-risk best-risk)))
                (begin
                  (var-set best-apy current-apy)
                  (var-set best-risk current-risk)
                  (var-set best-strategy-id (some i)))
                true
              )
              true ;; Strategy is not active, skip it
            )
          )
          true ;; Strategy ID not found, skip it
        )
      )
      (var-set i (+ i u1))
    )
    (match best-strategy-id
      id (ok {id: id, contract: (get contract (unwrap! (map-get? strategies id) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND)))})
      (err (err-trait ERR_YIELD_NO_ACTIVE_STRATEGIES)))
  )
)

;; --- Read-Only Functions ---

;; @notice Retrieves the total number of registered yield strategies.
;; @desc Gets the total number of registered strategies.
;; @returns The total number of strategies.
(define-read-only (get-strategy-count)
  (ok (var-get strategy-count)))

;; @notice Retrieves the details of a specific yield strategy by its ID.
;; @desc Gets the details of a specific strategy.
;; @param id The ID of the strategy.
;; @returns A tuple containing strategy details, or an error if not found.
(define-read-only (get-strategy (id uint))
  (ok (unwrap! (map-get? strategies id) (err-trait ERR_YIELD_STRATEGY_NOT_FOUND))))

;; @notice Retrieves the current asset allocation for a given asset principal.
;; @desc Gets the current allocation for a specific asset.
;; @param asset The asset principal.
;; @returns A tuple containing allocation details, or a default if not found.
(define-read-only (get-asset-allocation (asset principal))
  (ok (default-to {amount: u0, last-rebalanced: u0, strategy-id: u0} (map-get? asset-allocation asset))))

;; @notice Checks if a given principal has the contract owner role.
;; @desc Checks if a given principal has the contract owner role.
;; @param account The principal to check.
;; @returns A boolean indicating if the account is the contract owner.
(define-read-only (is-contract-owner (account principal))
  (ok (contract-call? ACCESS_CONTROL_CONTRACT has-role (var-get CONTRACT_OWNER) account)))
