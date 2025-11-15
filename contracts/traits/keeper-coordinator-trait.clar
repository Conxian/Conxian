;; ===========================================
;; KEEPER COORDINATOR TRAIT
;; ===========================================
;; @desc Interface for automated keeper task coordination.
;; This trait provides functions for managing automated tasks
;; such as interest accrual, liquidations, and protocol maintenance.
;;
;; @example
;; (use-trait keeper .keeper-coordinator-trait.keeper-coordinator-trait)
(define-trait keeper-coordinator-trait
  (
    ;; @desc Execute automated interest accrual.
    ;; @returns (response uint uint): The amount accrued, or an error code.
    (execute-interest-accrual () (response uint uint))

    ;; @desc Execute automated liquidations.
    ;; @returns (response uint uint): The number of liquidations, or an error code.
    (execute-liquidations () (response uint uint))

    ;; @desc Register a new keeper task.
    ;; @param task-id: A unique identifier for the task.
    ;; @param task-contract: The contract that implements the task.
    ;; @param frequency: How often the task should run (in blocks).
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (register-task ((string-ascii 64) principal uint) (response bool uint))

    ;; @desc Deregister an existing keeper task.
    ;; @param task-id: The unique identifier of the task to deregister.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (deregister-task ((string-ascii 64)) (response bool uint))

    ;; @desc Get the details of a specific task.
    ;; @param task-id: The unique identifier of the task.
    ;; @returns (response (tuple ...) uint): A tuple containing the task details, or an error code.
    (get-task ((string-ascii 64)) (response (tuple (contract principal) (frequency uint) (last-run uint) (active bool)) uint))
  )
)
