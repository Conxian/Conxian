;; lending-manager-trait.clar
;;
;; This trait defines the standard interface for a lending manager contract.
;; It outlines the core functionalities required for managing lending and
;; borrowing operations, which will be implemented by the lending-manager
;; contract and called by the lending facade.

(define-trait lending-manager-trait
  (
    ;; Public Functions
    (supply (asset <sip-010-ft-trait>) (amount uint) (response bool uint))
    (withdraw (asset <sip-010-ft-trait>) (amount uint) (response bool uint))
    (borrow (asset <sip-010-ft-trait>) (amount uint) (response bool uint))
    (repay (asset <sip-010-ft-trait>) (amount uint) (response bool uint))

    ;; Read-Only Functions
    (get-user-borrow-balance (user principal) (asset principal) (response (optional uint) uint))
    (get-user-supply-balance (user principal) (asset principal) (response (optional uint) uint))
  )
)
