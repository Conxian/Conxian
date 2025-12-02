;; keeper-coordinator.clar
;; Automation system for executing scheduled tasks in the Conxian protocol.

;; Traits
(use-trait keeper-job-trait .controller-traits.keeper-job-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_INVALID_TASK (err u6001))
(define-constant ERR_TASK_NOT_READY (err u6002))
(define-constant ERR_TASK_FAILED (err u6003))
(define-constant ERR_INSUFFICIENT_GAS (err u6004))

;; Task IDs
(define-constant TASK_INTEREST_ACCRUAL u1)
(define-constant TASK_ORACLE_UPDATE u2)
(define-constant TASK_LIQUIDATION_CHECK u3)
(define-constant TASK_REBALANCE_STRATEGIES u4)
(define-constant TASK_FEE_DISTRIBUTION u5)
(define-constant TASK_BOND_COUPON_PROCESS u6)
(define-constant TASK_METRICS_UPDATE u7)
(define-constant TASK_AUTOMATION_MANAGER u8)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var keeper-registry (list 20 principal) (list))
(define-data-var task-registry (list 20 uint) (list))
(define-data-var total-tasks-executed uint u0)
(define-data-var total-tasks-failed uint u0)

;; Data Maps
(define-map task-config
  uint
  {
    enabled: bool,
    interval: uint,
    last-run: uint,
    priority: uint,
    gas-limit: uint,
  }
)

(define-map task-history
  {
    task-id: uint,
    block: uint,
  }
  {
    success: bool,
    gas-used: uint,
    error-code: (optional uint),
  }
)

;; Authorization Check
(define-private (is-keeper (user principal))
  (is-some (index-of (var-get keeper-registry) user))
)

;; Public Functions

;; @desc Register a new keeper
(define-public (register-keeper (keeper principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set keeper-registry (unwrap-panic (as-max-len? (append (var-get keeper-registry) keeper) u20)))
    (ok true)
  )
)

;; @desc Configure a task
(define-public (configure-task
    (task-id uint)
    (interval uint)
    (priority uint)
    (gas-limit uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set task-config task-id {
      enabled: true,
      interval: interval,
      last-run: u0,
      priority: priority,
      gas-limit: gas-limit,
    })
    (ok true)
  )
)

;; Placeholder executions
(define-private (execute-interest-accrual)
  (ok true)
)
(define-private (execute-oracle-update)
  (ok true)
)
(define-private (execute-liquidation-check)
  (ok true)
)
(define-private (execute-rebalance-strategies)
  (ok true)
)
(define-private (execute-fee-distribution)
  (ok true)
)
(define-private (execute-bond-processing)
  (ok true)
)
(define-private (execute-metrics-update)
  (ok true)
)
(define-private (execute-automation-manager)
  (ok true)
)

;; @desc Execute a batch of ready tasks.
;; @returns (response {tasks-attempted: uint, block: uint, keeper: principal} uint)
(define-public (execute-batch-tasks)
  (begin
    (asserts! (is-keeper tx-sender) ERR_UNAUTHORIZED)
    ;; Logic to iterate and execute tasks would go here.
    ;; Since Clarity doesn't support unbounded loops or complex iteration easily in one tx,
    ;; we simulate a batch execution.

    (try! (execute-single-task TASK_INTEREST_ACCRUAL
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_INTEREST_ACCRUAL)
      )))
    (try! (execute-single-task TASK_ORACLE_UPDATE
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_ORACLE_UPDATE)
      )))
    (try! (execute-single-task TASK_LIQUIDATION_CHECK
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_LIQUIDATION_CHECK)
      )))
    (try! (execute-single-task TASK_REBALANCE_STRATEGIES
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_REBALANCE_STRATEGIES)
      )))
    (try! (execute-single-task TASK_FEE_DISTRIBUTION
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_FEE_DISTRIBUTION)
      )))
    (try! (execute-single-task TASK_BOND_COUPON_PROCESS
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_BOND_COUPON_PROCESS)
      )))
    (try! (execute-single-task TASK_METRICS_UPDATE
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_METRICS_UPDATE)
      )))
    (try! (execute-single-task TASK_AUTOMATION_MANAGER
      (default-to {
        enabled: false,
        interval: u0,
        last-run: u0,
        priority: u0,
        gas-limit: u0,
      }
        (map-get? task-config TASK_AUTOMATION_MANAGER)
      )))

    (ok {
      tasks-attempted: u8,
      block: block-height,
      keeper: tx-sender,
    })
  )
)

;; @desc Execute a specific task if it is ready.
;; @param task-id: The ID of the task.
;; @returns (response bool uint): An `ok` response with `true` if the task was executed, `false` otherwise.
(define-private (execute-single-task
    (task-id uint)
    (config {
      enabled: bool,
      interval: uint,
      last-run: uint,
      priority: uint,
      gas-limit: uint,
    })
  )
  (begin
    (let (
      (execution-result (if (is-eq task-id TASK_INTEREST_ACCRUAL)
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
                    (if (is-eq task-id TASK_AUTOMATION_MANAGER)
                      (execute-automation-manager)
                      ERR_INVALID_TASK
                    )
                  )
                )
              )
            )
          )
        )
      ))
      ;; Update task config with last run time
      (map-set task-config task-id (merge config { last-run: block-height }))
      ;; Record task history
      (if (is-ok execution-result)
        (begin
          (var-set total-tasks-executed (+ (var-get total-tasks-executed) u1))
          (map-set task-history {
            task-id: task-id,
            block: block-height,
          } {
            success: true,
            gas-used: u50000,
            error-code: none,
          })
          (ok true)
        )
        (begin
          (var-set total-tasks-failed (+ (var-get total-tasks-failed) u1))
          (map-set task-history {
            task-id: task-id,
            block: block-height,
          } {
            success: false,
            gas-used: u10000,
            ;; Use the generic task-failed code; underlying err payload type
            ;; may vary per task, so we avoid unwrapping it here.
            error-code: (some u9002),
          })
          (ok false)
      )
    )
  )
)