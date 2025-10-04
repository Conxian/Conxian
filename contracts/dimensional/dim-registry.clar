;; dim-registry.clar
;; Dimensional Registry & Weight Updates
;; Registry for dimensional contracts and their associated metrics
;;
;; This contract is controlled by a contract owner who can designate a whitelisted oracle.

;; --- Traits ---
(use-trait dim-registry-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.dim-registry-trait)
(use-trait ownable-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)


(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.dim-registry-trait)
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.ownable-trait)

;; Constants
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)
(define-constant ERR_UNAUTHORIZED u101)
(define-constant ERR_INVALID_WEIGHT u102)
(define-constant ERR_DIMENSION_EXISTS u103)
(define-constant ERR_DIMENSION_NOT_FOUND u104)

(define-data-var oracle-principal principal tx-sender)
(define-data-var contract-owner principal tx-sender)

(define-map dimension-weights {dim-id: uint} {weight: uint})

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

(define-read-only (get-dimension-weight (id uint))
  (map-get? dimension-weights {dim-id: id}))

;; @desc Registers a new dimension. Only callable by the contract owner.
;; @param id: The ID of the new dimension.
;; @param wt: The initial weight for the dimension.
;; @returns (response uint uint)
(define-public (register-dimension (id uint) (wt uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? dimension-weights {dim-id: id})) (err ERR_DIMENSION_EXISTS))
    (map-set dimension-weights {dim-id: id} {weight: wt})
    (ok id)))

;; @desc Updates the weight of an existing dimension. Only callable by the whitelisted oracle.
;; @param dim-id: The ID of the dimension to update.
;; @param new-wt: The new weight for the dimension.
;; @returns (response uint uint)
(define-public (update-weight (dim-id uint) (new-wt uint))
  (begin
    (asserts! (is-eq tx-sender (var-get oracle-principal)) (err ERR_UNAUTHORIZED))
    (asserts! (is-some (map-get? dimension-weights {dim-id: dim-id})) (err ERR_DIMENSION_NOT_FOUND))
    (map-set dimension-weights {dim-id: dim-id} {weight: new-wt})
    (ok new-wt)))






