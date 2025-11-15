;; ===========================================
;; WEIGHTED SWAP POOL TRAIT
;; ===========================================
;; @desc Interface for weighted swap pools with customizable token weights.
;; This trait provides functions for weighted pools where tokens can have
;; different weights, enabling flexible AMM configurations.
;;
;; @example
;; (use-trait weighted-swap .weighted-swap-pool-trait.weighted-swap-pool-trait)
(define-trait weighted-swap-pool-trait
  (
    ;; @desc Create a weighted pool with specified tokens and weights.
    ;; @param tokens: A list of the token principals.
    ;; @param weights: A list of the token weights (must sum to 100%).
    ;; @param swap-fee: The trading fee in basis points.
    ;; @param pool-owner: The owner of the pool for governance purposes.
    ;; @returns (response principal uint): The principal of the newly created pool, or an error code.
    (create-pool ((list 10 principal) (list 10 uint) uint principal) (response principal uint))
    
    ;; @desc Add liquidity to the weighted pool.
    ;; @param amounts: A list of the token amounts to deposit.
    ;; @param min-lp-tokens: The minimum number of LP tokens to receive.
    ;; @param recipient: The recipient of the LP tokens.
    ;; @returns (response uint uint): The number of LP tokens received, or an error code.
    (add-liquidity ((list 10 uint) uint principal) (response uint uint))
    
    ;; @desc Remove liquidity from the weighted pool.
    ;; @param lp-tokens: The amount of LP tokens to burn.
    ;; @param min-amounts-out: The minimum amounts of each token to receive.
    ;; @param recipient: The recipient of the tokens.
    ;; @returns (response (list 10 uint) uint): A list of the tokens received, or an error code.
    (remove-liquidity (uint (list 10 uint) principal) (response (list 10 uint) uint))
    
    ;; @desc Swap tokens in the weighted pool.
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @param amount-in: The amount of the input token.
    ;; @param min-amount-out: The minimum acceptable output amount.
    ;; @param recipient: The recipient of the output token.
    ;; @returns (response uint uint): The output amount, or an error code.
    (swap-tokens (principal principal uint uint principal) (response uint uint))
    
    ;; @desc Get the spot price for a token pair.
    ;; @param token-in: The principal of the input token.
    ;; @param token-out: The principal of the output token.
    ;; @returns (response uint uint): The spot price, or an error code.
    (get-spot-price (principal principal) (response uint uint))
    
    ;; @desc Get the normalized weight for a token.
    ;; @param token: The principal of the token.
    ;; @returns (response uint uint): The normalized weight, or an error code.
    (get-normalized-weight (principal) (response uint uint))
    
    ;; @desc Get the pool's tokens and weights.
    ;; @returns (response (tuple (tokens (list 10 principal)) (weights (list 10 uint))) uint): A tuple containing the pool information, or an error code.
    (get-pool-info () (response (tuple (tokens (list 10 principal)) (weights (list 10 uint))) uint))
    
    ;; @desc Get the pool's balance for a token.
    ;; @param token: The principal of the token.
    ;; @returns (response uint uint): The balance, or an error code.
    (get-balance (principal) (response uint uint))
    
    ;; @desc Join the pool with exact tokens (all assets).
    ;; @param max-amounts-in: The maximum amounts of each token to deposit.
    ;; @param recipient: The recipient of the LP tokens.
    ;; @returns (response uint uint): The number of LP tokens received, or an error code.
    (join-pool-exact-tokens ((list 10 uint) principal) (response uint uint))
    
    ;; @desc Exit the pool to exact tokens (all assets).
    ;; @param lp-tokens: The amount of LP tokens to burn.
    ;; @param min-amounts-out: The minimum amounts of each token to receive.
    ;; @param recipient: The recipient of the tokens.
    ;; @returns (response (list 10 uint) uint): A list of the tokens received, or an error code.
    (exit-pool-exact-tokens (uint (list 10 uint) principal) (response (list 10 uint) uint))
    
    ;; @desc Admin function to set the swap fee.
    ;; @param new-swap-fee: The new swap fee in basis points.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    - (set-swap-fee (uint) (response bool uint))
  )
)
