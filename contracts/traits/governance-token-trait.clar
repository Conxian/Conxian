;; ===========================================
;; GOVERNANCE TOKEN TRAIT
;; ===========================================
;; Interface for governance tokens
;;
;; This trait provides functions for managing a governance token,
;; including voting power, delegation, and proposal submission.
;;
;; Example usage:
;;   (use-trait governance-token .governance-token-trait.governance-token-trait)
(define-trait governance-token-trait
  (
    ;; Get voting power of a principal
    ;; @param user: principal to check
    ;; @return (response uint uint): voting power and error code
    (get-voting-power (principal) (response uint uint))

    ;; Delegate voting power
    ;; @param delegatee: principal to delegate to
    ;; @return (response bool uint): success flag and error code
    (delegate (principal) (response bool uint))

    ;; Undelegate voting power
    ;; @return (response bool uint): success flag and error code
    (undelegate () (response bool uint))

    ;; Get current delegatee of a principal
    ;; @param user: principal to check
    ;; @return (response (optional principal) uint): delegatee or none, and error code
    (get-delegatee (principal) (response (optional principal) uint))
  )
)
