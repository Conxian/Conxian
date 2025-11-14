;; @desc A trait for finding the shortest path between two tokens using Dijkstra's algorithm.

(define-trait dijkstra-pathfinder-trait
  (
    ;; @desc Find the best route between two tokens.
    ;; @param token-in: The input token.
    ;; @param token-out: The output token.
    ;; @param amount-in: The amount of the input token.
    ;; @returns (response { ... } uint): A tuple containing the best route and the amount out, or an error code.
    (compute-best-route (principal principal uint) (response {path: (list 10 {pool: principal, token-in: principal, token-out: principal}), amount-out: uint} uint))
  )
)
