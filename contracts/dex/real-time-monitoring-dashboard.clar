;; ===== Traits =====
;; TODO: monitoring-dashboard-trait not defined in traits folder.clar
;; (use-trait monitoring-dashboard-trait .traits folder.monitoring-dash

;; Real-Time Monitoring Dashboard Contract
;; Provides comprehensive system monitoring, alerting, and metrics collection
;; for the enhanced tokenomics system with real-time dashboards

;; ===== Error Codes =====
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_INVALID_PARAMS (err u400))
(define-constant ERR_METRIC_NOT_FOUND (err u404))
(define-constant ERR_ALERT_ALREADY_EXISTS (err u409))

;; ===== Alert Severity Levels =====
(define-constant SEVERITY_INFO u0)
(define-constant SEVERITY_WARNING u1)
(define-constant SEVERITY_CRITICAL u2)
(define-constant SEVERITY_EMERGENCY u3)

;; ===== Metric Types =====
(define-constant METRIC_COUNTER u0)
(define-constant METRIC_GAUGE u1)
(define-constant METRIC_HISTOGRAM u2)
(define-constant METRIC_RATE u3)

;; ===== Configuration =====
(define-data-var contract-owner principal tx-sender)
(define-data-var monitoring-enabled bool true)
(define-data-var alert-threshold-multiplier uint u150) ;; 150% of baseline
(define-data-var retention-period uint u86400) ;; 24 hours

;; ===== System Metrics Storage =====
(define-map system-metrics
  { metric-name: (string-ascii 64), timestamp-window: uint }
  {
    value: uint,
    metric-type: uint,
    last-updated: uint,
    sample-count: uint
  })

;; ===== Real-time Dashboards =====
(define-map dashboard-configs
  { dashboard-name: (string-ascii 64) }
  {
    enabled: bool,
    refresh-interval: uint,
    metric-count: uint,
    created-at: uint
  })

;; ===== Dashboard Metrics Mapping =====
(define-map dashboard-metrics
  { dashboard-name: (string-ascii 64), metric-name: (string-ascii 64) }
  {
    display-order: uint,
    chart-type: (string-ascii 32),
    color-scheme: (string-ascii 16)
  })

;; ===== Active Alerts =====
(define-map active-alerts
  { alert-id: (string-ascii 64) }
  {
    metric-name: (string-ascii 64),
    severity: uint,
    threshold-value: uint,
    current-value: uint,
    triggered-at: uint,
    acknowledged: bool
  })

;; ===== Alert Rules =====
(define-map alert-rules
  { rule-name: (string-ascii 64) }
  {
    metric-name: (string-ascii 64),
    condition: (string-ascii 16), ;; "gt", "lt", "eq"
    threshold: uint,
    severity: uint,
    enabled: bool
  })

;; ===== Performance Baselines =====
(define-map performance-baselines
  { metric-name: (string-ascii 64) }
  {
    baseline-value: uint,
    variance-threshold: uint,
    last-calibrated: uint,
    sample-size: uint
  })

;; ===== Global Monitoring Stats =====
(define-data-var total-metrics uint u0)
(define-data-var total-alerts uint u0)
(define-data-var total-dashboards uint u0)
(define-data-var uptime-start uint u0)

;; ===== OWNER FUNCTIONS =====
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))

(define-public (configure-monitoring (enabled bool) (threshold-mult uint) (retention uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (and (> threshold-mult u100) (> retention u3600)) ERR_INVALID_PARAMS)
    (var-set monitoring-enabled enabled)
    (var-set alert-threshold-multiplier threshold-mult)
    (var-set retention-period retention)
    (ok true)))

;; ===== METRICS COLLECTION =====
(define-public (record-metric (metric-name (string-ascii 64)) (value uint) (metric-type uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (window-id (/ current-time u300)) ;; 5-minute windows
    (existing-metric (map-get? system-metrics { metric-name: metric-name, timestamp-window: window-id }))
  )
    (if (var-get monitoring-enabled)
      (begin
        (match existing-metric
          some-metric
          ;; Update existing metric
          (map-set system-metrics
            { metric-name: metric-name, timestamp-window: window-id }
            {
              value: (if (is-eq metric-type METRIC_COUNTER)
                       (+ (get value some-metric) value)
                       value),
              metric-type: metric-type,
              last-updated: current-time,
              sample-count: (+ (get sample-count some-metric) u1)
            })
          ;; Create new metric entry
          (begin
            (map-set system-metrics
              { metric-name: metric-name, timestamp-window: window-id }
              {
                value: value,
                metric-type: metric-type,
                last-updated: current-time,
                sample-count: u1
              })
            (var-set total-metrics (+ (var-get total-metrics) u1))))
        ;; Check for alert conditions
        (unwrap-panic (check-alert-conditions metric-name value))
        (ok true))
      (ok false))))

;; ===== DASHBOARD MANAGEMENT =====
(define-public (create-dashboard (dashboard-name (string-ascii 64)) (refresh-interval uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (> refresh-interval u10) ERR_INVALID_PARAMS)
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (map-set dashboard-configs
        { dashboard-name: dashboard-name }
        {
          enabled: true,
          refresh-interval: refresh-interval,
          metric-count: u0,
          created-at: current-time
        })
      (var-set total-dashboards (+ (var-get total-dashboards) u1))
      (ok true))))

(define-public (add-metric-to-dashboard 
  (dashboard-name (string-ascii 64)) 
  (metric-name (string-ascii 64)) 
  (display-order uint) 
  (chart-type (string-ascii 32)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? dashboard-configs { dashboard-name: dashboard-name })) ERR_INVALID_PARAMS)
    (map-set dashboard-metrics
      { dashboard-name: dashboard-name, metric-name: metric-name }
      {
        display-order: display-order,
        chart-type: chart-type,
        color-scheme: "blue"
      })
    ;; Update dashboard metric count
    (let (
      (dashboard (unwrap-panic (map-get? dashboard-configs { dashboard-name: dashboard-name })))
    )
      (map-set dashboard-configs
        { dashboard-name: dashboard-name }
        (merge dashboard { metric-count: (+ (get metric-count dashboard) u1) }))
      (ok true))))

;; ===== ALERTING SYSTEM =====
(define-public (create-alert-rule 
  (rule-name (string-ascii 64)) 
  (metric-name (string-ascii 64)) 
  (condition (string-ascii 16)) 
  (threshold uint) 
  (severity uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (asserts! (and (<= severity SEVERITY_EMERGENCY) (> threshold u0)) ERR_INVALID_PARAMS)
    (map-set alert-rules
      { rule-name: rule-name }
      {
        metric-name: metric-name,
        condition: condition,
        threshold: threshold,
        severity: severity,
        enabled: true
      })
    (ok true)))

(define-private (check-alert-conditions (metric-name (string-ascii 64)) (current-value uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    ;; Note: In a real implementation, we'd iterate through all alert rules
    ;; For now, this serves as a template for alert checking logic
    (ok true)))

(define-public (trigger-alert 
  (alert-id (string-ascii 64)) 
  (metric-name (string-ascii 64)) 
  (severity uint) 
  (threshold uint) 
  (current-value uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (map-set active-alerts
        { alert-id: alert-id }
        {
          metric-name: metric-name,
          severity: severity,
          threshold-value: threshold,
          current-value: current-value,
          triggered-at: current-time,
          acknowledged: false
        })
      (var-set total-alerts (+ (var-get total-alerts) u1))
      (ok true))))

(define-public (acknowledge-alert (alert-id (string-ascii 64)))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
      (alert (unwrap! (map-get? active-alerts { alert-id: alert-id }) ERR_METRIC_NOT_FOUND))
    )
      (map-set active-alerts
        { alert-id: alert-id }
        (merge alert { acknowledged: true }))
      (ok true))))

;; ===== PERFORMANCE MONITORING =====
(define-public (set-performance-baseline 
  (metric-name (string-ascii 64)) 
  (baseline-value uint) 
  (variance-threshold uint))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (map-set performance-baselines
        { metric-name: metric-name }
        {
          baseline-value: baseline-value,
          variance-threshold: variance-threshold,
          last-calibrated: current-time,
          sample-size: u1
        })
      (ok true))))

;; ===== SYSTEM HEALTH =====
(define-public (initialize-monitoring)
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (let (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
      (var-set uptime-start current-time)
      (var-set monitoring-enabled true)
      (ok true))))

;; ===== READ-ONLY FUNCTIONS =====
(define-read-only (get-owner)
  (var-get contract-owner))

(define-read-only (get-metric-value (metric-name (string-ascii 64)) (timestamp-window uint))
  (map-get? system-metrics { metric-name: metric-name, timestamp-window: timestamp-window }))

(define-read-only (get-dashboard-config (dashboard-name (string-ascii 64)))
  (map-get? dashboard-configs { dashboard-name: dashboard-name }))

(define-read-only (get-dashboard-metrics (dashboard-name (string-ascii 64)) (metric-name (string-ascii 64)))
  (map-get? dashboard-metrics { dashboard-name: dashboard-name, metric-name: metric-name }))

(define-read-only (get-active-alert (alert-id (string-ascii 64)))
  (map-get? active-alerts { alert-id: alert-id }))

(define-read-only (get-alert-rule (rule-name (string-ascii 64)))
  (map-get? alert-rules { rule-name: rule-name }))

(define-read-only (get-performance-baseline (metric-name (string-ascii 64)))
  (map-get? performance-baselines { metric-name: metric-name }))

(define-read-only (get-monitoring-stats)
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (uptime (if (> (var-get uptime-start) u0)
              (- current-time (var-get uptime-start))
              u0))
  )
    {
      total-metrics: (var-get total-metrics),
      total-alerts: (var-get total-alerts),
      total-dashboards: (var-get total-dashboards),
      monitoring-enabled: (var-get monitoring-enabled),
      uptime-seconds: uptime,
      alert-threshold-multiplier: (var-get alert-threshold-multiplier),
      retention-period: (var-get retention-period)
    }))

(define-read-only (calculate-system-health-score)
  ;; Simple health score calculation based on active alerts and system metrics
  (let (
    (base-score u10000) ;; 100.00% (using basis points)
    (alert-count (var-get total-alerts))
    (penalty-per-alert u500) ;; 5% penalty per active alert
  )
    (if (> alert-count u0)
      (let ((total-penalty (* alert-count penalty-per-alert)))
        (if (> total-penalty base-score)
          u0
          (- base-score total-penalty)))
      base-score)))

(define-read-only (is-monitoring-healthy)
  (and
    (var-get monitoring-enabled)
    (> (calculate-system-health-score) u7500))) ;; Health score above 75%
