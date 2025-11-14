;; SPDX-License-Identifier: TBD

;; Lending Pool
;; This contract is the main entry point for users to interact with the lending pool.
(use-trait lending-pool-core-trait .lending-pool-core.lending-pool-core-trait)

(define-data-var lending-pool-core-address principal .lending-pool-core)

;; --- Public Functions ---

;; @desc Deposits an asset into the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to deposit.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (deposit (asset principal) (amount uint))
  (contract-call? (var-get lending-pool-core-address) deposit asset amount tx-sender)
)

;; @desc Withdraws an asset from the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to withdraw.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (withdraw (asset principal) (amount uint))
  (contract-call? (var-get lending-pool-core-address) withdraw asset amount tx-sender)
)

;; @desc Borrows an asset from the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to borrow.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (borrow (asset principal) (amount uint))
  (contract-call? (var-get lending-pool-core-address) borrow asset amount tx-sender)
)

;; @desc Repays a borrowed asset to the lending pool.
;; @param asset principal The contract principal of the asset.
;; @param amount uint The amount to repay.
;; @returns (response bool uint) `(ok true)` on success.
(define-public (repay (asset principal) (amount uint))
  (contract-call? (var-get lending-pool-core-address) repay asset amount tx-sender)
)
