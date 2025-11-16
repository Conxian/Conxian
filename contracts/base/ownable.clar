;; @desc Base contract for ownership management.
;; This contract provides a simple implementation of ownership management,
;; allowing the contract owner to transfer ownership to another principal.

(use-trait ownable-trait .base-traits.ownable-trait)

;; @constants
;; @var ERR_NOT_OWNER: The caller is not the owner of the contract.
(define-constant ERR_NOT_OWNER (err u1002))
;; @var ERR_ZERO_ADDRESS: The specified address is the zero address.
(define-constant ERR_ZERO_ADDRESS (err u8006))
;; @var ERR_TRANSFER_PENDING: An ownership transfer is already pending.
(define-constant ERR_TRANSFER_PENDING (err u1006))
;; @var ERR_NO_PENDING_OWNER: There is no pending owner.
(define-constant ERR_NO_PENDING_OWNER (err u1007))
;; @var ERR_NOT_PENDING_OWNER: The caller is not the pending owner.
(define-constant ERR_NOT_PENDING_OWNER (err u1001))

;; @data-vars
;; @var contract-owner: The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var pending-owner: The principal of the pending owner.
(define-data-var pending-owner (optional principal) none)
;; @var rbac-contract: The principal of the RBAC contract.
(define-data-var rbac-contract (optional principal) none)

;; @desc Get the owner of the contract.
;; @returns (response principal uint): The principal of the contract owner.
(define-read-only (get-owner)
  (ok (var-get contract-owner)))

;; @desc Check if a principal is the owner of the contract.
;; @param who: The principal to check.
;; @returns (response bool uint): True if the principal is the owner, false otherwise.
(define-read-only (is-owner (who principal))
  (ok (is-eq who (var-get contract-owner))))

;; @desc Transfer ownership of the contract to a new address.
;; @param new-owner: The address of the new owner.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (var-set pending-owner (some new-owner))
    (ok true)))

;; @desc Accept ownership of the contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (accept-ownership)
  (begin
    (asserts! (is-some (var-get pending-owner)) ERR_NO_PENDING_OWNER)
    (asserts! (is-eq tx-sender (unwrap-panic (var-get pending-owner))) ERR_NOT_PENDING_OWNER)
    (var-set contract-owner tx-sender)
    (var-set pending-owner none)
    (ok true)))
