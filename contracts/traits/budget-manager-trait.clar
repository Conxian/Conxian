;; ===========================================
;; BUDGET MANAGER TRAIT
;; ===========================================
;; @desc Interface for treasury allocation and budget management.
;; This trait provides functions for managing protocol treasury
;; allocations and budget proposals within the DAO governance system.
;;
;; @example
;; (use-trait budget-manager .budget-manager-trait.budget-manager-trait)
(define-trait budget-manager-trait
  (
    ;; @desc Create a new budget allocation.
    ;; @param name: The name of the budget.
    ;; @param description: A description of the budget.
    ;; @param amount: The allocation amount.
    ;; @param duration: The duration of the budget in blocks.
    ;; @returns (response uint uint): The ID of the newly created budget, or an error code.
    (create-budget ((string-ascii 64) (string-utf8 256) uint uint) (response uint uint))

    ;; @desc Execute a budget allocation.
    ;; @param budget-id: The identifier of the budget.
    ;; @param recipient: The recipient address.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (execute-allocation (uint principal) (response bool uint))

    ;; @desc Get the details of a specific budget.
    ;; @param budget-id: The identifier of the budget.
    ;; @returns (response (tuple ...) uint): A tuple containing the budget details, or an error code.
    (get-budget (uint) (response (tuple (name (string-ascii 64)) (description (string-utf8 256)) (amount uint) (spent uint) (duration uint) (created-at uint) (status (string-ascii 20))) uint))

    ;; @desc Update the status of a budget.
    ;; @param budget-id: The identifier of the budget.
    ;; @param status: The new status of the budget.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (update-budget-status (uint (string-ascii 20)) (response bool uint))
  )
)
