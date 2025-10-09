;; test-flash-loan-receiver.clar
;; Minimal flash-loan receiver that repays amount + fee back to the initiator (vault)

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

(define-public (on-flash-loan (initiator principal) (asset <sip-010-ft-trait>) (amount uint) (fee uint) (data (buff 256)))
  (begin
    ;; Transfer back the amount + fee to the initiator (the vault contract)
    (try! (as-contract (contract-call? asset transfer (+ amount fee) tx-sender initiator none)))
    (ok (tuple (success true)))
  )
)
