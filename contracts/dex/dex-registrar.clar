;; dex-registrar.clar
;; This contract is responsible for registering the DEX components
;; with the dimensional registry.

(use-trait dim-registry-trait .traits.dim-registry-trait.dim-registry-trait)

(define-constant ERR_UNAUTHORIZED (err u101))
(define-constant DEX_ROUTER_WEIGHT u100)
(define-constant DEX_FACTORY_WEIGHT u100)

(define-data-var contract-owner principal tx-sender)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (register-dex-components (registry <dim-registry-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (try! (contract-call? registry register-component .multi-hop-router-v3 DEX_ROUTER_WEIGHT))
    (try! (contract-call? registry register-component .dex-factory-v2 DEX_FACTORY_WEIGHT))
    (ok true)
  )
)