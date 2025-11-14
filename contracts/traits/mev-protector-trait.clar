;; ===========================================
;; MEV PROTECTOR TRAIT
;; ===========================================
;; @desc Interface for MEV (Maximum Extractable Value) protection mechanisms.
;; This trait provides functions for protecting users from MEV attacks
;; including front-running, sandwich attacks, and fair ordering.
;;
;; @example
;; (use-trait mev-protector .mev-protector-trait.mev-protector-trait)
(define-trait mev-protector-trait
  (
    ;; @desc Submit a commit-reveal transaction.
    ;; @param commit-hash: The hash of the transaction details.
    ;; @param encrypted-payload: The encrypted transaction data.
    ;; @returns (response uint uint): The commit ID, or an error code.
    (submit-commit ((buff 32) (buff 1024)) (response uint uint))
    
    ;; @desc Reveal and execute a committed transaction.
    ;; @param commit-id: The commit identifier.
    ;; @param reveal-data: The revealed transaction details.
    ;; @param signature: The user's signature.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (reveal-and-execute (uint (buff 512) (buff 65)) (response bool uint))
    
    ;; @desc Submit a batch auction order.
    ;; @param orders: An array of orders to batch.
    ;; @param batch-deadline: The deadline for the batch execution.
    ;; @returns (response uint uint): The batch ID, or an error code.
    (submit-batch-auction ((list 50 (tuple (user principal) (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))) uint) (response uint uint))
    
    ;; @desc Execute a batch auction.
    ;; @param batch-id: The batch identifier.
    ;; @param clearing-price: The uniform clearing price.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (execute-batch-auction (uint uint) (response bool uint))
    
    ;; @desc Detect a sandwich attack attempt.
    ;; @param transaction: The transaction to analyze.
    ;; @param mempool-state: The current mempool state.
    ;; @returns (response bool uint): A boolean indicating if an attack was detected, or an error code.
    (detect-sandwich-attack ((buff 1024) (buff 2048)) (response bool uint))
    
    ;; @desc Get a fair ordering for a set of transactions.
    ;; @param transactions: An array of transactions to order.
    ;; @returns (response (list 50 (buff 32)) uint): The fair ordering, or an error code.
    (get-fair-ordering ((list 50 (buff 1024))) (response (list 50 (buff 32)) uint))
    
    ;; @desc Set the MEV protection parameters.
    ;; @param commit-timeout: The timeout for the commit-reveal scheme.
    ;; @param batch-size: The maximum batch size.
    ;; @param protection-level: The protection level (0-3).
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-protection-params (uint uint uint) (response bool uint))
    
    ;; @desc Get the MEV protection statistics.
    ;; @returns (response (tuple ...) uint): A tuple containing the protection statistics, or an error code.
    (get-protection-stats () (response (tuple 
      (commits-submitted uint)
      (reveals-executed uint)
      (batches-processed uint)
      (attacks-prevented uint)
      (total-protected-volume uint)
    ) uint))
    
    ;; @desc Check if a user has active protection.
    ;; @param user: The principal of the user.
    ;; @returns (response bool uint): A boolean indicating if the user has active protection, or an error code.
    (has-active-protection (principal) (response bool uint))
    
    ;; @desc Get the protection history for a user.
    ;; @param user: The principal of the user.
    ;; @param limit: The maximum number of records to return.
    ;; @returns (response (list 20 (tuple ...)) uint): A list of the user's protection history, or an error code.
    (get-user-protection-history (principal uint) (response (list 20 (tuple 
      (timestamp uint)
      (protection-type (string-ascii 20))
      (volume-protected uint)
      (fees-paid uint)
      (success bool)
    )) uint))
  )
)
