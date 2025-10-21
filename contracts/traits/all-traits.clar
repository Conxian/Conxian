;; ===========================================
;; CONXIAN PROTOCOL - CENTRALIZED TRAIT DEFINITIONS
;; ===========================================
;;
;; This file is the single source of truth for all trait definitions in the
;; Conxian protocol. All contracts should reference traits from this file
;; to ensure consistency and avoid duplication.
;;
;; VERSION: 3.7.0
;; LAST UPDATED: 2025-10-21
;;
;; USAGE:
;;   (use-trait <trait-name> .all-traits.<trait-name>)
;;   (impl-trait .all-traits.<trait-name>)
;;
;; ERROR CODES: See errors.clar for standardized error codes
;; ===========================================

;; ===========================================
;; CORE PROTOCOL TRAITS
;; ===========================================

;; ===========================================
;; SIP-010 FUNGIBLE TOKEN TRAIT (FT)
;; ===========================================
;; Standard interface for fungible tokens implementing SIP-010
;;
;; Required for all token contracts in the Conxian ecosystem
;;
;; Example usage:
;;   (use-trait ft .all-traits.sip-010-ft-trait)
;;   (define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
;;     (contract-call? .token-contract transfer amount sender recipient memo))
(define-trait sip-010-ft-trait
  (
    ;; Transfer tokens between principals
    ;; @param amount: number of tokens to transfer
    ;; @param sender: token sender (must be tx-sender or approved spender)
    ;; @param recipient: token recipient
    ;; @param memo: optional memo (max 34 bytes)
    ;; @return (response bool uint): success flag and error code
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    
    ;; Get token name
    ;; @return (response string-ascii-32 uint): token name and error code
    (get-name () (response (string-ascii 32) uint))
    
    ;; Get token symbol
    ;; @return (response string-ascii-10 uint): token symbol and error code
    (get-symbol () (response (string-ascii 10) uint))
    
    ;; Get token decimals
    ;; @return (response uint uint): number of decimals and error code
    (get-decimals () (response uint uint))
    
    ;; Get token balance of a principal
    ;; @param owner: principal to check balance for
    ;; @return (response uint uint): token balance and error code
    (get-balance (principal) (response uint uint))
    
    ;; Get total token supply
    ;; @return (response uint uint): total supply and error code
    (get-total-supply () (response uint uint))
    
    ;; Get token metadata URI
    ;; @return (response (optional (string-utf8 256)) uint): URI and error code
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
;; ===========================================
;; SIP-009 NON-FUNGIBLE TOKEN TRAIT (NFT)
;; ===========================================
;; Standard interface for non-fungible tokens implementing SIP-009
;;
;; Required for all NFT contracts in the Conxian ecosystem
;;
;; Example usage:
;;   (use-trait nft .all-traits.sip-009-nft-trait)
;;   (define-public (transfer (token-id uint) (sender principal) (recipient principal))
;;     (contract-call? .nft-contract transfer token-id sender recipient))
(define-trait sip-009-nft-trait
  (
    ;; Transfer an NFT between principals
    ;; @param token-id: unique identifier of the token
    ;; @param sender: current token owner (must be tx-sender or approved)
    ;; @param recipient: new token owner
    ;; @return (response bool uint): success flag and error code
    (transfer (uint principal principal) (response bool uint))
    
    ;; Get the highest token ID that has been minted
    ;; @return (response uint uint): last token ID and error code
    (get-last-token-id () (response uint uint))
    
    ;; Get the metadata URI for a token
    ;; @param token-id: ID of the token
    ;; @return (response (optional (string-utf8 256)) uint): URI and error code
    (get-token-uri (uint) (response (optional (string-utf8 256)) uint))
    
    ;; Get the owner of a token
    ;; @param token-id: ID of the token
    ;; @return (response (optional principal) uint): owner principal and error code
    (get-owner (uint) (response (optional principal) uint))
  )
)
;; ===========================================
;; FUNGIBLE TOKEN MINTABLE TRAIT
;; ===========================================
;; Extension trait for fungible tokens that can be minted and burned
;;
;; This trait should be implemented alongside sip-010-ft-trait for tokens
;; that require the ability to create and destroy tokens programmatically.
;;
;; Example usage:
;;   (use-trait mintable .all-traits.ft-mintable-trait)
;;   (define-public (mint-tokens (recipient principal) (amount uint))
;;     (contract-call? .token-contract mint recipient amount))
(define-trait ft-mintable-trait
  (
    ;; Mint new tokens and assign them to a principal
    ;; @param recipient: principal to receive the minted tokens
    ;; @param amount: number of tokens to mint
    ;; @return (response bool uint): success flag and error code
    (mint (principal uint) (response bool uint))
    
    ;; Burn tokens from a principal's balance
    ;; @param owner: principal whose tokens will be burned
    ;; @param amount: number of tokens to burn
    ;; @return (response bool uint): success flag and error code
    (burn (principal uint) (response bool uint))
  )
)
;; ===========================================
;; PROTOCOL MONITOR TRAIT
;; ===========================================
;; Interface for monitoring and controlling protocol state
;;
;; This trait provides functions to monitor protocol health, check invariants,
;; and handle emergency situations like pausing the protocol.
;;
;; Example usage:
;;   (use-trait monitor .all-traits.protocol-monitor-trait)
;;   (define-public (check-protocol-health (monitor-contract principal))
;;     (contract-call? monitor-contract check-invariants))
(define-trait protocol-monitor-trait
  (
    ;; Check if the protocol is currently paused
    ;; @return (response bool uint): true if paused, false otherwise, and error code
    (is-paused () (response bool uint))
    
    ;; Verify all protocol invariants are satisfied
    ;; @return (response bool uint): true if all invariants hold, false otherwise, and error code
    (check-invariants () (response bool uint))
    
    ;; Pause all non-essential protocol functions (emergency only)
    ;; Only callable by governance or emergency multisig
    ;; @return (response bool uint): success flag and error code
    (emergency-pause () (response bool uint))
    
    ;; Resume normal protocol operations after a pause
    ;; Only callable by governance or emergency multisig
    ;; @return (response bool uint): success flag and error code
    (resume-normal-ops () (response bool uint))
  )
)
;; ===========================================
;; STAKING TRAIT
;; ===========================================
;; Interface for staking tokens and earning rewards
;;
;; This trait provides functions for users to stake tokens, unstake them,
;; and claim accumulated rewards.
;;
;; Example usage:
;;   (use-trait staking .all-traits.staking-trait)
;;   (define-public (stake-tokens (staking-contract principal) (amount uint))
;;     (contract-call? staking-contract stake amount))
(define-trait staking-trait
  (
    ;; Stake tokens into the contract
    ;; @param amount: number of tokens to stake
    ;; @return (response bool uint): success flag and error code
    (stake (amount uint) (response bool uint))
    
    ;; Unstake tokens from the contract
    ;; @param amount: number of tokens to unstake
    ;; @return (response bool uint): success flag and error code
    (unstake (amount uint) (response bool uint))
    
    ;; Claim accumulated staking rewards
    ;; @return (response uint uint): amount of rewards claimed and error code
    (claim-rewards () (response uint uint))
    
    ;; Get the staked balance for a user
    ;; @param user: principal to check balance for
    ;; @return (response uint uint): staked amount and error code
    (get-staked-balance (user principal) (response uint uint))
    
    ;; Get pending rewards for a user
    ;; @param user: principal to check rewards for
    ;; @return (response uint uint): pending reward amount and error code
    (get-pending-rewards (user principal) (response uint uint))
  )
)

;; ===========================================
;; ACCESS CONTROL TRAIT
;; ===========================================
;; Interface for role-based access control
;;
;; This trait provides functions to manage roles and permissions within the protocol.
;;
;; Example usage:
;;   (use-trait access-control .all-traits.access-control-trait)
;;   (define-public (grant-admin (ac-contract principal) (new-admin principal))
;;     (contract-call? ac-contract grant-role "admin" new-admin))
(define-trait access-control-trait
  (
    ;; Check if an account has a specific role
    ;; @param role: role identifier
    ;; @param account: principal to check
    ;; @return (response bool uint): true if account has role, false otherwise, and error code
    (has-role (role (string-ascii 32)) (account principal) (response bool uint))
    
    ;; Grant a role to an account
    ;; @param role: role identifier
    ;; @param account: principal to grant role to
    ;; @return (response bool uint): success flag and error code
    (grant-role (role (string-ascii 32)) (account principal) (response bool uint))
    
    ;; Revoke a role from an account
    ;; @param role: role identifier
    ;; @param account: principal to revoke role from
    ;; @return (response bool uint): success flag and error code
    (revoke-role (role (string-ascii 32)) (account principal) (response bool uint))
  )
)

;; ===========================================
;; FLASH LOAN RECEIVER TRAIT
;; ===========================================
;; Interface for contracts that can receive flash loans
;;
;; This trait must be implemented by any contract that wants to receive
;; flash loans from the protocol.
;;
;; Example usage:
;;   (impl-trait .all-traits.flash-loan-receiver-trait)
(define-trait flash-loan-receiver-trait
  (
    ;; Execute operations with borrowed funds
    ;; @param asset: token being borrowed
    ;; @param amount: amount borrowed
    ;; @param premium: fee to be paid
    ;; @param initiator: address that initiated the flash loan
    ;; @param params: arbitrary data for custom logic
    ;; @return (response bool uint): success flag and error code
    (execute-operation (asset principal) (amount uint) (premium uint) (initiator principal) (params (buff 256)) (response bool uint))
  )
)

;; ===========================================
;; DIMENSIONAL ORACLE TRAIT
;; ===========================================
;; Interface for price oracle functionality
;;
;; This trait provides functions to get and update asset prices.
;;
;; Example usage:
;;   (use-trait oracle .all-traits.dimensional-oracle-trait)
;;   (define-public (get-asset-price (oracle-contract principal) (asset principal))
;;     (contract-call? oracle-contract get-price asset))
(define-trait dimensional-oracle-trait
  (
    ;; Get the current price of an asset
    ;; @param asset: token address to get price for
    ;; @return (response uint uint): price and error code
    (get-price (asset principal) (response uint uint))
    
    ;; Update the price of an asset (admin only)
    ;; @param asset: token address to update price for
    ;; @param price: new price value
    ;; @return (response bool uint): success flag and error code
    (update-price (asset principal) (price uint) (response bool uint))
    
    ;; Get price with timestamp information
    ;; @param asset: token address to get price for
    ;; @return (response (tuple (price uint) (timestamp uint)) uint): price data and error code
    (get-price-with-timestamp (asset principal) (response (tuple (price uint) (timestamp uint)) uint))
  )
)

;; ===========================================
;; DIM REGISTRY TRAIT
;; ===========================================
;; Interface for managing oracle registrations
;;
;; This trait provides functions to register and manage oracle contracts.
;;
;; Example usage:
;;   (use-trait registry .all-traits.dim-registry-trait)
(define-trait dim-registry-trait
  (
    ;; Register a new oracle contract
    ;; @param oracle: principal of oracle contract to register
    ;; @return (response bool uint): success flag and error code
    (register-oracle (oracle principal) (response bool uint))
    
    ;; Unregister an existing oracle contract
    ;; @param oracle: principal of oracle contract to unregister
    ;; @return (response bool uint): success flag and error code
    (unregister-oracle (oracle principal) (response bool uint))
    
    ;; Check if an oracle is registered
    ;; @param oracle: principal to check
    ;; @return (response bool uint): true if registered, false otherwise, and error code
    (is-registered (oracle principal) (response bool uint))
  )
)

;; ===========================================
;; UTILS TRAIT
;; ===========================================
;; Interface for utility functions
;;
;; This trait provides conversion functions between different data types.
;;
;; Example usage:
;;   (use-trait utils .all-traits.utils-trait)
(define-trait utils-trait
  (
    ;; Convert principal to buffer
    ;; @param p: principal to convert
    ;; @return (response (buff 32) uint): buffer representation and error code
    (principal-to-buff (p principal) (response (buff 32) uint))
    
    ;; Convert buffer to principal
    ;; @param b: buffer to convert
    ;; @return (response principal uint): principal and error code
    (buff-to-principal (b (buff 128)) (response principal uint))
    
    ;; Convert string to unsigned integer
    ;; @param s: string to convert
    ;; @return (response uint uint): integer value and error code
    (string-to-uint (s (string-ascii 32)) (response uint uint))
    
    ;; Convert unsigned integer to string
    ;; @param n: integer to convert
    ;; @return (response (string-ascii 32) uint): string representation and error code
    (uint-to-string (n uint) (response (string-ascii 32) uint))
  )
)

;; ===========================================
;; ADVANCED ROUTER (DIJKSTRA) TRAIT
;; ===========================================
;; Interface for optimal path routing using Dijkstra's algorithm
;;
;; This trait provides functions to build a token graph and find optimal
;; swap paths across multiple pools.
;;
;; Example usage:
;;   (use-trait router .all-traits.advanced-router-dijkstra-trait)
(define-trait advanced-router-dijkstra-trait
  (
    ;; Add a token node to the routing graph
    ;; @param token: token principal to add
    ;; @return (response uint uint): token index and error code
    (add-token (token principal) (response uint uint))
    
    ;; Add an edge (pool connection) between two tokens
    ;; @param token-from: source token
    ;; @param token-to: destination token
    ;; @param pool: pool contract connecting the tokens
    ;; @param pool-type: type of pool (e.g., "constant-product")
    ;; @param liquidity: available liquidity in the pool
    ;; @param fee: swap fee for this pool
    ;; @return (response bool uint): success flag and error code
    (add-edge (token-from principal) (token-to principal) (pool principal) (pool-type (string-ascii 20)) (liquidity uint) (fee uint) (response bool uint))
    
    ;; Find the optimal swap path between two tokens
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint): optimal path data and error code
    (find-optimal-path (token-in principal) (token-out principal) (amount-in uint) (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint))
    
    ;; Execute a swap along the optimal path
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum acceptable output amount
    ;; @return (response (tuple (amount-out uint) (path (list 20 principal)) (hops uint) (distance uint)) uint): swap result and error code
    (swap-optimal-path (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (response (tuple (amount-out uint) (path (list 20 principal)) (hops uint) (distance uint)) uint))
    
    ;; Get statistics about the routing graph
    ;; @return (response (tuple (nodes uint) (edges uint)) uint): graph statistics and error code
    (get-graph-stats () (response (tuple (nodes uint) (edges uint)) uint))
    
    ;; Get the index of a token in the graph
    ;; @param token: token principal to look up
    ;; @return (response (optional uint) uint): token index and error code
    (get-token-index (token principal) (response (optional uint) uint))
    
    ;; Get information about an edge between two tokens
    ;; @param from-token: source token
    ;; @param to-token: destination token
    ;; @return (response (optional (tuple ...)) uint): edge information and error code
    (get-edge-info (from-token principal) (to-token principal) (response (optional (tuple (pool principal) (pool-type (string-ascii 20)) (weight uint) (liquidity uint) (fee uint) (active bool))) uint))
    
    ;; Estimate output amount for a swap
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint): estimated output and error code
    (estimate-output (token-in principal) (token-out principal) (amount-in uint) (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint))
  )
)

;; ===========================================
;; SIGNED DATA BASE TRAIT
;; ===========================================
;; Interface for EIP-712 style structured data signing
;;
;; This trait provides functions for signature verification with domain separation.
;;
;; Example usage:
;;   (use-trait signed-data .all-traits.signed-data-base-trait)
(define-trait signed-data-base-trait
  (
    ;; Get the domain separator for this contract
    ;; @return (response (buff 32) uint): domain separator and error code
    (get-domain-separator () (response (buff 32) uint))
    
    ;; Get the structured data version
    ;; @return (response (string-ascii 16) uint): version string and error code
    (get-structured-data-version () (response (string-ascii 16) uint))
    
    ;; Verify a signature for a message
    ;; @param message: message that was signed
    ;; @param signature: signature to verify
    ;; @param signer: expected signer principal
    ;; @return (response bool uint): true if valid, false otherwise, and error code
    (verify-signature (message (buff 1024)) (signature (buff 65)) (signer principal) (response bool uint))
    
    ;; Verify a signature for structured data
    ;; @param structured-data: structured data that was signed
    ;; @param signature: signature to verify
    ;; @param signer: expected signer principal
    ;; @return (response bool uint): true if valid, false otherwise, and error code
    (verify-structured-data (structured-data (buff 1024)) (signature (buff 65)) (signer principal) (response bool uint))
    
    ;; Initialize or update the domain separator
    ;; @param new-separator: new domain separator value
    ;; @return (response bool uint): success flag and error code
    (initialize-domain-separator (new-separator (buff 32)) (response bool uint))
  )
)

;; ===========================================
;; BOND TRAIT
;; ===========================================
;; Interface for fixed-income bond instruments
;;
;; This trait provides functions to issue bonds, claim coupon payments,
;; and redeem bonds at maturity.
;;
;; Example usage:
;;   (use-trait bond .all-traits.bond-trait)
(define-trait bond-trait
  (
    ;; Issue a new bond
    ;; @param name: bond name
    ;; @param symbol: bond symbol
    ;; @param decimals: number of decimals
    ;; @param initial-supply: initial supply of bonds
    ;; @param maturity-in-blocks: blocks until maturity
    ;; @param coupon-rate-scaled: coupon rate (scaled by 10^6)
    ;; @param frequency-in-blocks: blocks between coupon payments
    ;; @param payment-token-address: token used for payments
    ;; @return (response bool uint): success flag and error code
    (issue-bond (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (initial-supply uint) (maturity-in-blocks uint) (coupon-rate-scaled uint) (frequency-in-blocks uint) (payment-token-address principal) (response bool uint))
    
    ;; Claim a coupon payment
    ;; @return (response uint uint): amount claimed and error code
    (claim-coupon () (response uint uint))
    
    ;; Redeem bond at maturity
    ;; @param payment-token: token to receive payment in
    ;; @return (response uint uint): amount redeemed and error code
    (redeem-at-maturity (payment-token principal) (response uint uint))
    
    ;; Get details about a bond
    ;; @param bond-id: ID of the bond
    ;; @return (response (tuple ...) uint): bond details and error code
    (get-bond-details (bond-id uint) (response (tuple (issuer principal) (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (total-supply uint) (maturity-block uint) (coupon-rate uint) (payment-token principal) (is-mature bool)) uint))
  )
)

;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
;; Interface for circuit breaker pattern
;;
;; This trait provides functions to trip and reset circuit breakers
;; for individual services or the entire protocol.
;;
;; Example usage:
;;   (use-trait breaker .all-traits.circuit-breaker-trait)
