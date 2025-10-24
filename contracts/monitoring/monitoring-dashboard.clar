;; monitoring-dashboard.clar
;; Provides read-only functions for system monitoring and health checks

(use-trait dimensional-core-trait .all-traits.dimensional-core-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait monitoring-trait .all-traits.monitoring-trait)

(use-trait monitoring_trait .all-traits.monitoring-trait)
 .all-traits.monitoring-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_MODULE (err u101))
(define-constant ERR_DATA_UNAVAILABLE (err u102))
(define-constant ERR_DASHBOARD_DISABLED (err u103))

(define-constant STATUS_OPERATIONAL "operational")
(define-constant STATUS_DEGRADED "degraded")
(define-constant STATUS_OFFLINE "offline")

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var dashboard-enabled bool true)
(define-data-var core-contract (optional principal) none)
(define-data-var oracle-contract (optional principal) none)
(define-data-var finance-metrics-contract (optional principal) none)
(define-data-var alert-threshold uint u9500) ;; 95% success rate threshold

;; Module health tracking
(define-map module-status
  (string-ascii 32)  ;; module-id
  {
    status: (string-ascii 20),
    last-updated: uint,
    error-count: uint,
    enabled: bool
  }
)

;; Transaction counters
(define-data-var total-transactions uint u0)
(define-data-var failed-transactions uint u0)
(define-data-var last-health-check uint u0)

;; Alert tracking
(define-map system-alerts
  uint  ;; alert-id
  {
    module: (string-ascii 32),
    severity: (string-ascii 20),
    message: (string-ascii 256),
    timestamp: uint,
    resolved: bool
  }
)
(define-data-var next-alert-id uint u1)

;; ===== Private Functions =====
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (calculate-success-rate (total uint) (failed uint))
  (if (> total u0)
    (/ (* (- total failed) u10000) total)
    u10000
  )
)

(define-private (determine-health-status (success-rate uint))
  (if (>= success-rate (var-get alert-threshold))
    STATUS_OPERATIONAL
    (if (>= success-rate u8000)
      STATUS_DEGRADED
      STATUS_OFFLINE
    )
  )
)

;; ===== Admin Functions =====
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-dashboard-enabled (enabled bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set dashboard-enabled enabled)
    (ok true)
  )
)

(define-public (set-alert-threshold (threshold uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (and (<= threshold u10000) (>= threshold u5000)) ERR_INVALID_MODULE)
    (var-set alert-threshold threshold)
    (ok true)
  )
)

(define-public (set-core-contract (core principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set core-contract (some core))
    (ok true)
  )
)

(define-public (set-oracle-contract (oracle principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set oracle-contract (some oracle))
    (ok true)
  )
)

(define-public (set-finance-metrics-contract (finance principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set finance-metrics-contract (some finance))
    (ok true)
  )
)

(define-public (update-module-status (module-id (string-ascii 32)) (status (string-ascii 20)) (error-count uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (var-get dashboard-enabled) ERR_DASHBOARD_DISABLED)
    (map-set module-status module-id {
      status: status,
      last-updated: block-height,
      error-count: error-count,
      enabled: true
    })
    (ok true)
  )
)

(define-public (toggle-module (module-id (string-ascii 32)) (enabled bool))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let ((current-status (unwrap! (map-get? module-status module-id) ERR_INVALID_MODULE)))
      (map-set module-status module-id (merge current-status { enabled: enabled }))
      (ok true)
    )
  )
)

(define-public (increment-transaction-counter (success bool))
  (begin
    (asserts! (var-get dashboard-enabled) ERR_DASHBOARD_DISABLED)
    (var-set total-transactions (+ (var-get total-transactions) u1))
    (if (not success)
      (var-set failed-transactions (+ (var-get failed-transactions) u1))
      true
    )
    (ok true)
  )
)

(define-public (create-alert (module (string-ascii 32)) (severity (string-ascii 20)) (message (string-ascii 256)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let ((alert-id (var-get next-alert-id)))
      (map-set system-alerts alert-id {
        module: module,
        severity: severity,
        message: message,
        timestamp: block-height,
        resolved: false
      })
      (var-set next-alert-id (+ alert-id u1))
      (ok alert-id)
    )
  )
)

(define-public (resolve-alert (alert-id uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let ((alert (unwrap! (map-get? system-alerts alert-id) ERR_DATA_UNAVAILABLE)))
      (map-set system-alerts alert-id (merge alert { resolved: true }))
      (ok true)
    )
  )
)

(define-public (reset-transaction-counters)
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set total-transactions u0)
    (var-set failed-transactions u0)
    (ok true)
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-system-health)
  (let (
    (uptime-blocks (- block-height (var-get last-health-check)))
    (total-tx (var-get total-transactions))
    (failed-tx (var-get failed-transactions))
    (success-rate (calculate-success-rate total-tx failed-tx))
    (health-status (determine-health-status success-rate))
  )
    (ok {
      status: health-status,
      enabled: (var-get dashboard-enabled),
      block-height: block-height,
      last-checked: (var-get last-health-check),
      uptime-blocks: uptime-blocks,
      total-transactions: total-tx,
      failed-transactions: failed-tx,
      success-rate: success-rate,
      alert-threshold: (var-get alert-threshold),
      core-configured: (is-some (var-get core-contract)),
      oracle-configured: (is-some (var-get oracle-contract)),
      finance-configured: (is-some (var-get finance-metrics-contract))
    })
  )
)

(define-read-only (get-module-status (module-id (string-ascii 32)))
  (ok (map-get? module-status module-id))
)

(define-read-only (get-transaction-stats)
  (let (
    (total (var-get total-transactions))
    (failed (var-get failed-transactions))
  )
    (ok {
      total: total,
      failed: failed,
      success-rate: (calculate-success-rate total failed),
      enabled: (var-get dashboard-enabled)
    })
  )
)

(define-read-only (get-alert (alert-id uint))
  (ok (map-get? system-alerts alert-id))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-read-only (get-configured-contracts)
  (ok {
    core: (var-get core-contract),
    oracle: (var-get oracle-contract),
    finance-metrics: (var-get finance-metrics-contract)
  })
)

(define-read-only (is-dashboard-enabled)
  (ok (var-get dashboard-enabled))
)

(define-read-only (get-alert-threshold)
  (ok (var-get alert-threshold))
)