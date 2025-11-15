;; ===========================================
;; POOL FACTORY TRAIT
;; ===========================================
;; @desc Interface for creating and managing liquidity pools.
;; This trait provides functions to deploy new liquidity pool instances
;; and retrieve information about existing ones.
;;
;; @example
;; (use-trait pool-factory .pool-factory-trait.pool-factory-trait)
(define-trait pool-factory-trait
  (
    ;; @desc Create a new liquidity pool.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @param pool-type: The type of the pool (e.g., constant-product, concentrated-liquidity).
    ;; @returns (response principal uint): The principal of the newly created pool, or an error code.
    (create-pool (principal principal (string-ascii 32)) (response principal uint))

    ;; @desc Get a pool by its token pair and type.
    ;; @param token-a: The principal of the first token.
    ;; @param token-b: The principal of the second token.
    ;; @param pool-type: The type of the pool.
    ;; @returns (response (optional principal) uint): The principal of the pool, or none if it's not found.
    (get-pool-by-pair ((principal principal (string-ascii 32))) (response (optional principal) uint))

    ;; @desc Get all pools created by the factory.
    ;; @returns (response (list 20 principal) uint): A list of the principals of all created pools, or an error code.
    (get-all-pools () (response (list 20 principal) uint))
  )
)
