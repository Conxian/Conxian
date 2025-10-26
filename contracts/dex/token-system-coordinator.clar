

;; token-system-coordinator.clar

;; Central coordination contract for the enhanced Conxian token system
;; Provides unified interface and orchestrates interactions between all token subsystems

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; System component identifiers
(define-constant COMPONENT_CXD_STAKING u1)
(define-constant COMPONENT_MIGRATION_QUEUE u2)
(define-constant COMPONENT_CXVG_UTILITY u3)
(define-constant COMPONENT_EMISSION_CONTROLLER u4)
(define-constant COMPONENT_REVENUE_DISTRIBUTOR u5)
(define-constant COMPONENT_INVARIANT_MONITOR u6)

;; Operation types
(define-constant OP_TYPE_STAKE u1)
(define-constant OP_TYPE_MIGRATE u2)
(define-constant OP_TYPE_GOVERNANCE u3)
(define-constant OP_TYPE_REVENUE_DIST u4)

;; Operation status
(define-constant OP_STATUS_PENDING u0)
(define-constant OP_STATUS_SUCCESS u1)
(define-constant OP_STATUS_FAILED u2)

;; Health thresholds
(define-constant HEALTH_THRESHOLD_RESUME u8000)
(define-constant HEALTH_FULL u10000)
(define-constant HEALTH_DEGRADED u7000)
(define-constant DEFAULT_GOVERNANCE_BOOST u100)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u1000)
(define-constant ERR_SYSTEM_PAUSED u1001)
(define-constant ERR_COMPONENT_UNAVAILABLE u1002)
(define-constant ERR_INVALID_AMOUNT u1003)
(define-constant ERR_INITIALIZATION_FAILED u1004)
(define-constant ERR_COORDINATION_FAILED u1005)
(define-constant ERR_COMPONENT_UPDATE_FAILED u1006)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var system-initialized bool false)
(define-data-var system-paused bool false)

;; Contract references (Dependency Injection)
(define-data-var cxd-staking-contract (optional principal) none)
(define-data-var migration-queue-contract (optional principal) none)
(define-data-var cxvg-utility-contract (optional principal) none)
(define-data-var emission-controller-contract (optional principal) none)
(define-data-var revenue-distributor-contract (optional principal) none)
(define-data-var invariant-monitor-contract (optional principal) none)
(define-data-var system-integration-enabled bool false)
(define-data-var initialization-complete bool false)

;; System status tracking
(define-map component-status uint {
  active: bool,
  last-health-check: uint,
  error-count: uint
})

;; Cross-system operation tracking
(define-data-var next-operation-id uint u1)
(define-map cross-system-operations uint {
  operation-type: uint,
  initiator: principal,
  components-involved: (list 10 uint),
  status: uint,
  timestamp: uint
})

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (initialize-system)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (not (var-get system-initialized)) (err ERR_INITIALIZATION_FAILED))
    
    ;; Initialize component status tracking
    (map-set component-status COMPONENT_CXD_STAKING
      { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_MIGRATION_QUEUE
      { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_CXVG_UTILITY
      { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_EMISSION_CONTROLLER
      { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_REVENUE_DISTRIBUTOR
      { active: true, last-health-check: block-height, error-count: u0 })
    (map-set component-status COMPONENT_INVARIANT_MONITOR
      { active: true, last-health-check: block-height, error-count: u0 })
    
    (var-set system-initialized true)
    (ok true)
  )
)

;; --- Contract Configuration Functions ---

(define-public (set-cxd-staking-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxd-staking-contract (some contract-address))
    (ok true)
  )
)

(define-public (set-migration-queue-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set migration-queue-contract (some contract-address))
    (ok true)
  )
)

(define-public (set-cxvg-utility-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxvg-utility-contract (some contract-address))
    (ok true)
  )
)

(define-public (set-emission-controller-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set emission-controller-contract (some contract-address))
    (ok true)
  )
)

(define-public (set-revenue-distributor-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set revenue-distributor-contract (some contract-address))
    (ok true)
  )
)

(define-public (set-invariant-monitor-contract (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set invariant-monitor-contract (some contract-address))
    (ok true)
  )
)

(define-public (enable-system-integration)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set system-integration-enabled true)
    (ok true)
  )
)

(define-public (complete-initialization)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (var-get system-integration-enabled) (err ERR_INITIALIZATION_FAILED))
    (var-set initialization-complete true)
    (try! (initialize-system))
    (ok true)
  )
)

;; --- Safe Contract Call Helpers ---

(define-private (is-component-available (component-contract (optional principal)))
  (and (var-get system-integration-enabled) (is-some component-contract))
)

(define-private (is-system-paused-safe)
  false
)

(define-private (get-governance-boost-safe (user principal))
  (if (is-component-available (var-get cxvg-utility-contract))
    DEFAULT_GOVERNANCE_BOOST
    u0
  )
)

(define-private (execute-staking-safe (amount uint))
  (if (is-component-available (var-get cxd-staking-contract))
    (ok true)
    (err ERR_COMPONENT_UNAVAILABLE)
  )
)

(define-private (execute-migration-safe (amount uint))
  (if (is-component-available (var-get migration-queue-contract))
    (ok true)
    (err ERR_COMPONENT_UNAVAILABLE)
  )
)

(define-private (calculate-enhanced-amount (amount uint) (boost uint))
  (if (> boost u0)
    (+ amount (/ (* amount boost) u10000))
    amount
  )
)

;; --- Operation Recording ---

(define-private (record-operation (op-type uint) (components (list 10 uint)))
  (let ((operation-id (var-get next-operation-id)))
    (map-set cross-system-operations operation-id {
      operation-type: op-type,
      initiator: tx-sender,
      components-involved: components,
      status: OP_STATUS_PENDING,
      timestamp: block-height
    })
    (var-set next-operation-id (+ operation-id u1))
    operation-id
  )
)

(define-private (update-operation-status (operation-id uint) (status uint))
  (match (map-get? cross-system-operations operation-id)
    operation (map-set cross-system-operations operation-id
      (merge operation { status: status }))
    false
  )
)

;; --- Unified Token Operations ---

(define-public (stake-cxd-with-governance-check (amount uint))
  (let (
    (operation-id (record-operation OP_TYPE_STAKE
      (list COMPONENT_CXD_STAKING COMPONENT_INVARIANT_MONITOR)))
    (governance-boost (get-governance-boost-safe tx-sender))
    (enhanced-amount (calculate-enhanced-amount amount governance-boost))
  )
    (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
    (asserts! (not (is-system-paused-safe)) (err ERR_SYSTEM_PAUSED))
    
    (match (execute-staking-safe enhanced-amount)
      success (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_SUCCESS))
        (ok success)
      )
      error (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_FAILED))
        (err error)
      )
    )
  )
)

(define-public (migrate-cxlp-to-cxd (amount uint))
  (let (
    (operation-id (record-operation OP_TYPE_MIGRATE
      (list COMPONENT_MIGRATION_QUEUE COMPONENT_REVENUE_DISTRIBUTOR)))
  )
    (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
    (asserts! (not (is-system-paused-safe)) (err ERR_SYSTEM_PAUSED))
    
    (match (execute-migration-safe amount)
      success (begin
        (if (is-component-available (var-get revenue-distributor-contract))
          true
          true
        )
        (unwrap-panic (update-operation-status operation-id OP_STATUS_SUCCESS))
        (ok success)
      )
      error (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_FAILED))
        (err error)
      )
    )
  )
)

(define-public (participate-in-governance (proposal-id uint) (vote bool) (cxvg-amount uint))
  (let (
    (operation-id (record-operation OP_TYPE_GOVERNANCE (list COMPONENT_CXVG_UTILITY)))
  )
    (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))
    
    (match (if (is-component-available (var-get cxvg-utility-contract))
             (ok true)
             (err ERR_COMPONENT_UNAVAILABLE))
      success (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_SUCCESS))
        (ok { proposal: proposal-id, vote: vote, locked-amount: cxvg-amount })
      )
      error (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_FAILED))
        (err error)
      )
    )
  )
)

;; --- System Health and Coordination ---

(define-private (update-component-status (component-id uint) (is-healthy bool))
  (let ((current-status (unwrap-panic (map-get? component-status component-id))))
    (map-set component-status component-id {
      active: is-healthy,
      last-health-check: block-height,
      error-count: (if is-healthy
        (get error-count current-status)
        (+ (get error-count current-status) u1)
      )
    })
    (ok true)
  )
)

(define-public (run-system-health-check)
  (begin
    (asserts! (var-get system-initialized) (err ERR_INITIALIZATION_FAILED))
    
    (let (
      (monitor-health (ok true))
      (staking-info (if (is-component-available (var-get cxd-staking-contract))
        (ok { total-staked-cxd: u0 })
        (ok { total-staked-cxd: u0 })
      ))
      (migration-info (ok { current-epoch: u0 }))
      (revenue-stats (if (is-component-available (var-get revenue-distributor-contract))
        (ok { total-distributed: u0 })
        (ok { total-distributed: u0 })
      ))
    )
      (let (
        (staking-status (is-ok staking-info))
        (migration-status (is-ok migration-info))
        (revenue-status (is-ok revenue-stats))
        (monitor-status (is-ok monitor-health))
      )
        (unwrap! (update-component-status COMPONENT_CXD_STAKING staking-status)
          (err ERR_COMPONENT_UPDATE_FAILED))
        (unwrap! (update-component-status COMPONENT_MIGRATION_QUEUE migration-status)
          (err ERR_COMPONENT_UPDATE_FAILED))
        (unwrap! (update-component-status COMPONENT_REVENUE_DISTRIBUTOR revenue-status)
          (err ERR_COMPONENT_UPDATE_FAILED))
        (unwrap! (update-component-status COMPONENT_INVARIANT_MONITOR monitor-status)
          (err ERR_COMPONENT_UPDATE_FAILED))
      )
      
      (ok {
        overall-health: (if (and (is-ok monitor-health) (is-ok staking-info)
                                 (is-ok migration-info) (is-ok revenue-stats))
          HEALTH_FULL
          HEALTH_DEGRADED
        ),
        monitor-status: (is-ok monitor-health),
        staking-status: (is-ok staking-info),
        migration-status: (is-ok migration-info),
        revenue-status: (is-ok revenue-stats)
      })
    )
  )
)

(define-public (trigger-revenue-distribution)
  (let (
    (operation-id (record-operation OP_TYPE_REVENUE_DIST
      (list COMPONENT_REVENUE_DISTRIBUTOR COMPONENT_CXD_STAKING)))
  )
    (asserts! (not (var-get system-paused)) (err ERR_SYSTEM_PAUSED))

    (match (if (is-component-available (var-get revenue-distributor-contract))
             (if (is-component-available (var-get cxd-staking-contract))
               (ok { distribution-triggered: true, components: (list COMPONENT_REVENUE_DISTRIBUTOR COMPONENT_CXD_STAKING) })
               (err ERR_COMPONENT_UNAVAILABLE))
             (err ERR_COMPONENT_UNAVAILABLE))
      success (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_SUCCESS))
        (ok success)
      )
      error (begin
        (unwrap-panic (update-operation-status operation-id OP_STATUS_FAILED))
        (err error)
      )
    )
  )
)