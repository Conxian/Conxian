;; ===========================================
;; GOVERNANCE TOKEN TRAIT
;; ===========================================
;; @desc Interface for governance tokens.
;; This trait provides functions for managing a governance token,
;; including voting power, delegation, and proposal submission.
;;
;; @example
;; (use-trait governance-token .governance-token-trait.governance-token-trait)
(define-trait governance-token-trait
  (
    ;; @desc Get the voting power of a principal.
    ;; @param user: The principal to check.
    ;; @returns (response uint uint): The voting power of the principal, or an error code.
    (get-voting-power (principal) (response uint uint))

    ;; @desc Delegate voting power to another principal.
    ;; @param delegatee: The principal to delegate to.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (delegate (principal) (response bool uint))

    ;; @desc Undelegate voting power.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (undelegate () (response bool uint))

    ;; @desc Get the current delegatee of a principal.
    ;; @param user: The principal to check.
    ;; @returns (response (optional principal) uint): The delegatee of the principal, or none if not delegated.
    (get-delegatee (principal) (response (optional principal) uint))
  )
)
