;; pool-trait.clar
;; Defines the interface for all pool contracts.

(define-trait pool-trait
  (
    ;; @desc Calculates the amount of token-in required for a given amount of token-out.
    ;; @param token-in principal The principal of the input token.
    ;; @param token-out principal The principal of the output token.
    ;; @param amount-out uint The desired amount of output token.
    ;; @returns (response uint uint) The amount of token-in required, or an error.
    (get-amount-in (token-in principal) (token-out principal) (amount-out uint)) => (response uint uint)

    ;; @desc Calculates the amount of token-out received for a given amount of token-in.
    ;; @param token-in principal The principal of the input token.
    ;; @param token-out principal The principal of the output token.
    ;; @param amount-in uint The amount of input token provided.
    ;; @returns (response uint uint) The amount of token-out received, or an error.
    (get-amount-out (token-in principal) (token-out principal) (amount-in uint)) => (response uint uint)

    ;; @desc Returns the fee in basis points for the pool.
    ;; @returns (response uint uint) The fee in basis points, or an error.
    (get-fee-bps) => (response uint uint)

    ;; @desc Returns the principals of the two tokens in the pool.
    ;; @returns (response { token-a: principal, token-b: principal } uint) The token principals, or an error.
    (get-tokens) => (response { token-a: principal, token-b: principal } uint)
  )
)
