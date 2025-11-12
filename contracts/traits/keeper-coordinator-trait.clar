;; ===========================================
;; KEEPER COORDINATOR TRAIT
;; ===========================================
;; Interface for automated keeper task coordination
;;
;; This trait provides functions for managing automated tasks
;; such as interest accrual, liquidations, and protocol maintenance.
;;
;; Example usage:
;;   (use-trait keeper .all-traits.keeper-coordinator-trait)
(define-trait keeper-coordinator-trait
  (
    ;; Execute automated interest accrual
    ;; @return (response uint uint): amount accrued and error code
    (execute-interest-accrual () (response uint uint))

    ;; Execute automated liquidations
    ;; @return (response uint uint): number of liquidations and error code
    (execute-liquidations () (response uint uint))

    ;; Register a new keeper task
    ;; @param task-id: unique task identifier
    ;; @param task-contract: contract implementing the task
    ;; @param frequency: how often the task should run (in blocks)
    ;; @return (response bool uint): success flag and error code
    (register-task ((string-ascii 64) principal uint) (response bool uint))

    ;; Deregister an existing keeper task
    ;; @param task-id: unique task identifier
    ;; @return (response bool uint): success flag and error code
    (deregister-task ((string-ascii 64)) (response bool uint))

    ;; Get task details
    ;; @param task-id: unique task identifier
    ;; @return (response (tuple ...) uint): task details and error code
    (get-task ((string-ascii 64)) (response (tuple (contract principal) (frequency uint) (last-run uint) (active bool)) uint))
  )
)
