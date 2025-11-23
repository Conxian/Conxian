;; @desc Central coordinator for automated keeper tasks across the Conxian protocol.
;; This contract manages automated interest accrual, liquidations, rebalancing, and fee distribution.

(use-trait keeper_coordinator_trait .keeper-coordinator-trait.keeper-coordinator-trait)
(use-trait rbac-trait .decentralized-trait-registry.decentralized-trait-registry)

;; @constants
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED (err u1001))
;; @var ERR_TASK_FAILED: The task failed to execute.
(define-constant ERR_TASK_FAILED (err u9002))
;; @var ERR_TASK_NOT_READY: The task is not ready to be executed.
(define-constant ERR_TASK_NOT_READY (err u9003))
;; @var ERR_INVALID_TASK: The specified task is invalid.
(define-constant ERR_INVALID_TASK (err u9004))
;; @var ERR_KEEPER_PAUSED: The keeper is currently paused.
(define-constant ERR_KEEPER_PAUSED (err u1003))

;; @var TASK_INTEREST_ACCRUAL: The ID for the interest accrual task.
(define-constant TASK_INTEREST_ACCRUAL u1)
;; @var TASK_ORACLE_UPDATE: The ID for the oracle update task.
(define-constant TASK_ORACLE_UPDATE u2)
;; @var TASK_LIQUIDATION_CHECK: The ID for the liquidation check task.
(define-constant TASK_LIQUIDATION_CHECK u3)
;; @var TASK_REBALANCE_STRATEGIES: The ID for the rebalance strategies task.
(define-constant TASK_REBALANCE_STRATEGIES u4)
;; @var TASK_FEE_DISTRIBUTION: The ID for the fee distribution task.
(define-constant TASK_FEE_DISTRIBUTION u5)
;; @var TASK_BOND_COUPON_PROCESS: The ID for the bond coupon process task.
(define-constant TASK_BOND_COUPON_PROCESS u6)
;; @var TASK_METRICS_UPDATE: The ID for the metrics update task.
(define-constant TASK_METRICS_UPDATE u7)
;; @var TASK_AUTOMATION_MANAGER: The ID for the automation manager task.
(define-constant TASK_AUTOMATION_MANAGER u8)

;; @data-vars
;; @var keeper-enabled: A boolean indicating if the keeper is enabled.
(define-data-var keeper-enabled bool true)
;; @var last-execution-block: The block height of the last execution.
(define-data-var last-execution-block uint u0)
;; @var execution-interval: The interval at which the keeper executes tasks.
(define-data-var execution-interval uint u10) ;; Execute every 10 blocks (~10 minutes)
;; @var authorized-keepers: A map of authorized keepers.
(define-map authorized-keepers principal bool)
;; @var task-config: A map of task configurations.
(define-map task-config uint {enabled: bool, interval: uint, last-run: uint, priority: uint, gas-limit: uint})
;; @var task-history: A map of task execution history.
(define-map task-history {task-id: uint, block: uint} {success: bool, gas-used: uint, error-code: (optional uint)})
;; @var interest-rate-contract: The principal of the interest rate contract.
(define-data-var interest-rate-contract (optional principal) none)
;; @var interest-rate-assets: The list of assets that require periodic interest accrual.
(define-data-var interest-rate-assets (list 10 principal) (list))
;; @var oracle-contract: The principal of the oracle contract.
(define-data-var oracle-contract (optional principal) none)
;; @var liquidation-contract: The principal of the liquidation contract.
(define-data-var liquidation-contract (optional principal) none)
;; @var yield-optimizer-contract: The principal of the yield optimizer contract.
(define-data-var yield-optimizer-contract (optional principal) none)
;; @var revenue-distributor-contract: The principal of the revenue distributor contract.
(define-data-var revenue-distributor-contract (optional principal) none)
;; @var rbac-contract: The principal of the RBAC contract.
(define-data-var rbac-contract (optional principal) none)
;; @var automation-manager-contract: The principal of the automation manager contract.
(define-data-var automation-manager-contract (optional principal) none)
;; @var total-tasks-executed: The total number of tasks executed.
(define-data-var total-tasks-executed uint u0)
;; @var total-tasks-failed: The total number of tasks failed.
(define-data-var total-tasks-failed uint u0)
;; @var total-gas-used: The total amount of gas used.
(define-data-var total-gas-used uint u0)

;; --- Authorization ---
;; @desc Check if the caller is the contract owner.
;; @returns (response bool uint): An `ok` response with `true` if the caller is the owner, or an error code.
(define-private (check-is-owner)
  (match (var-get rbac-contract)
    rbac-principal
    (ok (asserts! (is-ok (contract-call? rbac-principal has-role "contract-owner")) ERR_UNAUTHORIZED))
    (err ERR_UNAUTHORIZED)))

;; @desc Check if the caller is a keeper.
;; @returns (response bool uint): An `ok` response with `true` if the caller is a keeper, or an error code.
(define-private (check-is-keeper)
  (match (var-get rbac-contract)
    rbac-principal
    (ok (asserts! (or (is-ok (contract-call? rbac-principal has-role "contract-owner"))
                      (default-to false (map-get? authorized-keepers tx-sender)))
                  ERR_UNAUTHORIZED))
    (err ERR_UNAUTHORIZED)))

;; @desc Check if the keeper is enabled.
;; @returns (response bool uint): An `ok` response with `true` if the keeper is enabled, or an error code.
(define-private (check-keeper-enabled)
  (ok (asserts! (var-get keeper-enabled) ERR_KEEPER_PAUSED)))

;; --- Admin Functions ---
;; @desc Set the keeper enabled status.
;; @param enabled: A boolean indicating if the keeper is enabled.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-keeper-enabled (enabled bool))
  (begin
    (try! (check-is-owner))
    (var-set keeper-enabled enabled)
    (ok true)))

;; @desc Add a keeper to the whitelist.
;; @param keeper: The principal of the keeper to add.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (add-keeper (keeper principal))
  (begin
    (try! (check-is-owner))
    (map-set authorized-keepers keeper true)
    (ok true)))

;; @desc Remove a keeper from the whitelist.
;; @param keeper: The principal of the keeper to remove.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (remove-keeper (keeper principal))
  (begin
    (try! (check-is-owner))
    (map-delete authorized-keepers keeper)
    (ok true)))

;; @desc Set the execution interval.
;; @param interval: The new execution interval in blocks.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-execution-interval (interval uint))
  (begin
    (try! (check-is-owner))
    (var-set execution-interval interval)
    (ok true)))

;; @desc Set the interest rate contract.
;; @param contract: The principal of the interest rate contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-interest-rate-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set interest-rate-contract (some contract))
    (ok true)))

;; @desc Configure the assets that require periodic interest accrual.
;; @param assets: A list of asset principals to accrue interest for.
;; @returns (response bool uint)
(define-public (set-interest-rate-assets (assets (list 10 principal)))
  (begin
    (try! (check-is-owner))
    (var-set interest-rate-assets assets)
    (ok true)
  )
)

;; @desc Set the oracle contract.
;; @param contract: The principal of the oracle contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-oracle-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set oracle-contract (some contract))
    (ok true)))

;; @desc Set the liquidation contract.
;; @param contract: The principal of the liquidation contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-liquidation-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set liquidation-contract (some contract))
    (ok true)))

;; @desc Set the yield optimizer contract.
;; @param contract: The principal of the yield optimizer contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-yield-optimizer-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set yield-optimizer-contract (some contract))
    (ok true)))

;; @desc Set the revenue distributor contract.
;; @param contract: The principal of the revenue distributor contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-revenue-distributor-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set revenue-distributor-contract (some contract))
    (ok true)))

;; @desc Set the bond contract.
;; @param contract: The principal of the bond contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-bond-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set bond-contract (some contract))
    (ok true)))

;; @desc Set the RBAC contract.
;; @param contract: The principal of the RBAC contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-rbac-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set rbac-contract (some contract))
    (ok true)))

;; @desc Configure a task.
;; @param task-id: The ID of the task.
;; @param enabled: A boolean indicating if the task is enabled.
;; @param interval: The execution interval for the task in blocks.
;; @param priority: The priority of the task.
;; @param gas-limit: The gas limit for the task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (configure-task (task-id uint) (enabled bool) (interval uint) (priority uint) (gas-limit uint))
  (begin
    (try! (check-is-owner))
    (map-set task-config task-id {
      enabled: enabled,
      interval: interval,
      last-run: u0,
      priority: priority,
      gas-limit: gas-limit
    })
    (ok true)))

;; --- Core Keeper Functions ---

;; @desc Execute all ready keeper tasks.
;; @returns (response { ... } uint): A tuple containing the results of the execution, or an error code.
(define-public (execute-keeper-tasks)
  (begin
    (try! (check-is-keeper))
    (try! (check-keeper-enabled))
    
    ;; Update last execution
    (var-set last-execution-block block-height)
    
    ;; Execute tasks in priority order
    (let ((results (list
      (execute-task-if-ready TASK_INTEREST_ACCRUAL)
      (execute-task-if-ready TASK_ORACLE_UPDATE)
      (execute-task-if-ready TASK_LIQUIDATION_CHECK)
      (execute-task-if-ready TASK_REBALANCE_STRATEGIES)
      (execute-task-if-ready TASK_FEE_DISTRIBUTION)
      (execute-task-if-ready TASK_BOND_COUPON_PROCESS)
      (execute-task-if-ready TASK_METRICS_UPDATE)
      (execute-task-if-ready TASK_AUTOMATION_MANAGER)
    )))
      (ok {
        tasks-attempted: u8,
        block: block-height,
        keeper: tx-sender
      }))))

;; @desc Execute a specific task if it is ready.
;; @param task-id: The ID of the task.
;; @returns (response bool uint): An `ok` response with `true` if the task was executed, `false` otherwise.
(define-private (execute-task-if-ready (task-id uint))
  (match (map-get? task-config task-id)
    config
    (if (and (get enabled config)
             (>= (- block-height (get last-run config)) (get interval config)))
        (execute-single-task task-id config)
        (ok false))
    (ok false)))

(define-private (execute-single-task (task-id uint) (config {enabled: bool, interval: uint, last-run: uint, priority: uint, gas-limit: uint}))
  (let (
    (execution-result
      (match task-id
        TASK_INTEREST_ACCRUAL (execute-interest-accrual)
        TASK_ORACLE_UPDATE (execute-oracle-update)
        TASK_LIQUIDATION_CHECK (execute-liquidation-check)
        TASK_REBALANCE_STRATEGIES (execute-rebalance-strategies)
        TASK_FEE_DISTRIBUTION (execute-fee-distribution)
        TASK_BOND_COUPON_PROCESS (execute-bond-processing)
        TASK_METRICS_UPDATE (execute-metrics-update)
        TASK_AUTOMATION_MANAGER (execute-automation-manager)
        (err ERR_INVALID_TASK)
      )
    )
  )
    ;; Update task config with last run time
    (map-set task-config task-id (merge config {last-run: block-height}))

    ;; Record task history
    (if (is-ok execution-result)
        (begin
          (var-set total-tasks-executed (+ (var-get total-tasks-executed) u1))
          (map-set task-history {task-id: task-id, block: block-height} {
            success: true,
            gas-used: u50000,
            error-code: none
          })
          (ok true))
        (begin
          (var-set total-tasks-failed (+ (var-get total-tasks-failed) u1))
          (map-set task-history {task-id: task-id, block: block-height} {
            success: false,
            gas-used: u10000,
            error-code: (some (unwrap-err-panic execution-result))
          })
          (ok false)))))

;; @desc Execute the oracle update task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-oracle-update)
  (match (var-get oracle-contract)
    contract-principal
    (contract-call? contract-principal update-all-prices)
    (err ERR_TASK_FAILED)))

;; @desc Execute the liquidation check task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-liquidation-check)
  (match (var-get liquidation-contract)
    contract-principal
    (contract-call? contract-principal check-and-liquidate-undercollateralized)
    (err ERR_TASK_FAILED)))

;; @desc Execute the rebalance strategies task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-rebalance-strategies)
  (match (var-get yield-optimizer-contract)
    contract-principal
    (contract-call? contract-principal optimize-all-strategies)
    (err ERR_TASK_FAILED)))

;; @desc Execute the fee distribution task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-fee-distribution)
  (match (var-get revenue-distributor-contract)
    contract-principal
    (contract-call? contract-principal distribute-fees)
    (err ERR_TASK_FAILED)))

;; @desc Execute the bond processing task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-bond-processing)
  (match (var-get bond-contract)
    contract-principal
    (contract-call? contract-principal process-matured-coupons)
    (err ERR_TASK_FAILED)))

;; @desc Execute the metrics update task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-metrics-update)
  (ok true))

;; @desc Execute the automation manager task.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-private (execute-automation-manager)
  (match (var-get automation-manager-contract)
    contract-principal
    (contract-call? contract-principal run-daily-automation)
    (err ERR_TASK_FAILED)))

;; @desc Execute the interest accrual task across configured assets.
;; @returns (response bool uint): `(ok true)` on success, or an error code if the interest rate contract is not set.
(define-private (execute-interest-accrual)
  (match (var-get interest-rate-contract)
    contract-principal (let ((assets (var-get interest-rate-assets)))
      (if (is-eq (len assets) u0)
        (err ERR_TASK_FAILED)
        (let ((result (fold execute-interest-accrual-for-asset assets {
            status: (ok true),
            contract: contract-principal,
          })))
          (get status result)
        )
      )
    )
    (err ERR_TASK_FAILED)
  )
)

(define-private (execute-interest-accrual-for-asset
    (asset principal)
    (state {
      status: (response bool uint),
      contract: principal,
    })
  )
  (if (is-err (get status state))
    state
    {
      status: (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.lending-system accrue-interest asset),
      contract: (get contract state),
    }
  )
)

;; --- Read-Only Functions ---

;; @desc Get the keeper status.
;; @returns ({ ... }): A tuple containing the keeper status.
(define-read-only (get-keeper-status)
  {
    enabled: (var-get keeper-enabled),
    last-execution: (var-get last-execution-block),
    interval: (var-get execution-interval),
    total-executed: (var-get total-tasks-executed),
    total-failed: (var-get total-tasks-failed),
    success-rate: (if (> (var-get total-tasks-executed) u0)
                      (/ (* (var-get total-tasks-executed) u10000)
                         (+ (var-get total-tasks-executed) (var-get total-tasks-failed)))
                      u0)
  })

;; @desc Get the configuration for a task.
;; @param task-id: The ID of the task.
;; @returns (optional { ... }): A tuple containing the task configuration, or none if not found.
(define-read-only (get-task-config (task-id uint))
  (map-get? task-config task-id))

;; @desc Check if a task is ready to be executed.
;; @param task-id: The ID of the task.
;; @returns (bool): True if the task is ready, false otherwise.
(define-read-only (is-task-ready (task-id uint))
  (match (map-get? task-config task-id)
    config
    (and (get enabled config)
         (>= (- block-height (get last-run config)) (get interval config)))
    false))

;; @desc Get the history for a task.
;; @param task-id: The ID of the task.
;; @param block: The block height.
;; @returns (optional { ... }): A tuple containing the task history, or none if not found.
(define-read-only (get-task-history (task-id uint) (block uint))
  (map-get? task-history {task-id: task-id, block: block}))

;; @desc Check if a principal is an authorized keeper.
;; @param keeper: The principal to check.
;; @returns (bool): True if the principal is an authorized keeper, false otherwise.
(define-read-only (is-authorized-keeper (keeper principal))
  (or (is-eq keeper (var-get contract-owner))
      (default-to false (map-get? authorized-keepers keeper))))

;; @desc Get the configured contracts.
;; @returns ({ ... }): A tuple containing the configured contracts.
(define-read-only (get-configured-contracts)
  {
    interest-rate: (var-get interest-rate-contract),
    oracle: (var-get oracle-contract),
    liquidation: (var-get liquidation-contract),
    yield-optimizer: (var-get yield-optimizer-contract),
    revenue-distributor: (var-get revenue-distributor-contract),
    bond: (var-get bond-contract),
    automation-manager: (var-get automation-manager-contract)
  })

;; @desc Check if the keeper should execute now.
;; @returns (bool): True if the keeper should execute now, false otherwise.
(define-read-only (should-execute-now)
  (and (var-get keeper-enabled)
       (>= (- block-height (var-get last-execution-block)) (var-get execution-interval))))

;; @data-vars
;; @var tasks: A list of tasks. Initialized empty; can be configured via admin functions.
(define-data-var tasks (list 10 {name: (string-ascii 32), contract: principal, enabled: bool}) (list))
