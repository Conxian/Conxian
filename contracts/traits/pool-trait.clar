;; ===========================================
;; POOL TRAIT
;; ===========================================
;; Interface for a liquidity pool.
;;
;; This trait defines the core functionality for interacting with a liquidity pool,
;; including adding/removing liquidity, swapping tokens, and querying pool state.
;;
;; Example usage:
;;   (use-trait pool-trait .pool-trait.pool-trait)
(define-trait pool-trait
  (
    ;; Add liquidity to the pool
    ;; @param token-x: principal of the first token
    ;; @param token-y: principal of the second token
    ;; @param amount-x: amount of the first token to add
    ;; @param amount-y: amount of the second token to add
    ;; @param sender: principal of the liquidity provider
    ;; @return (response uint uint): amount of LP tokens minted and error code
    (add-liquidity (principal principal uint uint principal) (response uint uint))

    ;; Remove liquidity from the pool
    ;; @param token-x: principal of the first token
    ;; @param token-y: principal of the second token
    ;; @param lp-token-amount: amount of LP tokens to burn
    ;; @param sender: principal of the liquidity provider
    ;; @return (response (tuple (amount-x uint) (amount-y uint)) uint): amounts of tokens returned and error code
    (remove-liquidity (principal principal uint principal) (response (tuple (amount-x uint) (amount-y uint)) uint))

    ;; Perform a token swap
    ;; @param token-in: principal of the input token
    ;; @param token-out: principal of the output token
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum acceptable output amount
    ;; @param sender: principal of the swapper
    ;; @return (response uint uint): amount of output token received and error code
    (swap-tokens (principal principal uint uint principal) (response uint uint))

    ;; Get the current reserves of the pool
    ;; @return (response (tuple (reserve-x uint) (reserve-y uint)) uint): current reserves and error code
    (get-reserves () (response (tuple (reserve-x uint) (reserve-y uint)) uint))

    ;; Get the total supply of LP tokens
    ;; @return (response uint uint): total supply of LP tokens and error code
    (get-lp-token-supply () (response uint uint))

    ;; Get the amount of token-out for a given amount of token-in
    ;; @param token-in: principal of the input token
    ;; @param token-out: principal of the output token
    ;; @param amount-in: amount of input token
    ;; @return (response uint uint): amount of output token and error code
    (get-amount-out (principal principal uint) (response uint uint))

    ;; Get the amount of token-in for a given amount of token-out
    ;; @param token-in: principal of the input token
    ;; @param token-out: principal of the output token
    ;; @param amount-out: amount of output token
    ;; @return (response uint uint): amount of input token and error code
    (get-amount-in (principal principal uint) (response uint uint))
  )
)
