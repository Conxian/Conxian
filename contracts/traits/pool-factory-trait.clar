;; ===========================================
;; POOL FACTORY TRAIT
;; ===========================================
;; Interface for creating and managing liquidity pools
;;
;; This trait provides functions to deploy new liquidity pool instances
;; and retrieve information about existing ones.
;;
;; Example usage:
;;   (use-trait pool-factory .pool-factory-trait.pool-factory-trait)
(define-trait pool-factory-trait
  (
    ;; Create a new liquidity pool
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @param pool-type: type of the pool (e.g., constant-product, concentrated-liquidity)
    ;; @return (response principal uint): principal of the new pool and error code
    (create-pool (principal principal (string-ascii 32)) (response principal uint))

    ;; Get pool by token pair and type
    ;; @param token-a: principal of the first token
    ;; @param token-b: principal of the second token
    ;; @param pool-type: type of the pool
    ;; @return (response (optional principal) uint): principal of the pool or none, and error code
    (get-pool-by-pair ((principal principal (string-ascii 32))) (response (optional principal) uint))

    ;; Get all pools created by the factory
    ;; @return (response (list 20 principal) uint): list of pool principals and error code
    (get-all-pools () (response (list 20 principal) uint))
  )
)
