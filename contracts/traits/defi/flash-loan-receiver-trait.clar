(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

(define-trait flash-loan-receiver-trait
  (
    ;; @notice Execute a flash loan
    (execute-flash-loan (token-contract <sip-010-ft-trait>) (amount uint) (initiator principal) (data (optional (buff 256))) (response bool (err uint)))
  )
)
