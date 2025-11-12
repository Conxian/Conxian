;; ===========================================
;; DEX TRAIT
;; ===========================================
;; Interface for a decentralized exchange (DEX).
;;
;; This trait defines the core functionality for a DEX, including
;; liquidity provision, swapping, and fee management.
;;
;; Example usage:
;;   (use-trait dex-trait .dex-trait.dex-trait)
(define-trait dex-trait
  (
    ;; @desc Adds liquidity to a pool.
    ;; @param token-x The principal of the first token.
    ;; @param token-y The principal of the second token.
    ;; @param amount-x The amount of token-x to add.
    ;; @param amount-y The amount of token-y to add.
    ;; @returns (response { lp-tokens: uint, tokens-x: uint, tokens-y: uint } uint) The amounts of LP tokens, token-x, and token-y added, or an error.
    (add-liquidity (token-x principal) (token-y principal) (amount-x uint) (amount-y uint)) (response { lp-tokens: uint, tokens-x: uint, tokens-y: uint } uint))

    ;; @desc Removes liquidity from a pool.
    ;; @param token-x The principal of the first token.
    ;; @param token-y The principal of the second token.
    ;; @param lp-tokens The amount of LP tokens to burn.
    ;; @returns (response { tokens-x: uint, tokens-y: uint } uint) The amounts of token-x and token-y removed, or an error.
    (remove-liquidity (token-x principal) (token-y principal) (lp-tokens uint)) (response { tokens-x: uint, tokens-y: uint } uint))

    ;; @desc Swaps tokens.
    ;; @param token-in The principal of the token to swap from.
    ;; @param token-out The principal of the token to swap to.
    ;; @param amount-in The amount of token-in to swap.
    ;; @param min-amount-out The minimum amount of token-out to receive.
    ;; @returns (response { amount-out: uint } uint) The amount of token-out received, or an error.
    (swap-exact-in (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint)) (response { amount-out: uint } uint))

    ;; @desc Swaps tokens for a fixed amount out.
    ;; @param token-in The principal of the token to swap from.
    ;; @param token-out The principal of the token to swap to.
    ;; @param max-amount-in The maximum amount of token-in to spend.
    ;; @param amount-out The exact amount of token-out to receive.
    ;; @returns (response { amount-in: uint } uint) The amount of token-in spent, or an error.
    (swap-exact-out (token-in principal) (token-out principal) (max-amount-in uint) (amount-out uint)) (response { amount-in: uint } uint))

    ;; @desc Gets the amount of token-out for a given amount-in.
    ;; @param token-in The principal of the token to swap from.
    ;; @param token-out The principal of the token to swap to.
    ;; @param amount-in The amount of token-in.
    ;; @returns (response { amount-out: uint } uint) The amount of token-out, or an error.
    (get-amount-out (token-in principal) (token-out principal) (amount-in uint)) (response { amount-out: uint } uint))

    ;; @desc Gets the amount of token-in for a given amount-out.
    ;; @param token-in The principal of the token to swap from.
    ;; @param token-out The principal of the token to swap to.
    ;; @param amount-out The amount of token-out.
    ;; @returns (response { amount-in: uint } uint) The amount of token-in, or an error.
    (get-amount-in (token-in principal) (token-out principal) (amount-out uint)) (response { amount-in: uint } uint))

    ;; @desc Gets the current reserves of a pool.
    ;; @param token-x The principal of the first token.
    ;; @param token-y The principal of the second token.
    ;; @returns (response { reserve-x: uint, reserve-y: uint } uint) The reserves of token-x and token-y, or an error.
    (get-reserves (token-x principal) (token-y principal)) (response { reserve-x: uint, reserve-y: uint } uint))

    ;; @desc Gets the total supply of LP tokens for a pool.
    ;; @param token-x The principal of the first token.
    ;; @param token-y The principal of the second token.
    ;; @returns (response uint uint) The total supply of LP tokens, or an error.
    (get-lp-token-supply (token-x principal) (token-y principal)) (response uint uint))
  )
)
