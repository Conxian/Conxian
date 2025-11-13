;; lending-registrar.clar
;; This contract is responsible for registering the lending components
;; with the dimensional registry.

(use-trait dim-registry-trait .dimensional.dim-registry-trait)

(define-constant ERR_UNAUTHORIZED (err u101))
(define-constant LENDING_VAULT_WEIGHT u100)
(define-constant ENTERPRISE_MODULE_WEIGHT u100)

(define-data-var contract-owner principal tx-sender)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (register-lending-components (registry <dim-registry-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (try! (contract-call? registry register-component .dimensional-vault LENDING_VAULT_WEIGHT))
    (try! (contract-call? registry register-component .enterprise-module ENTERPRISE_MODULE_WEIGHT))
    (ok true)
  )
)
