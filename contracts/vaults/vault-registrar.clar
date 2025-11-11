;; vault-registrar.clar
;; This contract is responsible for registering the vault components
;; with the dimensional registry.

(use-trait dim-registry-trait .all-traits.dim-registry-trait)
(use-trait rbac-trait .rbac-trait.rbac-trait)

(define-constant ERR_UNAUTHORIZED (err u101))
(define-constant SBTC_VAULT_WEIGHT u100)



(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) (err ERR_UNAUTHORIZED))
    (ok true)
  )
)

(define-public (register-vault-components (registry <dim-registry-trait>))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) (err ERR_UNAUTHORIZED))
    (try! (contract-call? registry register-component .sbtc-vault SBTC_VAULT_WEIGHT))
    (ok true)
  )
)
