;; ===========================================
;; MONITORING & SECURITY TRAITS MODULE
;; ===========================================
;; @desc System monitoring and security traits.
;; Essential for protocol safety and transparency.

;; ===========================================
;; PROTOCOL MONITOR TRAIT
;; ===========================================
;; @desc Interface for a protocol monitor.
(define-trait protocol-monitor-trait
  (
    ;; @desc Get the health score of the protocol.
    ;; @returns (response uint uint): The health score of the protocol, or an error code.
    (get-health-score () (response uint uint))

    ;; @desc Get the risk metrics of the protocol.
    ;; @returns (response { ... } uint): A tuple containing the risk metrics of the protocol, or an error code.
    (get-risk-metrics () (response {
      total-exposure: uint,
      liquidation-ratio: uint,
      utilization-rate: uint
    } uint))

    ;; @desc Trigger an emergency pause of the protocol.
    ;; @param reason: The reason for the emergency pause.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (trigger-emergency-pause ((string-ascii 256)) (response bool uint))
  )
)

;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
;; @desc Interface for a circuit breaker.
(define-trait circuit-breaker-trait
  (
    ;; @desc Check if the circuit is open.
    ;; @returns (response bool uint): True if the circuit is open, false otherwise, or an error code.
    (is-circuit-open () (response bool uint))

    ;; @desc Trigger an emergency pause.
    ;; @param reason: The reason for the emergency pause.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (emergency-pause ((string-ascii 256)) (response bool uint))

    ;; @desc Resume from an emergency pause.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (resume-emergency () (response bool uint))

    ;; @desc Get the status of the circuit breaker.
    ;; @returns (response { ... } uint): A tuple containing the status of the circuit breaker, or an error code.
    (get-status () (response {
      is-open: bool,
      reason: (string-ascii 256),
      last-updated: uint
    } uint))

    ;; @desc Record a failure.
    ;; @param reason: The reason for the failure.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (record-failure ((string-ascii 256)) (response bool uint))
  )
)
