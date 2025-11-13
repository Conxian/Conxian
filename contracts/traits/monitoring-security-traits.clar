;; ===========================================
;; MONITORING & SECURITY TRAITS MODULE
;; ===========================================
;; System monitoring and security traits
;; Essential for protocol safety and transparency

;; ===========================================
;; PROTOCOL MONITOR TRAIT
;; ===========================================
(define-trait protocol-monitor-trait
  (
    (get-health-score () (response uint uint))
    (get-risk-metrics () (response {
      total-exposure: uint,
      liquidation-ratio: uint,
      utilization-rate: uint
    } uint))
    (trigger-emergency-pause ((string-ascii 256)) (response bool uint))
  )
)

;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
(define-trait circuit-breaker-trait
  (
    (is-circuit-open () (response bool uint))
    (emergency-pause ((string-ascii 256)) (response bool uint))
    (resume-emergency () (response bool uint))
    (get-status () (response {
      is-open: bool,
      reason: (string-ascii 256),
      last-updated: uint
    } uint))
    (record-failure ((string-ascii 256)) (response bool uint))
  )
)
