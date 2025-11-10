;; File: contracts/base/pausable.clar
;; Base contract for pausable functionality

(use-trait pausable-trait .all-traits.pausable-trait)
(use-trait ownable-trait .all-traits.ownable-trait)

;; Error codes
(define-constant ERR_NOT_OWNER (err u1000))
(define-constant ERR_ALREADY_PAUSED (err u1001))
(define-constant ERR_ALREADY_UNPAUSED (err u1002))
(define-constant ERR_PAUSED (err u1003))

;; State variable to track pause status
(define-data-var paused bool false)

;; ===========================================
;; Public functions
;; ===========================================

;; Check if the contract is paused
(define-read-only (is-paused)
  (ok (var-get paused))
)

;; Pause the contract (only callable by owner)
(define-public (pause)
  (begin
    ;; Verify caller is the owner
    (let ((owner (contract-call? .ownable get-owner)))
      (asserts! (is-ok owner) ERR_NOT_OWNER)
      (asserts! (is-eq tx-sender (unwrap-panic owner)) ERR_NOT_OWNER)
    )
    
    ;; Ensure contract is not already paused
    (asserts! (not (var-get paused)) ERR_ALREADY_PAUSED)
    
    ;; Update state
    (var-set paused true)
    (ok true)
  )
)

;; Unpause the contract (only callable by owner)
(define-public (unpause)
  (begin
    ;; Verify caller is the owner
    (let ((owner (contract-call? .ownable get-owner)))
      (asserts! (is-ok owner) ERR_NOT_OWNER)
      (asserts! (is-eq tx-sender (unwrap-panic owner)) ERR_NOT_OWNER)
    )
    
    ;; Ensure contract is currently paused
    (asserts! (var-get paused) ERR_ALREADY_UNPAUSED)
    
    ;; Update state
    (var-set paused false)
    (ok true)
  )
)

;; Helper function for derived contracts
(define-public (check-not-paused)
  (begin
    (asserts! (not (var-get paused)) ERR_ALREADY_PAUSED)
    (ok true)
  )
)

;; Helper function for derived contracts
(define-private (when-not-paused)
  (if (var-get paused)
    (err ERR_PAUSED)
    (ok true)
  )
)

;; Event for state changes
(define-data-var paused-event (buff 1) 0x00) ;; Dummy for event emission
