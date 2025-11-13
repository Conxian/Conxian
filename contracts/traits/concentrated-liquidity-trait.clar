;; ===========================================
;; CONCENTRATED LIQUIDITY POOL TRAIT
;; ===========================================
;; Interface for concentrated liquidity pools with tick-based pricing
;;
;; This trait provides functions for concentrated liquidity management,
;; position NFT creation, and fee accumulation within price ranges.
;;
;; Example usage:
;;   (use-trait concentrated-liquidity .concentrated-liquidity-trait.concentrated-liquidity-trait)
(define-trait concentrated-liquidity-trait
  (
    ;; Create a new concentrated liquidity position
    ;; @param lower-tick: lower price tick boundary
    ;; @param upper-tick: upper price tick boundary  
    ;; @param amount-0: amount of token 0 to deposit
    ;; @param amount-1: amount of token 1 to deposit
    ;; @param recipient: position NFT recipient
    ;; @return (response uint uint): position ID and error code
    (create-position (int int uint uint principal) (response uint uint))
    
    ;; Collect fees from a position
    ;; @param position-id: position identifier
    ;; @param recipient: fee recipient
    ;; @return (response (tuple (amount-0 uint) (amount-1 uint)) uint): collected fees and error code
    (collect-fees (uint principal) (response (tuple (amount-0 uint) (amount-1 uint)) uint))
    
    ;; Remove liquidity from a position
    ;; @param position-id: position identifier
    ;; @param liquidity: amount of liquidity to remove
    ;; @param recipient: token recipient
    ;; @return (response (tuple (amount-0 uint) (amount-1 uint)) uint): withdrawn amounts and error code
    (remove-liquidity (uint uint principal) (response (tuple (amount-0 uint) (amount-1 uint)) uint))
    
    ;; Get position information
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): position details and error code
    (get-position (uint) (response (tuple 
      (owner principal) 
      (lower-tick int) 
      (upper-tick int) 
      (liquidity uint) 
      (fee-growth-inside-0 uint) 
      (fee-growth-inside-1 uint)
      (tokens-owed-0 uint)
      (tokens-owed-1 uint)
    ) uint))
    
    ;; Get current price tick
    ;; @return (response int uint): current price tick and error code
    (get-current-tick () (response int uint))
    
    ;; Get tick information
    ;; @param tick: tick to query
    ;; @return (response (tuple ...) uint): tick info and error code
    (get-tick (int) (response (tuple 
      (liquidity-gross uint)
      (liquidity-net int)
      (fee-growth-outside-0 uint)
      (fee-growth-outside-1 uint)
    ) uint))
    
    ;; Swap tokens with concentrated liquidity
    ;; @param zero-for-one: true if swapping token0 for token1
    ;; @param amount-specified: amount to swap (positive for exact input, negative for exact output)
    ;; @param sqrt-price-limit-x96: price limit for the swap
    ;; @param recipient: token recipient
    ;; @return (response (tuple ...) uint): swap result and error code
    (swap (bool int uint principal) (response (tuple 
      (amount-0 int)
      (amount-1 int)
      (sqrt-price-x96 uint)
      (liquidity uint)
      (tick int)
    ) uint))
  )
)
