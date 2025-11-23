;; Security & Monitoring Traits

;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
(define-trait circuit-breaker-trait
  (
    (trigger-circuit-breaker ((string-utf8 200)) (response bool uint))
    (reset-circuit-breaker () (response bool uint))
    (is-circuit-broken () (response bool uint))
    (assert-operational () (response bool uint))
  )
)

;; ===========================================
;; MEV PROTECTOR TRAIT
;; ===========================================
(define-trait mev-protector-trait
  (
    (validate-tx-ordering (uint (list 10 uint)) (response bool uint))
    (get-tenure-id () (response uint uint))
    (check-mev-attack (principal uint) (response bool uint))
  )
)

;; ===========================================
;; PROTOCOL MONITOR TRAIT
;; ===========================================
(define-trait protocol-monitor-trait
  (
    (get-system-health () (response {
      total-tvl: uint,
      active-positions: uint,
      circuit-breaker-status: bool,
      last-updated: uint
    } uint))
    
    (record-anomaly ((string-ascii 64) uint) (response bool uint))
    (get-recent-anomalies () (response (list 100 (string-ascii 64)) uint))
  )
)

;; ===========================================
;; AUDIT REGISTRY TRAIT
;; ===========================================
(define-trait audit-registry-trait
  (
    (submit-audit (principal (string-ascii 64) (string-utf8 256)) (response uint uint))
    (vote-on-audit (uint bool) (response bool uint))
    (get-audit-status (uint) (response (string-ascii 20) uint))
  )
)
