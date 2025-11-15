;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
;; @desc Interface for circuit breaker functionality.
;; This trait defines the core functionality for circuit breaker systems,
;; providing emergency stop mechanisms and status checking.
;;
;; @example
;; (use-trait circuit-breaker-trait .circuit-breaker-trait.circuit-breaker-trait)

(define-trait circuit-breaker-trait
  (
    ;; @desc Check if the circuit breaker is open (active).
    ;; @returns (response bool uint): True if the circuit is open, false if closed, or an error code.
    (is-circuit-open () (response bool uint))

    ;; @desc Emergency pause the system.
    ;; @param reason: The reason for pausing.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (emergency-pause ((string-ascii 256)) (response bool uint))

    ;; @desc Resume the system from an emergency pause.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (resume-emergency () (response bool uint))

    ;; @desc Get the status details of the circuit breaker.
    ;; @returns (response {active: bool, reason: (string-ascii 256), last-updated: uint} uint): A tuple containing the status details, or an error code.
    (get-status () (response {active: bool, reason: (string-ascii 256), last-updated: uint} uint))
  )
)
