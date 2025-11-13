;; ===========================================
;; MEV PROTECTOR TRAIT
;; ===========================================
;; Interface for MEV (Maximum Extractable Value) protection mechanisms
;;
;; This trait provides functions for protecting users from MEV attacks
;; including front-running, sandwich attacks, and fair ordering.
;;
;; Example usage:
;;   (use-trait mev-protector .mev-protector-trait.mev-protector-trait)
(define-trait mev-protector-trait
  (
    ;; Submit commit-reveal transaction
    ;; @param commit-hash: hash of transaction details
    ;; @param encrypted-payload: encrypted transaction data
    ;; @return (response uint uint): commit ID and error code
    (submit-commit ((buff 32) (buff 1024)) (response uint uint))
    
    ;; Reveal and execute committed transaction
    ;; @param commit-id: commit identifier
    ;; @param reveal-data: revealed transaction details
    ;; @param signature: user signature
    ;; @return (response bool uint): success flag and error code
    (reveal-and-execute (uint (buff 512) (buff 65)) (response bool uint))
    
    ;; Submit batch auction order
    ;; @param orders: array of orders to batch
    ;; @param batch-deadline: deadline for batch execution
    ;; @return (response uint uint): batch ID and error code
    (submit-batch-auction ((list 50 (tuple (user principal) (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))) uint) (response uint uint))
    
    ;; Execute batch auction
    ;; @param batch-id: batch identifier
    ;; @param clearing-price: uniform clearing price
    ;; @return (response bool uint): success flag and error code
    (execute-batch-auction (uint uint) (response bool uint))
    
    ;; Detect sandwich attack attempt
    ;; @param transaction: transaction to analyze
    ;; @param mempool-state: current mempool state
    ;; @return (response bool uint): attack detected flag and error code
    (detect-sandwich-attack ((buff 1024) (buff 2048)) (response bool uint))
    
    ;; Get fair ordering for transactions
    ;; @param transactions: array of transactions to order
    ;; @return (response (list 50 (buff 32)) uint): fair ordering and error code
    (get-fair-ordering ((list 50 (buff 1024))) (response (list 50 (buff 32)) uint))
    
    ;; Set MEV protection parameters
    ;; @param commit-timeout: timeout for commit-reveal
    ;; @param batch-size: maximum batch size
    ;; @param protection-level: protection level (0-3)
    ;; @return (response bool uint): success flag and error code
    (set-protection-params (uint uint uint) (response bool uint))
    
    ;; Get MEV protection statistics
    ;; @return (response (tuple ...) uint): protection stats and error code
    (get-protection-stats () (response (tuple 
      (commits-submitted uint)
      (reveals-executed uint)
      (batches-processed uint)
      (attacks-prevented uint)
      (total-protected-volume uint)
    ) uint))
    
    ;; Check if user has active protection
    ;; @param user: user principal
    ;; @return (response bool uint): protection active flag and error code
    (has-active-protection (principal) (response bool uint))
    
    ;; Get user protection history
    ;; @param user: user principal
    ;; @param limit: maximum number of records
    ;; @return (response (list 20 (tuple ...)) uint): protection history and error code
    (get-user-protection-history (principal uint) (response (list 20 (tuple 
      (timestamp uint)
      (protection-type (string-ascii 20))
      (volume-protected uint)
      (fees-paid uint)
      (success bool)
    )) uint))
  )
)
