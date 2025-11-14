;; ===========================================
;; ADVANCED ROUTER DIJKSTRA TRAIT
;; ===========================================
;; @desc Interface for advanced routing using Dijkstra's algorithm.
;; This trait provides functions for finding optimal paths and calculating
;; prices across multiple liquidity pools using Dijkstra's algorithm.
;;
;; @example
;; (use-trait advanced-router-dijkstra .advanced-router-dijkstra-trait.advanced-router-dijkstra-trait)
(define-trait advanced-router-dijkstra-trait
  (
    ;; @desc Find the optimal path between two tokens.
    ;; @param token-a: The principal of the start token.
    ;; @param token-b: The principal of the end token.
    ;; @param pools: A list of available liquidity pools to route through.
    ;; @returns (response (list 10 principal) uint): The optimal path as a list of token principals, or an error code.
    (find-optimal-path (principal principal (list 10 principal)) (response (list 10 principal) uint))

    ;; @desc Calculate the price for a given path.
    ;; @param path: A list of token principals representing the path.
    ;; @param amount-in: The amount of the first token in the path.
    ;; @returns (response uint uint): The calculated output amount, or an error code.
    (calculate-path-price ((list 10 principal) uint) (response uint uint))

    ;; @desc Execute a swap along a given path.
    ;; @param path: A list of token principals representing the path.
    ;; @param amount-in: The amount of the first token in the path.
    ;; @param min-amount-out: The minimum acceptable output amount.
    ;; @returns (response uint uint): The actual output amount, or an error code.
    (execute-swap-path ((list 10 principal) uint uint) (response uint uint))
  )
)
