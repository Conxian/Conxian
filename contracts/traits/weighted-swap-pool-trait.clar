;; ===========================================
;; WEIGHTED SWAP POOL TRAIT
;; ===========================================
;; Interface for weighted swap pools with customizable token weights
;;
;; This trait provides functions for weighted pools where tokens can have
;; different weights, enabling flexible AMM configurations.
;;
;; Example usage:
;;   (use-trait weighted-swap .weighted-swap-pool-trait.weighted-swap-pool-trait)
(define-trait weighted-swap-pool-trait
  (
    ;; Create weighted pool with specified tokens and weights
    ;; @param tokens: array of token principals
    ;; @param weights: array of token weights (must sum to 100%)
    ;; @param swap-fee: trading fee in basis points
    ;; @param pool-owner: pool owner for governance
    ;; @return (response principal uint): pool principal and error code
    (create-pool ((list 10 principal) (list 10 uint) uint principal) (response principal uint))
    
    ;; Add liquidity to weighted pool
    ;; @param amounts: array of token amounts to deposit
    ;; @param min-lp-tokens: minimum LP tokens to receive
    ;; @param recipient: LP token recipient
    ;; @return (response uint uint): LP tokens received and error code
    (add-liquidity ((list 10 uint) uint principal) (response uint uint))
    
    ;; Remove liquidity from weighted pool
    ;; @param lp-tokens: amount of LP tokens to burn
    ;; @param min-amounts-out: minimum amounts of each token to receive
    ;; @param recipient: token recipient
    ;; @return (response (list 10 uint) uint): tokens received and error code
    (remove-liquidity (uint (list 10 uint) principal) (response (list 10 uint) uint))
    
    ;; Swap tokens in weighted pool
    ;; @param token-in: input token principal
    ;; @param token-out: output token principal
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum output amount
    ;; @param recipient: output token recipient
    ;; @return (response uint uint): output amount and error code
    (swap-tokens (principal principal uint uint principal) (response uint uint))
    
    ;; Get spot price for token pair
    ;; @param token-in: input token principal
    ;; @param token-out: output token principal
    ;; @return (response uint uint): spot price and error code
    (get-spot-price (principal principal) (response uint uint))
    
    ;; Get normalized weight for token
    ;; @param token: token principal
    ;; @return (response uint uint): normalized weight and error code
    (get-normalized-weight (principal) (response uint uint))
    
    ;; Get pool tokens and weights
    ;; @return (response (tuple (tokens (list 10 principal)) (weights (list 10 uint))) uint): pool info and error code
    (get-pool-info () (response (tuple (tokens (list 10 principal)) (weights (list 10 uint))) uint))
    
    ;; Get pool balance for token
    ;; @param token: token principal
    ;; @return (response uint uint): balance and error code
    (get-balance (principal) (response uint uint))
    
    ;; Join pool with exact tokens (all assets)
    ;; @param max-amounts-in: maximum amounts of each token to deposit
    ;; @param recipient: LP token recipient
    ;; @return (response uint uint): LP tokens received and error code
    (join-pool-exact-tokens ((list 10 uint) principal) (response uint uint))
    
    ;; Exit pool to exact tokens (all assets)
    ;; @param lp-tokens: amount of LP tokens to burn
    ;; @param min-amounts-out: minimum amounts of each token to receive
    ;; @param recipient: token recipient
    ;; @return (response (list 10 uint) uint): tokens received and error code
    (exit-pool-exact-tokens (uint (list 10 uint) principal) (response (list 10 uint) uint))
    
    ;; Admin function to set swap fee
    ;; @param new-swap-fee: new swap fee in basis points
    ;; @return (response bool uint): success flag and error code
    (set-swap-fee (uint) (response bool uint))
  )
)