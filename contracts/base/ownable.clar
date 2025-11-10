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
(define-data-var contract-owner principal tx-sender)
(define-data-var pending-owner (optional principal) none)

;; Implementation of ownable-trait
(define-read-only (get-owner)
  (ok (var-get contract-owner)))

(define-read-only (is-owner (who principal))
  (ok (is-eq who (var-get contract-owner))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_OWNER)
    (asserts! (is-eq (is-none (var-get pending-owner)) true) ERR_TRANSFER_PENDING)
    (var-set pending-owner (some new-owner))
    (ok true)))

(define-public (claim-ownership)
  (let ((pending (unwrap! (var-get pending-owner) ERR_NO_PENDING_OWNER)))
    (asserts! (is-eq tx-sender pending) ERR_NOT_PENDING_OWNER)
    (var-set contract-owner pending)
    (var-set pending-owner none)
    (ok true)))
