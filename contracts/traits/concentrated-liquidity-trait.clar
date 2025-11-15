;; ===========================================
;; CONCENTRATED LIQUIDITY POOL TRAIT
;; ===========================================
;; @desc Interface for concentrated liquidity pools with tick-based pricing.
;; This trait provides functions for concentrated liquidity management,
;; position NFT creation, and fee accumulation within price ranges.
;;
;; @example
;; (use-trait concentrated-liquidity .concentrated-liquidity-trait.concentrated-liquidity-trait)
(define-trait concentrated-liquidity-trait
  (
    ;; @desc Create a new concentrated liquidity position.
    ;; @param lower-tick: The lower price tick boundary.
    ;; @param upper-tick: The upper price tick boundary.
    ;; @param amount-0: The amount of token 0 to deposit.
    ;; @param amount-1: The amount of token 1 to deposit.
    ;; @param recipient: The recipient of the position NFT.
    ;; @returns (response uint uint): The ID of the newly created position, or an error code.
    (create-position (int int uint uint principal) (response uint uint))
    
    ;; @desc Collect fees from a position.
    ;; @param position-id: The identifier of the position.
    ;; @param recipient: The recipient of the collected fees.
    ;; @returns (response (tuple (amount-0 uint) (amount-1 uint)) uint): A tuple containing the collected fees, or an error code.
    (collect-fees (uint principal) (response (tuple (amount-0 uint) (amount-1 uint)) uint))
    
    ;; @desc Remove liquidity from a position.
    ;; @param position-id: The identifier of the position.
    ;; @param liquidity: The amount of liquidity to remove.
    ;; @param recipient: The recipient of the withdrawn tokens.
    ;; @returns (response (tuple (amount-0 uint) (amount-1 uint)) uint): A tuple containing the withdrawn amounts, or an error code.
    (remove-liquidity (uint uint principal) (response (tuple (amount-0 uint) (amount-1 uint)) uint))
    
    ;; @desc Get information about a specific position.
    ;; @param position-id: The identifier of the position.
    ;; @returns (response (tuple ...) uint): A tuple containing the position details, or an error code.
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
    
    ;; @desc Get the current price tick of the pool.
    ;; @returns (response int uint): The current price tick, or an error code.
    (get-current-tick () (response int uint))
    
    ;; @desc Get information about a specific tick.
    ;; @param tick: The tick to query.
    ;; @returns (response (tuple ...) uint): A tuple containing the tick information, or an error code.
    (get-tick (int) (response (tuple 
      (liquidity-gross uint)
      (liquidity-net int)
      (fee-growth-outside-0 uint)
      (fee-growth-outside-1 uint)
    ) uint))
    
    ;; @desc Swap tokens with concentrated liquidity.
    ;; @param zero-for-one: True if swapping token0 for token1, false otherwise.
    ;; @param amount-specified: The amount to swap (positive for exact input, negative for exact output).
    ;; @param sqrt-price-limit-x96: The price limit for the swap.
    ;; @param recipient: The recipient of the swapped tokens.
    ;; @returns (response (tuple ...) uint): A tuple containing the swap result, or an error code.
    (swap (bool int uint principal) (response (tuple 
      (amount-0 int)
      (amount-1 int)
      (sqrt-price-x96 uint)
      (liquidity uint)
      (tick int)
    ) uint))
  )
)
