;; loan-liquidation-manager.clar
;; Securely manages the liquidation of undercollateralized loans.
;; Refactored for clarity and to work with the overhauled lending system.

;; --- Traits ---
(use-trait ft-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.traits.sip-010-trait)
(use-trait lending-system-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.traits.lending-system-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u2001))
(define-constant ERR_LENDING_SYSTEM_NOT_SET (err u2002))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var lending-system-contract (optional principal) none)

;; --- Private Functions ---
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED))
)

;; --- Admin Functions ---

;; Sets the address of the main lending system contract.
(define-public (set-lending-system-contract (lending-system principal))
  (begin
    (try! (check-is-owner))
    (var-set lending-system-contract (some lending-system))
    (ok true)
  )
)

;; Allows the contract owner to transfer ownership to a new principal.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Public Functions ---

;; The primary public function that allows anyone to liquidate an unhealthy position.
(define-public (liquidate (borrower principal) (repay-asset <ft-trait>) (collateral-asset <ft-trait>) (repay-amount uint))
  (let ((lending-system (unwrap! (var-get lending-system-contract) ERR_LENDING_SYSTEM_NOT_SET))
        (liquidator tx-sender))

    ;; This contract acts as a permissionless entry point.
    ;; It calls the secure `liquidate` function on the main lending contract,
    ;; which is responsible for all security checks and state changes.
    (contract-call? lending-system liquidate liquidator borrower repay-asset collateral-asset repay-amount)
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-lending-system-contract)
  (var-get lending-system-contract)
)

(define-read-only (get-owner)
  (ok (var-get contract-owner))
)