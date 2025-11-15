;; ===========================================
;; MULTI-HOP ROUTER V3 TRAIT
;; ===========================================
;; @desc Interface for multi-hop routing across multiple DEX pools.
;; This trait provides functions to compute and execute optimal
;; swap paths across multiple liquidity pools.
;;
;; @example
;; (use-trait router .multi-hop-router-v3-trait.multi-hop-router-v3-trait)
(define-trait multi-hop-router-v3-trait
  (
    ;; @desc Compute the best route for a token swap.
    ;; @param token-in: The input token.
    ;; @param token-out: The output token.
    ;; @param amount-in: The amount of the input token.
    ;; @returns (response (tuple (route-id (buff 32)) (hops uint)) uint): A tuple containing the route data, or an error code.
    (compute-best-route (principal principal uint) (response (tuple (route-id (buff 32)) (hops uint)) uint))
    
    ;; @desc Execute a pre-computed route.
    ;; @param route-id: The route identifier.
    ;; @param recipient: The recipient of the output tokens.
    ;; @returns (response uint uint): The output amount, or an error code.
    (execute-route ((buff 32) principal) (response uint uint))
    
    ;; @desc Get statistics about a route.
    ;; @param route-id: The route identifier.
    ;; @returns (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint): A tuple containing the route statistics, or an error code.
    (get-route-stats ((buff 32)) (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint))
  )
)
