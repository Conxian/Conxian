;; File: contracts/base/ownable.clar
;; Base contract for ownership management

(use-trait ownable-trait .all-traits.ownable-trait)

;; Error codes
(define-constant ERR_NOT_OWNER (err u1001))
(define-constant ERR_ZERO_ADDRESS (err u1002))
(define-constant ERR_TRANSFER_PENDING (err u1005))
(define-constant ERR_NO_PENDING_OWNER (err u1006))
(define-constant ERR_NOT_PENDING_OWNER (err u1007))

;; State
(use-trait rbac-trait .decentralized-trait-registry.decentralized-trait-registry)

(define-data-var pending-owner (optional principal) none)

;; Implementation of ownable-trait
(define-read-only (get-owner)
  (ok (var-get contract-owner)))

(define-read-only (is-owner (who principal))
  (ok (is-eq who (var-get contract-owner))))

;; @desc Transfer ownership of the contract to a new address.
;; @param new-owner (principal) - The address of the new owner.
;; @returns (response bool uint) - Ok(true) if successful, Err(ERR_UNAUTHORIZED) otherwise.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) (err ERR_UNAUTHORIZED))
    (ok (var-set pending-owner (some new-owner)))))

;; @desc Accept ownership of the contract.
;; @returns (response bool uint) - Ok(true) if successful, Err(ERR_UNAUTHORIZED) otherwise.
(define-public (accept-ownership)
  (begin
    (asserts! (is-some (var-get pending-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq tx-sender (unwrap-panic (var-get pending-owner))) (err ERR_UNAUTHORIZED))
    (try! (contract-call? .rbac-contract set-role "contract-owner" tx-sender))
    (ok (var-set pending-owner none))))
