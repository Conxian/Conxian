;; ===========================================
;; PROTOCOL MONITOR TRAIT
;; ===========================================
;; @desc Interface for monitoring and controlling protocol state.
;; This trait provides functions to monitor protocol health, check invariants,
;; and handle emergency situations like pausing the protocol.
;;
;; @example
;; (use-trait monitor-trait .protocol-monitor-trait.protocol-monitor-trait)
(define-trait protocol-monitor-trait
  (
    ;; @desc Checks if the protocol is currently paused.
    ;; @returns (response bool uint): True if paused, false otherwise, or an error code.
    (is-paused () (response bool uint))

    ;; @desc Verifies that all protocol invariants are satisfied.
    ;; @returns (response bool uint): True if all invariants hold, false otherwise, or an error code.
    (check-invariants () (response bool uint))

    ;; @desc Pauses all non-essential protocol functions (emergency only).
    ;; Only callable by governance or an emergency multisig.
    ;; @returns (response bool uint): True if successful, or an error code.
    (emergency-pause () (response bool uint))

    ;; @desc Resumes normal protocol operations after a pause.
    ;; Only callable by governance or an emergency multisig.
    ;; @returns (response bool uint): True if successful, or an error code.
    (resume-normal-ops () (response bool uint))
  )
)
