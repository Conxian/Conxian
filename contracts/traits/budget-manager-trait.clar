;; ===========================================
;; BUDGET MANAGER TRAIT
;; ===========================================
;; Interface for treasury allocation and budget management
;;
;; This trait provides functions for managing protocol treasury
;; allocations and budget proposals within the DAO governance system.
;;
;; Example usage:
;;   (use-trait budget-manager .all-traits.budget-manager-trait)
(define-trait budget-manager-trait
  (
    ;; Create a new budget allocation
    ;; @param name: budget name
    ;; @param description: budget description
    ;; @param amount: allocation amount
    ;; @param duration: budget duration in blocks
    ;; @return (response uint uint): budget ID and error code
    (create-budget ((string-ascii 64) (string-utf8 256) uint uint) (response uint uint))

    ;; Execute a budget allocation
    ;; @param budget-id: budget identifier
    ;; @param recipient: recipient address
    ;; @return (response bool uint): success flag and error code
    (execute-allocation (uint principal) (response bool uint))

    ;; Get budget details
    ;; @param budget-id: budget identifier
    ;; @return (response (tuple ...) uint): budget details and error code
    (get-budget (uint) (response (tuple (name (string-ascii 64)) (description (string-utf8 256)) (amount uint) (spent uint) (duration uint) (created-at uint) (status (string-ascii 20))) uint))

    ;; Update budget status
    ;; @param budget-id: budget identifier
    ;; @param status: new status
    ;; @return (response bool uint): success flag and error code
    (update-budget-status (uint (string-ascii 20)) (response bool uint))
  )
)
