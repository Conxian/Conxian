;; dim-oracle-automation.clar
;; Dimensional Oracle Automation
;; Responsibilities:
;; - Fetch oracle data from off-chain sources
;; - Adjust dimension weights on-chain by calling the dim-registry contract
;;
;; This contract implements the dimensional-oracle-trait and is designed
;; to be called by a whitelisted keeper principal.

(impl-trait 'dimensional-oracle-trait.dimensional-oracle-trait)

(define-constant ERR_UNAUTHORIZED u101)

(define-data-var contract-owner principal tx-sender)
(define-data-var keeper-principal principal tx-sender)
(define-data-var dim-registry-contract principal 'ST000000000000000000002AMW42H.dim-registry) ;; placeholder, should be set at deployment

;; --- Owner Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (set-keeper-principal (new-keeper principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set keeper-principal new-keeper)
    (ok true)))

(define-public (set-dim-registry-contract (registry-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set dim-registry-contract registry-address)
    (ok true)))

;; --- Private Functions ---

(define-private (update-weight-iter (update {dim-id: uint, new-wt: uint}) (prev-result (response bool uint)))
  (begin
    (try! prev-result)
    (match (contract-call? .dim-registry update-weight (get dim-id update) (get new-wt update))
      success-val (ok true)
      error-val (err error-val)
    )
  )
)

;; --- Public Functions (implements trait) ---

(define-public (update-weights (updates (list 10 {dim-id: uint, new-wt: uint})))
  (begin
    (asserts! (is-eq tx-sender (var-get keeper-principal)) (err ERR_UNAUTHORIZED))
    (try! (fold update-weight-iter updates (ok true)))
    (ok true)
  )
)



