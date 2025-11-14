;; ===========================================
;; STABLE SWAP POOL TRAIT
;; ===========================================
;; @desc Interface for stable swap pools optimized for like-valued assets.
;; This trait provides functions for stable swap pools with low slippage
;; and amplified liquidity for assets of similar value (e.g., stablecoins).
;;
;; @example
;; (use-trait stable-swap .stable-swap-pool-trait.stable-swap-pool-trait)
(define-trait stable-swap-pool-trait
  (
    ;; @desc Add liquidity to the stable swap pool.
    ;; @param amounts: A list of token amounts to deposit.
    ;; @param min-mint-amount: The minimum number of LP tokens to mint.
    ;; @param recipient: The recipient of the LP tokens.
    ;; @returns (response uint uint): The number of LP tokens minted, or an error code.
    (add-liquidity ((list 10 uint) uint principal) (response uint uint))
    
    ;; @desc Remove liquidity from the stable swap pool.
    ;; @param lp-token-amount: The amount of LP tokens to burn.
    ;; @param min-amounts: The minimum amounts of each token to receive.
    ;; @param recipient: The recipient of the tokens.
    ;; @returns (response (list 10 uint) uint): A list of the tokens received, or an error code.
    (remove-liquidity (uint (list 10 uint) principal) (response (list 10 uint) uint))
    
    ;; @desc Perform a stable swap.
    ;; @param token-index-from: The index of the input token.
    ;; @param token-index-to: The index of the output token.
    ;; @param amount-in: The amount of the input token.
    ;; @param min-amount-out: The minimum acceptable output amount.
    ;; @param recipient: The recipient of the output token.
    ;; @returns (response uint uint): The output amount, or an error code.
    (swap-tokens (uint uint uint uint principal) (response uint uint))
    
    ;; @desc Calculate the swap output for a stable swap.
    ;; @param token-index-from: The index of the input token.
    ;; @param token-index-to: The index of the output token.
    ;; @param amount-in: The amount of the input token.
    ;; @returns (response uint uint): The output amount, or an error code.
    (get-amount-out (uint uint uint) (response uint uint))
    
    ;; @desc Get the pool's amplification parameter.
    ;; @returns (response uint uint): The amplification parameter, or an error code.
    (get-amplification () (response uint uint))
    
    ;; @desc Get the pool's token balances.
    ;; @returns (response (list 10 uint) uint): A list of the token balances, or an error code.
    (get-balances () (response (list 10 uint) uint))
    
    ;; @desc Get the virtual price of the LP token.
    ;; @returns (response uint uint): The virtual price, or an error code.
    (get-virtual-price () (response uint uint))
    
    ;; @desc Calculate the token amount for an exact number of LP tokens.
    ;; @param lp-token-amount: The amount of LP tokens.
    ;; @param token-index: The index of the token to calculate for.
    ;; @returns (response uint uint): The token amount, or an error code.
    (calculate-token-amount (uint uint) (response uint uint))
    
    ;; @desc Admin function to set the amplification parameter.
    ;; @param new-amplification: The new amplification parameter.
    ;; @param future-time: The time when the change takes effect.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-amplification (uint uint) (response bool uint))
  )
)
