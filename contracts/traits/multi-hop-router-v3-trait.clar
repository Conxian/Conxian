;; ===========================================
;; MULTI-HOP ROUTER V3 TRAIT
;; ===========================================
;; Interface for multi-hop routing across multiple DEX pools
;;
;; This trait provides functions to compute and execute optimal
;; swap paths across multiple liquidity pools.
;;
;; Example usage:
;;   (use-trait router .all-traits.multi-hop-router-v3-trait)
(define-trait multi-hop-router-v3-trait
  (
    ;; Compute the best route for a token swap
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response (tuple (route-id (buff 32)) (hops uint)) uint): route data and error code
    (compute-best-route (principal principal uint) (response (tuple (route-id (buff 32)) (hops uint)) uint))
    
    ;; Execute a pre-computed route
    ;; @param route-id: route identifier
    ;; @param recipient: recipient of output tokens
    ;; @return (response uint uint): output amount and error code
    (execute-route ((buff 32) principal) (response uint uint))
    
    ;; Get statistics about a route
    ;; @param route-id: route identifier
    ;; @return (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint): route stats and error code
    (get-route-stats ((buff 32)) (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint))
  )
)
