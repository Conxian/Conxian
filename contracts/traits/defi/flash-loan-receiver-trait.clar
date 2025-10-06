(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)


(define-trait flash-loan-receiver-trait
  (
    ;; @notice Execute a flash loan
    (execute-flash-loan (token-contract <sip-010-ft-trait>) (amount uint) (initiator principal) (data (optional (buff 256))) (response bool (err uint)))
  )
)
