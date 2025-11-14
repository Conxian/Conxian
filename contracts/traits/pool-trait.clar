;; ===========================================
;; POOL TRAIT
;; ===========================================
;; @desc Interface for a liquidity pool.
;; This trait defines the core functionality for interacting with a liquidity pool,
;; including adding/removing liquidity, swapping tokens, and querying pool state.
;;
;; @example
;; (use-trait pool-trait .pool-trait.pool-trait)
(define-trait pool-trait
  (
    ;; @desc Add liquidity to the pool.
    ;; @param token-x: The principal of the first token.
    ;; @param token-y: The principal of the second token.
    ;; @param amount-x: The amount of the first token to add.
    ;; @param amount-y: The amount of the second token to add.
    ;; @param sender: The principal of the liquidity provider.
    ;; @returns (response uint uint): The amount of LP tokens minted, or an error code.
    (add-liquidity (principal principal uint uint principal) (response uint uint))

    ;; @desc Remove liquidity from the pool.
    ;; @param token-x: The principal of the first token.
    ;; @param token-y: The principal of the second token.
    ;; @param lp-token-amount: The amount of LP tokens to burn.
    ;; @param sender: The principal of the liquidity provider.
    ;; @returns (response (tuple (amount-x uint) (amount-y uint)) uint): A tuple containing the amounts of tokens returned, or an error code.
    (remove-liquidity (principal principal uint principal) (response (tuple (amount-x uint) (amount-y uint)) uint))

    ;; @desc Perform a token swap.
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @param amount-in: The amount of the input token.
    ;; @param min-amount-out: The minimum acceptable output amount.
    ;; @param sender: The principal of the swapper.
    ;; @returns (response uint uint): The amount of the output token received, or an error code.
    (swap-tokens (principal principal uint uint principal) (response uint uint))

    ;; @desc Get the current reserves of the pool.
    ;; @returns (response (tuple (reserve-x uint) (reserve-y uint)) uint): A tuple containing the current reserves, or an error code.
    (get-reserves () (response (tuple (reserve-x uint) (reserve-y uint)) uint))

    ;; @desc Get the total supply of LP tokens.
    ;; @returns (response uint uint): The total supply of LP tokens, or an error code.
    (get-lp-token-supply () (response uint uint))

    ;; @desc Get the amount of token-out for a given amount of token-in.
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @param amount-in: The amount of the input token.
    ;; @returns (response uint uint): The amount of the output token, or an error code.
    (get-amount-out (principal principal uint) (response uint uint))

    ;; @desc Get the amount of token-in for a given amount of token-out.
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @param amount-out: The amount of the output token.
    ;; @returns (response uint uint): The amount of the input token, or an error code.
    (get-amount-in (principal principal uint) (response uint uint))
  )
)
