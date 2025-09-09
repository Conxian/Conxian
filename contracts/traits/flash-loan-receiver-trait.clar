;; flash-loan-receiver-trait.clar
;; Standard interface for contracts that can receive flash loans
;; Based on ERC-3156 Flash Loan standard adapted for Stacks

(define-trait flash-loan-receiver-trait
  (
    ;; Called by the flash loan provider during a flash loan
    ;; Parameters:
    ;; - initiator: The account that initiated the flash loan
    ;; - token: The token being borrowed
    ;; - amount: The amount borrowed
    ;; - fee: The fee to be paid
    ;; - data: Arbitrary data passed from the initiator
    ;; Returns: A response indicating success/failure
    (on-flash-loan (principal principal uint uint (buff 256)) (response bool uint))
    
    ;; Optional: Get the maximum flash loan amount this receiver can handle
    (get-max-flash-loan (principal) (response uint uint))
    
    ;; Optional: Get the fee this receiver is willing to pay for a flash loan
    (get-flash-loan-fee (principal uint) (response uint uint))
  )
)
