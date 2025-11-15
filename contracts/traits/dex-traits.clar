;; ===========================================
;; DEX TRAITS MODULE
;; ===========================================
;; @desc Decentralized exchange specific traits.
;; Optimized for high-frequency trading operations.

;; ===========================================
;; SIP-010 FT TRAIT
;; ===========================================
;; @desc Standard interface for fungible tokens (SIP-010).
(define-trait sip-010-ft-trait
  (
    ;; @desc Transfers tokens from the caller's account to a recipient.
    ;; @param amount: The amount of tokens to transfer.
    ;; @param sender: The principal of the sender.
    ;; @param recipient: The principal of the recipient.
    ;; @param memo: An optional memo to include with the transfer.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; @desc Transfers tokens from a sender's account to a recipient, with the caller acting as an intermediary.
    ;; @param amount: The amount of tokens to transfer.
    ;; @param sender: The principal of the sender.
    ;; @param recipient: The principal of the recipient.
    ;; @param spender: The principal of the spender (the caller).
    ;; @param memo: An optional memo to include with the transfer.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (transfer-from (uint principal principal principal (optional (buff 34))) (response bool uint))

    ;; @desc Gets the balance of a principal.
    ;; @param owner: The principal of the owner.
    ;; @returns (response uint uint): The balance of the owner, or an error code.
    (get-balance (principal) (response uint uint))

    ;; @desc Gets the total supply of the token.
    ;; @returns (response uint uint): The total supply of the token, or an error code.
    (get-total-supply () (response uint uint))

    ;; @desc Gets the name of the token.
    ;; @returns (response (string-ascii 32) uint): The name of the token, or an error code.
    (get-name () (response (string-ascii 32) uint))

    ;; @desc Gets the symbol of the token.
    ;; @returns (response (string-ascii 32) uint): The symbol of the token, or an error code.
    (get-symbol () (response (string-ascii 32) uint))

    ;; @desc Gets the number of decimals for the token.
    ;; @returns (response uint uint): The number of decimals for the token, or an error code.
    (get-decimals () (response uint uint))

    ;; @desc Gets the token's URI.
    ;; @returns (response (optional (string-utf8 256)) uint): The token's URI, or none.
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; ===========================================
;; POOL TRAIT
;; ===========================================
;; @desc Interface for a liquidity pool.
(define-trait pool-trait
  (
    ;; @desc Swaps tokens.
    ;; @param token-in: The principal of the token to swap from.
    ;; @param token-out: The principal of the token to swap to.
    ;; @param amount-in: The amount of token-in to swap.
    ;; @param min-amount-out: The minimum amount of token-out to receive.
    ;; @returns (response uint uint): The amount of token-out received, or an error code.
    (swap (principal principal uint uint) (response uint uint))

    ;; @desc Adds liquidity to the pool.
    ;; @param amount0: The amount of the first token to add.
    ;; @param amount1: The amount of the second token to add.
    ;; @param min-lp-tokens: The minimum amount of LP tokens to receive.
    ;; @param deadline: The deadline for the transaction.
    ;; @returns (response uint uint): The amount of LP tokens received, or an error code.
    (add-liquidity (uint uint uint uint) (response uint uint))

    ;; @desc Removes liquidity from the pool.
    ;; @param lp-tokens: The amount of LP tokens to burn.
    ;; @returns (response { amount0: uint, amount1: uint } uint): A tuple containing the amounts of tokens removed, or an error code.
    (remove-liquidity (uint) (response { amount0: uint, amount1: uint } uint))

    ;; @desc Gets the current reserves of the pool.
    ;; @returns (response { reserve0: uint, reserve1: uint } uint): A tuple containing the reserves of the two tokens, or an error code.
    (get-reserves () (response { reserve0: uint, reserve1: uint } uint))

    ;; @desc Gets information about the pool.
    ;; @returns (response { token0: principal, token1: principal, fee: uint, total-liquidity: uint } uint): A tuple containing the pool information, or an error code.
    (get-pool-info () (response {
      token0: principal,
      token1: principal,
      fee: uint,
      total-liquidity: uint
    } uint))
  )
)

;; ===========================================
;; FACTORY TRAIT
;; ===========================================
;; @desc Interface for a pool factory.
(define-trait factory-trait
  (
    ;; @desc Creates a new pool.
    ;; @param token0: The principal of the first token.
    ;; @param token1: The principal of the second token.
    ;; @param fee: The fee for the pool.
    ;; @returns (response principal uint): The principal of the newly created pool, or an error code.
    (create-pool (principal principal uint) (response principal uint))

    ;; @desc Gets the pool for a given pair of tokens.
    ;; @param token0: The principal of the first token.
    ;; @param token1: The principal of the second token.
    ;; @returns (response (optional principal) uint): The principal of the pool, or none if it doesn't exist.
    (get-pool (principal principal) (response (optional principal) uint))

    ;; @desc Gets all pools created by the factory.
    ;; @returns (response (list 100 principal) uint): A list of the principals of all created pools, or an error code.
    (get-all-pools () (response (list 100 principal) uint))
  )
)

;; ===========================================
;; FINANCE METRICS TRAIT
;; ===========================================
;; @desc Interface for financial metrics.
(define-trait finance-metrics-trait
  (
    ;; @desc Gets the total value locked (TVL).
    ;; @returns (response uint uint): The total value locked, or an error code.
    (get-tvl () (response uint uint))

    ;; @desc Gets the volume for a given time period.
    ;; @param period: The time period to get the volume for.
    ;; @returns (response uint uint): The volume for the given time period, or an error code.
    (get-volume ((string-ascii 32)) (response uint uint))

    ;; @desc Gets the fees collected.
    ;; @returns (response uint uint): The fees collected, or an error code.
    (get-fees-collected () (response uint uint))

    ;; @desc Gets the utilization rate.
    ;; @returns (response uint uint): The utilization rate, or an error code.
    (get-utilization-rate () (response uint uint))
  )
)
