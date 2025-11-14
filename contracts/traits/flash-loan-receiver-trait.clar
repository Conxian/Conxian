;; ===========================================
;; FLASH LOAN RECEIVER TRAIT
;; ===========================================
;; @desc Interface for contracts that can receive flash loans.
;; This trait must be implemented by any contract that wants to receive
;; flash loans from the protocol.
;;
;; @example
;; (use-trait flash-loan-receiver-trait .flash-loan-receiver-trait.flash-loan-receiver-trait)
(define-trait flash-loan-receiver-trait
  (
    ;; @desc Executes operations with borrowed funds.
    ;; @param asset: The token being borrowed.
    ;; @param amount: The amount borrowed.
    ;; @param premium: The fee to be paid.
    ;; @param initiator: The address that initiated the flash loan.
    ;; @returns (response bool uint): True if successful, otherwise an error.
    (execute-operation (asset principal) (amount uint) (premium uint) (initiator principal)) (response bool uint))
  )
)
