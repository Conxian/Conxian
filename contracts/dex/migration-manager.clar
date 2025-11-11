

;; migration-manager
;; This contract facilitates the migration of liquidity and positions between different versions of pools or protocols.
;; It ensures a smooth transition for users and maintains data integrity during upgrades.

(use-trait rbac-trait .rbac-trait.rbac-trait)
(use-trait ft-trait .all-traits.ft-trait)
(use-trait lp-token-trait .all-traits.lp-token-trait)


(define-constant ERR_UNAUTHORIZED (err u9300))
(define-constant ERR_MIGRATION_ALREADY_PERFORMED (err u9301))
(define-constant ERR_INVALID_CONTRACT (err u9302))


(define-data-var old-dex-contract principal .dex-v1)
(define-data-var new-dex-contract principal .dex-v2)

(define-map migrated-users principal bool)

(define-public (migrate-liquidity (user principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (default-to false (map-get? migrated-users user))) ERR_MIGRATION_ALREADY_PERFORMED)
    (let ((lp-balance (try! (as-contract (contract-call? (var-get old-dex-contract) get-lp-balance user)))))
      (if (> lp-balance u0)
        (begin
          (try! (as-contract (contract-call? (var-get old-dex-contract) transfer-lp-to-contract user lp-balance)))
          (try! (as-contract (contract-call? (var-get new-dex-contract) mint-lp user lp-balance)))
        )
        (ok true)
      )
    )
    (map-set migrated-users user true)
    (ok true)
  ))

(define-public (set-contracts (old-dex principal) (new-dex principal))
    (begin
     (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) (err ERR_UNAUTHORIZED))
      (var-set old-dex-contract old-dex)
      (var-set new-dex-contract new-dex)
      (ok true)))

(define-read-only (has-migrated (user principal))
  (default-to false (map-get? migrated-users user)))