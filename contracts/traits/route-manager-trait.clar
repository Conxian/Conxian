;; @desc A trait for managing routes in the multi-hop router.

(define-trait route-manager-trait
  (
    ;; @desc Propose a new route.
    ;; @param token-in: The input token.
    ;; @param token-out: The output token.
    ;; @param amount-in: The amount of the input token.
    ;; @param min-amount-out: The minimum amount of the output token.
    ;; @param route-timeout: The timeout for the route.
    ;; @returns (response uint uint): The ID of the new route, or an error code.
    (propose-route (principal principal uint uint uint) (response uint uint))

    ;; @desc Execute a route.
    ;; @param route-id: The ID of the route to execute.
    ;; @param min-amount-out: The minimum amount of the output token.
    ;; @param recipient: The recipient of the output tokens.
    ;; @returns (response uint uint): The amount of the output token, or an error code.
    (execute-route (uint uint principal) (response uint uint))

    ;; @desc Get the stats for a route.
    ;; @param route-id: The ID of the route.
    ;; @returns (response { ... } uint): A tuple containing the route stats, or an error code.
    (get-route-stats (uint) (response {hops: uint, estimated-out: uint, expires-at: uint} uint))
  )
)
