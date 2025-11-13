;; keeper-coordinator.clar
;; Central coordinator for automated keeper tasks across the Conxian protocol
;; Manages automated interest accrual, liquidations, rebalancing, and fee distribution
(use-trait keeper_coordinator_trait .keeper-coordinator-trait.keeper-coordinator-trait)
(use-trait rbac-trait .decentralized-trait-registry.decentralized-trait-registry)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u9001))
(define-constant ERR_TASK_FAILED (err u9002))
(define-constant ERR_TASK_NOT_READY (err u9003))
(define-constant ERR_INVALID_TASK (err u9004))
(define-constant ERR_KEEPER_PAUSED (err u9005))

;; Task IDs
(define-constant TASK_INTEREST_ACCRUAL u1)
(define-constant TASK_ORACLE_UPDATE u2)
(define-constant TASK_LIQUIDATION_CHECK u3)
(define-constant TASK_REBALANCE_STRATEGIES u4)
(define-constant TASK_FEE_DISTRIBUTION u5)
(define-constant TASK_BOND_COUPON_PROCESS u6)
(define-constant TASK_METRICS_UPDATE u7)
(define-constant TASK_AUTOMATION_MANAGER u8) ;; Added

;; ===== Data Variables =====

(define-data-var keeper-enabled bool true)
(define-data-var last-execution-block uint u0)
(define-data-var execution-interval uint u10) ;; Execute every 10 blocks (~10 minutes)

;; Keeper whitelist
(define-map authorized-keepers principal bool)

;; Task configuration
(define-map task-config uint {
  enabled: bool,
  interval: uint,
  last-run: uint,
  priority: uint,
  gas-limit: uint
})

;; Task execution history
(define-map task-history {task-id: uint, block: uint} {
  success: bool,
  gas-used: uint,
  error-code: (optional uint)
})

;; Registered contracts for automation
(define-data-var interest-rate-contract (optional principal) none)
(define-data-var oracle-contract (optional principal) none)
(define-data-var liquidation-contract (optional principal) none)
(define-data-var yield-optimizer-contract (optional principal) none)
(define-data-var revenue-distributor-contract (optional principal) none)
(define-data-var rbac-contract (optional principal) none)
(define-data-var automation-manager-contract (optional principal) none) ;; Added

;; Performance metrics
(define-data-var total-tasks-executed uint u0)
(define-data-var total-tasks-failed uint u0)
(define-data-var total-gas-used uint u0)

;; ===== Authorization =====
(define-private (check-is-owner)
  (match (var-get rbac-contract)
    rbac-principal
    (ok (asserts! (is-ok (contract-call? rbac-principal has-role "contract-owner")) ERR_UNAUTHORIZED))
    ERR_UNAUTHORIZED))

(define-private (check-is-keeper)
  (match (var-get rbac-contract)
    rbac-principal
    (ok (asserts! (or (is-ok (contract-call? rbac-principal has-role "contract-owner"))
                      (default-to false (map-get? authorized-keepers tx-sender)))
                  ERR_UNAUTHORIZED))
    ERR_UNAUTHORIZED))

(define-private (check-keeper-enabled)
  (ok (asserts! (var-get keeper-enabled) ERR_KEEPER_PAUSED)))

;; ===== Admin Functions =====
(define-public (set-keeper-enabled (enabled bool))
  (begin
    (try! (check-is-owner))
    (var-set keeper-enabled enabled)
    (ok true)))

(define-public (add-keeper (keeper principal))
  (begin
    (try! (check-is-owner))
    (map-set authorized-keepers keeper true)
    (ok true)))

(define-public (remove-keeper (keeper principal))
  (begin
    (try! (check-is-owner))
    (map-set authorized-keepers keeper false)
    (ok true)))

(define-public (set-execution-interval (interval uint))
  (begin
    (try! (check-is-owner))
    (var-set execution-interval interval)
    (ok true)))

(define-public (set-interest-rate-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set interest-rate-contract (some contract))
    (ok true)))

(define-public (set-oracle-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set oracle-contract (some contract))
    (ok true)))

(define-public (set-liquidation-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set liquidation-contract (some contract))
    (ok true)))

(define-public (set-yield-optimizer-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set yield-optimizer-contract (some contract))
    (ok true)))

(define-public (set-revenue-distributor-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set revenue-distributor-contract (some contract))
    (ok true)))

(define-public (set-bond-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set bond-contract (some contract))
    (ok true)))

(define-public (set-rbac-contract (contract principal))
  (begin
    (try! (check-is-owner))
    (var-set rbac-contract (some contract))
    (ok true)))

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

;; ===== Core Keeper Functions =====

;; Main keeper execution function - executes all ready tasks
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
      (execute-task-if-ready TASK_AUTOMATION_MANAGER) ;; Added
    )))
      (ok {
        tasks-attempted: u8,
        block: block-height,
        keeper: tx-sender
      }))))

;; Execute specific task if ready
(define-private (execute-task-if-ready (task-id uint))
  (match (map-get? task-config task-id)
    config
    (if (and (get enabled config)
             (>= (- block-height (get last-run config)) (get interval config)))
        (execute-single-task task-id config)
        (ok false))
    (ok false)))

;; Execute a single task
(define-private (execute-single-task (task-id uint) (config {enabled: bool, interval: uint, last-run: uint, priority: uint, gas-limit: uint}))
  (let ((execution-result
    (if (is-eq task-id TASK_INTEREST_ACCRUAL)
        (execute-interest-accrual)
        (if (is-eq task-id TASK_ORACLE_UPDATE)
            (execute-oracle-update)
            (if (is-eq task-id TASK_LIQUIDATION_CHECK)
                (execute-liquidation-check)
                (if (is-eq task-id TASK_REBALANCE_STRATEGIES)
                    (execute-rebalance-strategies)
                    (if (is-eq task-id TASK_FEE_DISTRIBUTION)
                        (execute-fee-distribution)
                        (if (is-eq task-id TASK_BOND_COUPON_PROCESS)
                            (execute-bond-processing)
                            (if (is-eq task-id TASK_METRICS_UPDATE)
                                (execute-metrics-update)
                                (if (is-eq task-id TASK_AUTOMATION_MANAGER) ;; Added
                                    (execute-automation-manager)
                                    (err ERR_INVALID_TASK))))))))))
    
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
            error-code: (some (unwrap-panic (unwrap-err-panic execution-result)))
          })
          (ok false)))))

;; ===== Task Implementations =====

;; Task 1: Interest Accrual
(define-private (execute-interest-accrual)
  (match (var-get interest-rate-contract)
    contract-principal
    ;; In production, call actual interest accrual function
    ;; (contract-call? contract-principal accrue-all-markets)
    (ok true)
    ERR_TASK_FAILED))

;; Task 2: Oracle Update
(define-private (execute-oracle-update)
  (match (var-get oracle-contract)
    contract-principal
    ;; In production, call actual oracle update function
    ;; (contract-call? contract-principal update-all-prices)
    (ok true)
    ERR_TASK_FAILED))

;; Task 3: Liquidation Check
(define-private (execute-liquidation-check)
  (match (var-get liquidation-contract)
    contract-principal
    ;; In production, call actual liquidation check function
    ;; (contract-call? contract-principal check-and-liquidate-undercollateralized)
    (ok true)
    ERR_TASK_FAILED))

;; Task 4: Rebalance Strategies
(define-private (execute-rebalance-strategies)
  (match (var-get yield-optimizer-contract)
    contract-principal
    ;; In production, call actual rebalance function
    ;; (contract-call? contract-principal optimize-all-strategies)
    (ok true)
    ERR_TASK_FAILED))

;; Task 5: Fee Distribution
(define-private (execute-fee-distribution)
  (match (var-get revenue-distributor-contract)
    contract-principal
    ;; In production, call actual fee distribution function
    ;; (contract-call? contract-principal distribute-fees)
    (ok true)
    ERR_TASK_FAILED))

;; Task 6: Bond Coupon Processing
(define-private (execute-bond-processing)
  (match (var-get bond-contract)
    contract-principal
    ;; In production, call actual bond processing function
    ;; (contract-call? contract-principal process-matured-coupons)
    (ok true)
    ERR_TASK_FAILED))

;; Task 7: Metrics Update
(define-private (execute-metrics-update)
  ;; Update system-wide performance metrics
  (ok true))

;; Task 8: Automation Manager
(define-private (execute-automation-manager)
  (match (var-get automation-manager-contract)
    contract-principal
    ;; In production, call actual automation manager function
    ;; (contract-call? contract-principal execute-automation)
    (ok true)
    ERR_TASK_FAILED))

;; ===== Read-Only Functions =====

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

(define-read-only (get-task-config (task-id uint))
  (map-get? task-config task-id))

(define-read-only (is-task-ready (task-id uint))
  (match (map-get? task-config task-id)
    config
    (and (get enabled config)
         (>= (- block-height (get last-run config)) (get interval config)))
    false))

(define-read-only (get-task-history (task-id uint) (block uint))
  (map-get? task-history {task-id: task-id, block: block}))

(define-read-only (is-authorized-keeper (keeper principal))
  (or (is-eq keeper (var-get contract-owner))
      (default-to false (map-get? authorized-keepers keeper))))

(define-read-only (get-configured-contracts)
  {
    interest-rate: (var-get interest-rate-contract),
    oracle: (var-get oracle-contract),
    liquidation: (var-get liquidation-contract),
    yield-optimizer: (var-get yield-optimizer-contract),
    revenue-distributor: (var-get revenue-distributor-contract),
    bond: (var-get bond-contract),
    automation-manager: (var-get automation-manager-contract) ;; Added
  })

;; Check if keeper should execute
(define-read-only (should-execute-now)
  (and (var-get keeper-enabled)
       (>= (- block-height (var-get last-execution-block)) (var-get execution-interval))))

(define-data-var tasks (list 10 {name: (string-ascii 32), contract: principal, enabled: bool}) 
  (
    {name: "interest-accrual", contract: .interest-rate-model, enabled: true},
    {name: "oracle-update", contract: .oracle-aggregator-v2, enabled: true},
    {name: "liquidation", contract: .liquidation-engine, enabled: true},
    {name: "fee-distribution", contract: .fee-distributor, enabled: true},
    {name: "automation-manager", contract: .automation-manager, enabled: true}  
  )
)
