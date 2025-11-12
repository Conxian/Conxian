;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
;; Interface for circuit breaker functionality.
;;
;; This trait defines the core functionality for circuit breaker systems,
;; providing emergency stop mechanisms and status checking.
;;
;; Example usage:
;;   (use-trait circuit-breaker-trait .circuit-breaker-trait.circuit-breaker-trait)

(define-trait circuit-breaker-trait
  (
    ;; Check if the circuit breaker is open (active)
    ;; @return (response bool uint): true if circuit is open, false if closed, error code
    (is-circuit-open () (response bool uint))

    ;; Emergency pause the system
    ;; @param reason Reason for pausing
    ;; @return (response bool uint): success or error code
    (emergency-pause ((string-ascii 256)) (response bool uint))

    ;; Resume from emergency pause
    ;; @return (response bool uint): success or error code
    (resume-emergency () (response bool uint))

    ;; Get circuit breaker status details
    ;; @return (response {active: bool, reason: (string-ascii 256), last-updated: uint} uint)
    (get-status () (response {active: bool, reason: (string-ascii 256), last-updated: uint} uint))
  )
)
