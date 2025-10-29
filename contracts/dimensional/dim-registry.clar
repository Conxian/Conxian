;; dim-registry.clar
;; Dimensional Registry & Weight Updates - Central Component Registration
;; Registry for ALL system components under dimensional architecture
;; Manages DEX pools, vaults, lending systems, and cross-protocol integrations

(use-trait dim-registry-trait .all-traits.dim-registry-trait)

(impl-trait dim-registry-trait)

;; Constants
(define-constant TRAIT_REGISTRY .trait-registry)
(define-constant ERR_UNAUTHORIZED u101)
(define-constant ERR_INVALID_WEIGHT u102)
(define-constant ERR_DIMENSION_EXISTS u103)
(define-constant ERR_DIMENSION_NOT_FOUND u104)
(define-constant ERR_ORACLE_EXISTS u105)
(define-constant ERR_ORACLE_NOT_FOUND u106)

(define-data-var oracle-principal principal tx-sender)
(define-data-var contract-owner principal tx-sender)

;; Dimension weights registry
(define-map dimension-weights {dim-id: uint} {weight: uint})

;; Oracle registry
(define-map registered-oracles principal bool)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-oracle-principal (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set oracle-principal new-oracle)
    (ok true)))

;; Trait implementation functions
(define-public (register-dimension (id uint) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? dimension-weights {dim-id: id})) (err ERR_DIMENSION_EXISTS))
    (asserts! (> weight u0) (err ERR_INVALID_WEIGHT))
    (map-set dimension-weights {dim-id: id} {weight: weight})
    (ok id)))

(define-public (update-dimension-weight (dim-id uint) (new-weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-principal)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (map-get? dimension-weights {dim-id: dim-id})) (err ERR_DIMENSION_NOT_FOUND))
    (asserts! (> new-weight u0) (err ERR_INVALID_WEIGHT))
    (map-set dimension-weights {dim-id: dim-id} {weight: new-weight})
    (ok true)))

(define-read-only (get-dimension-weight (id uint))
  (ok (default-to u0 (get weight (map-get? dimension-weights {dim-id: id})))))


(define-public (register-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (not (default-to false (map-get? registered-oracles oracle))) (err ERR_ORACLE_EXISTS))
    (map-set registered-oracles oracle true)
    (ok true)))

(define-public (unregister-oracle (oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (default-to false (map-get? registered-oracles oracle)) (err ERR_ORACLE_NOT_FOUND))
    (map-delete registered-oracles oracle)
    (ok true)))

(define-read-only (is-oracle-registered (oracle principal))
  (ok (default-to false (map-get? registered-oracles oracle))))

(define-read-only (get-all-dimensions)
  (ok (list)))
