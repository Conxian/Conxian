;; ===========================================
;; STABLE SWAP POOL TRAIT
;; ===========================================
;; Interface for stable swap pools optimized for like-valued assets
;;
;; This trait provides functions for stable swap pools with low slippage
;; and amplified liquidity for assets of similar value (e.g., stablecoins).
;;
;; Example usage:
;;   (use-trait stable-swap .stable-swap-pool-trait.stable-swap-pool-trait)
(define-trait stable-swap-pool-trait
  (
    ;; Add liquidity to stable swap pool
    ;; @param amounts: array of token amounts to deposit
    ;; @param min-mint-amount: minimum LP tokens to mint
    ;; @param recipient: LP token recipient
    ;; @return (response uint uint): LP tokens minted and error code
    (add-liquidity ((list 10 uint) uint principal) (response uint uint))
    
    ;; Remove liquidity from stable swap pool
    ;; @param lp-token-amount: amount of LP tokens to burn
    ;; @param min-amounts: minimum amounts of each token to receive
    ;; @param recipient: token recipient
    ;; @return (response (list 10 uint) uint): tokens received and error code
    (remove-liquidity (uint (list 10 uint) principal) (response (list 10 uint) uint))
    
    ;; Perform stable swap
    ;; @param token-index-from: index of input token
    ;; @param token-index-to: index of output token
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum acceptable output
    ;; @param recipient: output token recipient
    ;; @return (response uint uint): output amount and error code
    (swap-tokens (uint uint uint uint principal) (response uint uint))
    
    ;; Calculate swap output for stable swap
    ;; @param token-index-from: index of input token
    ;; @param token-index-to: index of output token
    ;; @param amount-in: amount of input token
    ;; @return (response uint uint): output amount and error code
    (get-amount-out (uint uint uint) (response uint uint))
    
    ;; Get pool amplification parameter
    ;; @return (response uint uint): amplification parameter and error code
    (get-amplification () (response uint uint))
    
    ;; Get pool token balances
    ;; @return (response (list 10 uint) uint): token balances and error code
    (get-balances () (response (list 10 uint) uint))
    
    ;; Get virtual price of LP token
    ;; @return (response uint uint): virtual price and error code
    (get-virtual-price () (response uint uint))
    
    ;; Calculate token amount for exact LP tokens
    ;; @param lp-token-amount: amount of LP tokens
    ;; @param token-index: index of token to calculate for
    ;; @return (response uint uint): token amount and error code
    (calculate-token-amount (uint uint) (response uint uint))
    
    ;; Admin function to set amplification parameter
    ;; @param new-amplification: new amplification parameter
    ;; @param future-time: time when change takes effect
    ;; @return (response bool uint): success flag and error code
    (set-amplification (uint uint) (response bool uint))
  )
)