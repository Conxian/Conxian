;; keeper-coordinator.clar
;; Automation system for executing scheduled tasks in the Conxian protocol.


;; Traits
(use-trait keeper-job-trait .controller-traits.keeper-job-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)
(use-trait automation-trait .automation-traits.automation-trait)

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
(define-constant TASK_EPOCH_TRANSITION u9)
(define-constant TASK_AUTO_CONVERSION u10)
(define-constant TASK_OPEX_REPAYMENT u11)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var keeper-registry (list 20 principal) (list))
(define-data-var task-registry (list 20 uint) (list))
(define-data-var total-tasks-executed uint u0)
(define-data-var total-tasks-failed uint u0)
(define-data-var gamification-manager principal tx-sender)
(define-data-var points-oracle principal tx-sender)
(define-data-var self-launch-coordinator principal tx-sender)

;; Registry of automation targets that implement automation-trait.
;; This keeps keeper-coordinator as a lightweight directory, while
;; individual modules expose get-runnable-actions/execute-action.
(define-data-var automation-registry (list 20 principal) (list))

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
    (var-set keeper-registry
      (unwrap-panic (as-max-len? (append (var-get keeper-registry) keeper) u20))
    )
    (ok true)
  )
)

;; @desc Register an automation target implementing automation-trait
;; This does not execute tasks; it only tracks which contracts should be
;; polled by off-chain Guardians for get-runnable-actions.
(define-public (register-automation-target (target principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set automation-registry
      (unwrap-panic (as-max-len? (append (var-get automation-registry) target) u20))
    )
    (ok true)
  )
)

;; @desc Clear all registered automation targets (owner only).
(define-public (clear-automation-targets)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set automation-registry (list))
    (ok true)
  )
)

;; @desc List registered automation targets.
(define-read-only (get-automation-targets)
  (ok (var-get automation-registry))
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

;; Gamification Tasks
(define-private (execute-epoch-transition (epoch-id uint))
  (begin
    (try! (contract-call? .points-oracle-v2 finalize-epoch (- epoch-id u1)))
    (try! (contract-call? .gamification-manager initialize-epoch epoch-id block-height
      (+ block-height u518400) u45833 u45833
    ))
    (try! (contract-call? .points-oracle-v2 start-epoch epoch-id))
    (ok true)
  )
)

(define-private (execute-auto-conversion (epoch uint))
  (begin
    ;; Auto-convert unclaimed rewards after claim window
    ;; Real implementation would batch process users
    (print {
      event: "auto-conversion-triggered",
      epoch: epoch,
    })
    (ok true)
  )
)

(define-private (execute-opex-repayment)
  (begin
    ;; Check OPEX loan repayment conditions
    (try! (contract-call? (var-get self-launch-coordinator) check-automatic-repayment))
    (ok true)
  )
)

;; @desc Execute a batch of ready tasks.
;; @returns (response {tasks-attempted: uint, block: uint, keeper: principal} uint)

;; @desc Execute a batch of ready tasks.
;; @returns (response {tasks-attempted: uint, block: uint, keeper: principal} uint)
(define-public (execute-batch-tasks)
  (begin
    (asserts! (is-keeper tx-sender) ERR_UNAUTHORIZED)
    ;; Minimal body for debugging
    (ok {
      tasks-attempted: u0,
      block: block-height,
      keeper: tx-sender,
    })
  )
)

;; Admin Functions for Gamification
(define-public (set-gamification-manager (manager principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set gamification-manager manager)
    (ok true)
  )
)

(define-public (set-points-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set points-oracle oracle)
    (ok true)
  )
)

(define-public (set-self-launch-coordinator (coordinator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set self-launch-coordinator coordinator)
    (ok true)
  )
)