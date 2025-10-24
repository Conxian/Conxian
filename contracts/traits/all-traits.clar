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
    (get-staked-balance (principal) (response uint uint))
    
    ;; Get pending rewards for a user
    ;; @param user: principal to check rewards for
    ;; @return (response uint uint): pending reward amount and error code
    (get-pending-rewards (principal) (response uint uint))
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

    ;; Get TWAP (Time Weighted Average Price)
    ;; @param asset: token address to get TWAP for
    ;; @param interval: time interval for TWAP calculation
    ;; @return (response uint uint): TWAP value and error code
    (get-twap (asset principal) (interval uint) (response uint uint))
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
  )
)

;; ===========================================
;; BOND FACTORY TRAIT
;; ===========================================
;; Interface for creating and managing bond tokens
;;
;; This trait provides functions to create bond tokens with specific terms
;; and manage the bond creation process.
;;
;; Example usage:
;;   (use-trait bond-factory .all-traits.bond-factory-trait)
(define-trait bond-factory-trait
  (
    ;; Create a new bond token
    ;; @param name: bond name
    ;; @param symbol: bond symbol
    ;; @param decimals: number of decimals
    ;; @param total-supply: total supply of bonds
    ;; @param maturity-date: maturity date in blocks
    ;; @param coupon-rate: coupon rate in basis points
    ;; @param face-value: face value per bond
    ;; @return (response principal uint): bond contract address and error code
    (create-bond (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (total-supply uint) (maturity-date uint) (coupon-rate uint) (face-value uint) (response principal uint))
    
    ;; Get bond details by address
    ;; @param bond-address: bond contract address
    ;; @return (response (tuple ...) uint): bond details and error code
    (get-bond-details (bond-address principal) (response (tuple (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (total-supply uint) (maturity-date uint) (coupon-rate uint) (face-value uint)) uint))
    
    ;; List all bonds created by this factory
    ;; @return (response (list 100 principal) uint): list of bond addresses and error code
    (get-all-bonds () (response (list 100 principal) uint))
  )
)

;; ===========================================
;; BOND ISSUANCE TRAIT
;; ===========================================
;; Interface for issuing tokenized bonds
;;
;; This trait provides functions to issue bonds backed by underlying assets
;; and manage the issuance process.
;;
;; Example usage:
;;   (use-trait bond-issuance .all-traits.bond-issuance-trait)
(define-trait bond-issuance-trait
  (
    ;; Issue new bonds backed by collateral
    ;; @param collateral-amount: amount of collateral to back bonds
    ;; @param bond-amount: number of bonds to issue
    ;; @param maturity-blocks: maturity period in blocks
    ;; @param coupon-rate: coupon rate in basis points
    ;; @return (response uint uint): bond ID and error code
    (issue-bonds (collateral-amount uint) (bond-amount uint) (maturity-blocks uint) (coupon-rate uint) (response uint uint))
    
    ;; Redeem bonds at maturity
    ;; @param bond-id: bond identifier
    ;; @param amount: amount of bonds to redeem
    ;; @return (response uint uint): collateral returned and error code
    (redeem-bonds (bond-id uint) (amount uint) (response uint uint))
    
    ;; Claim coupon payments
    ;; @param bond-id: bond identifier
    ;; @return (response uint uint): coupon amount and error code
    (claim-coupon (bond-id uint) (response uint uint))
    
    ;; Get bond information
    ;; @param bond-id: bond identifier
    ;; @return (response (tuple ...) uint): bond details and error code
    (get-bond-info (bond-id uint) (response (tuple (collateral-amount uint) (bond-amount uint) (maturity-blocks uint) (coupon-rate uint) (issued-at uint) (issuer principal)) uint))
  )
)

;; ===========================================
;; CXLP MIGRATION QUEUE TRAIT
;; ===========================================
;; Interface for managing CXLP to CXD token migration queues
;;
;; This trait provides functions to queue migration requests and process
;; them in a fair, duration-weighted manner.
;;
;; Example usage:
;;   (use-trait migration-queue .all-traits.cxlp-migration-queue-trait)
(define-trait cxlp-migration-queue-trait
  (
    ;; Queue a migration request
    ;; @param cxlp-amount: amount of CXLP tokens to migrate
    ;; @return (response uint uint): queue position and error code
    (queue-migration (cxlp-amount uint) (response uint uint))
    
    ;; Cancel a queued migration request
    ;; @param queue-id: queue entry identifier
    ;; @return (response uint uint): refunded amount and error code
    (cancel-migration (queue-id uint) (response uint uint))
    
    ;; Process pending migration requests
    ;; @param max-process: maximum number of requests to process
    ;; @return (response uint uint): number processed and error code
    (process-migrations (max-process uint) (response uint uint))
    
    ;; Get migration queue statistics
    ;; @return (response (tuple ...) uint): queue statistics and error code
    (get-queue-stats () (response (tuple (total-queued uint) (processed uint) (average-wait uint)) uint))
    
    ;; Get user's queued migrations
    ;; @return (response (list 10 uint) uint): list of queue IDs and error code
    (get-user-migrations (user principal) (response (list 10 uint) uint))
  )
)

;; ===========================================
;; ROUTER TRAIT
;; ===========================================
;; Interface for DEX routing functionality
;;
;; This trait provides functions to route token swaps across multiple pools
;; and find optimal execution paths.
;;
;; Example usage:
;;   (use-trait router .all-traits.router-trait)
(define-trait router-trait
  (
    ;; Swap exact tokens for tokens
    ;; @param amount-in: amount of input tokens
    ;; @param amount-out-min: minimum output amount
    ;; @param path: swap path (token addresses)
    ;; @param to: recipient address
    ;; @param deadline: transaction deadline
    ;; @return (response (list uint) uint): amounts and error code
    (swap-exact-tokens-for-tokens (amount-in uint) (amount-out-min uint) (path (list 10 principal)) (to principal) (deadline uint) (response (list uint) uint))
    
    ;; Swap tokens for exact tokens
    ;; @param amount-out: desired output amount
    ;; @param amount-in-max: maximum input amount
    ;; @param path: swap path (token addresses)
    ;; @param to: recipient address
    ;; @param deadline: transaction deadline
    ;; @return (response (list uint) uint): amounts and error code
    (swap-tokens-for-exact-tokens (amount-out uint) (amount-in-max uint) (path (list 10 principal)) (to principal) (deadline uint) (response (list uint) uint))
    
    ;; Get amounts out for a given path
    ;; @param amount-in: input amount
    ;; @param path: swap path
    ;; @return (response (list uint) uint): output amounts and error code
    (get-amounts-out (amount-in uint) (path (list 10 principal)) (response (list uint) uint))
    
    ;; Get amounts in for a desired output
    ;; @param amount-out: desired output amount
    ;; @param path: swap path
    ;; @return (response (list uint) uint): input amounts and error code
    (get-amounts-in (amount-out uint) (path (list 10 principal)) (response (list uint) uint))
    
    ;; Remove liquidity from a pool
    ;; @param token-a: first token
    ;; @param token-b: second token
    ;; @param liquidity: liquidity amount
    ;; @param amount-a-min: minimum amount of token A
    ;; @param amount-b-min: minimum amount of token B
    ;; @param to: recipient address
    ;; @param deadline: transaction deadline
    ;; @return (response (tuple (amount-a uint) (amount-b uint)) uint): removed amounts and error code
    (remove-liquidity (token-a principal) (token-b principal) (liquidity uint) (amount-a-min uint) (amount-b-min uint) (to principal) (deadline uint) (response (tuple (amount-a uint) (amount-b uint)) uint))
  )
)

;; ===========================================
;; YIELD DISTRIBUTION TRAIT
;; ===========================================
;; Interface for yield distribution and optimization
;;
;; This trait provides functions to distribute yields from various sources
;; and optimize yield allocation across different strategies.
;;
;; Example usage:
;;   (use-trait yield-distribution .all-traits.yield-distribution-trait)
(define-trait yield-distribution-trait
  (
    ;; Distribute yields to stakeholders
    ;; @param total-yield: total yield available for distribution
    ;; @return (response uint uint): distributed amount and error code
    (distribute-yields (total-yield uint) (response uint uint))
    
    ;; Calculate optimal yield allocation
    ;; @param available-yield: yield available for allocation
    ;; @param strategies: list of yield strategies
    ;; @return (response (list 10 uint) uint): allocation amounts and error code
    (calculate-optimal-allocation (available-yield uint) (strategies (list 10 principal)) (response (list 10 uint) uint))
    
    ;; Claim yields for a user
    ;; @param user: user principal
    ;; @return (response uint uint): claimed amount and error code
    (claim-yields (user principal) (response uint uint))
    
    ;; Get system constants
    ;; @return (response (tuple ...) uint): system constants and error code
    (get-constants () (response (tuple (max-positions uint) (min-collateral uint) (maintenance-margin uint)) uint))
  )
)

;; ===========================================
;; MEV PROTECTOR TRAIT
;; ===========================================
;; Interface for MEV (Miner Extractable Value) protection
;;
;; This trait provides functions to protect against front-running,
;; sandwich attacks, and other MEV exploits.
;;
;; Example usage:
;;   (use-trait mev-protector .all-traits.mev-protector-trait)
(define-trait mev-protector-trait
  (
    ;; Submit a commitment for a transaction
    ;; @param commitment: hash commitment for the transaction
    ;; @return (response uint uint): commitment ID and error code
    (submit-commitment (commitment (buff 32)) (response uint uint))
    
    ;; Reveal and execute a committed transaction
    ;; @param commitment-id: commitment identifier
    ;; @param transaction-data: actual transaction data
    ;; @return (response bool uint): success flag and error code
    (reveal-and-execute (commitment-id uint) (transaction-data (buff 1024)) (response bool uint))
    
    ;; Check if a commitment is valid
    ;; @param commitment-id: commitment identifier
    ;; @return (response bool uint): validity flag and error code
    (is-commitment-valid (commitment-id uint) (response bool uint))
    
    ;; Get MEV protection statistics
    ;; @return (response (tuple ...) uint): protection statistics and error code
    (get-mev-stats () (response (tuple (total-protected uint) (attacks-prevented uint) (gas-saved uint)) uint))
  )
)

;; ===========================================
;; AUDIT REGISTRY TRAIT
;; ===========================================
;; Interface for audit registry and voting system
;;
;; This trait provides functions to submit audits, vote on them,
;; and manage the audit approval process.
;;
;; Example usage:
;;   (use-trait audit-registry .all-traits.audit-registry-trait)
(define-trait audit-registry-trait
  (
    ;; Submit a new audit
    ;; @param contract-address: address of contract being audited
    ;; @param audit-hash: hash of the audit report
    ;; @param report-uri: URI to the full audit report
    ;; @return (response uint uint): audit ID and error code
    (submit-audit (contract-address principal) (audit-hash (string-ascii 64)) (report-uri (string-utf8 256)) (response uint uint))

    ;; Vote on an audit
    ;; @param audit-id: ID of the audit to vote on
    ;; @param approve: true to approve, false to reject
    ;; @return (response bool uint): success flag and error code
    (vote (audit-id uint) (approve bool) (response bool uint))

    ;; Finalize audit after voting period
    ;; @param audit-id: ID of the audit to finalize
    ;; @return (response bool uint): success flag and error code
    (finalize-audit (audit-id uint) (response bool uint))

    ;; Get audit details
    ;; @param audit-id: ID of the audit
    ;; @return (response (tuple ...) uint): audit details and error code
    (get-audit (audit-id uint) (response (tuple
      (contract-address principal)
      (audit-hash (string-ascii 64))
      (auditor principal)
      (report-uri (string-utf8 256))
      (timestamp uint)
      (status (tuple (status (string-ascii 20)) (reason (optional (string-utf8 500)))))
      (votes (tuple (for uint) (against uint) (voters (list 100 principal))))
      (voting-ends uint)
    ) uint))

    ;; Get audit status
    ;; @param audit-id: ID of the audit
    ;; @return (response (tuple ...) uint): audit status and error code
    (get-audit-status (audit-id uint) (response (tuple
      (status (string-ascii 20))
      (reason (optional (string-utf8 500)))
    ) uint))

    ;; Get audit votes
    ;; @param audit-id: ID of the audit
    ;; @return (response (tuple ...) uint): vote details and error code
    (get-audit-votes (audit-id uint) (response (tuple
      (for uint)
      (against uint)
      (voters (list 100 principal))
    ) uint))

    ;; Admin: Set voting period
    ;; @param blocks: voting period in blocks
    ;; @return (response bool uint): success flag and error code
    (set-voting-period (blocks uint) (response bool uint))

    ;; Admin: Emergency pause an audit
    ;; @param audit-id: ID of the audit to pause
    ;; @param reason: reason for pausing
    ;; @return (response bool uint): success flag and error code
    (emergency-pause-audit (audit-id uint) (reason (string-utf8 500)) (response bool uint))
  )
)

;; ===========================================
;; CIRCUIT BREAKER TRAIT
;; ===========================================
;; Interface for circuit breaker functionality
;;
;; This trait provides functions to trip and reset circuit breakers
;; for individual services or the entire protocol.
;;
;; Example usage:
;;   (use-trait breaker .all-traits.circuit-breaker-trait)
(define-trait circuit-breaker-trait
  (
    ;; Check if the circuit breaker is currently tripped
    ;; @return (response bool uint): true if tripped, false otherwise, and error code
    (is-circuit-open () (response bool uint))
    
    ;; Trip the circuit breaker (admin only)
    ;; @return (response bool uint): success flag and error code
    (trip-circuit () (response bool uint))
    
    ;; Reset the circuit breaker (admin only)
    ;; @return (response bool uint): success flag and error code
    (reset-circuit () (response bool uint))
    
    ;; Get circuit breaker statistics
    ;; @return (response (tuple (trips uint) (last-trip uint) (resets uint)) uint): statistics and error code
    (get-circuit-stats () (response (tuple (trips uint) (last-trip uint) (resets uint)) uint))
  )
)

;; ===========================================
;; OWNABLE TRAIT
;; ===========================================
;; Interface for contracts that can be owned and transferred
;;
;; This trait provides functions to manage contract ownership.
;;
;; Example usage:
;;   (use-trait ownable .all-traits.ownable-trait)
;;   (impl-trait .all-traits.ownable-trait)
(define-trait ownable-trait
  (
    ;; Get the current owner of the contract
    ;; @return (response principal uint): owner principal and error code
    (get-owner () (response principal uint))
    
    ;; Transfer ownership to a new principal
    ;; @param new-owner: new owner principal
    ;; @return (response bool uint): success flag and error code
    (transfer-ownership (new-owner principal) (response bool uint))
  )
)

;; ===========================================
;; PAUSABLE TRAIT
;; ===========================================
;; Interface for contracts that can be paused and unpaused
;;
;; This trait provides functions to pause and resume contract operations.
;;
;; Example usage:
;;   (use-trait pausable .all-traits.pausable-trait)
;;   (impl-trait .all-traits.pausable-trait)
(define-trait pausable-trait
  (
    ;; Check if the contract is currently paused
    ;; @return bool: true if paused, false otherwise
    (is-paused () bool)
    
    ;; Pause contract operations (admin only)
    ;; @return (response bool uint): success flag and error code
    (pause () (response bool uint))
    
    ;; Resume contract operations (admin only)
    ;; @return (response bool uint): success flag and error code
    (unpause () (response bool uint))
  )
)

;; ===========================================
;; MULTI-HOP ROUTER V3 TRAIT
;; ===========================================
;; Interface for multi-hop routing across multiple DEX pools
;;
;; This trait provides functions to compute and execute optimal
;; swap paths across multiple liquidity pools.
;;
;; Example usage:
;;   (use-trait router .all-traits.multi-hop-router-v3-trait)
(define-trait multi-hop-router-v3-trait
  (
    ;; Compute the best route for a token swap
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response (tuple (route-id (buff 32)) (hops uint)) uint): route data and error code
    (compute-best-route (token-in principal) (token-out principal) (amount-in uint) (response (tuple (route-id (buff 32)) (hops uint)) uint))
    
    ;; Execute a pre-computed route
    ;; @param route-id: route identifier
    ;; @param recipient: recipient of output tokens
    ;; @return (response uint uint): output amount and error code
    (execute-route (route-id (buff 32)) (recipient principal) (response uint uint))
    
    ;; Get statistics about a route
    ;; @param route-id: route identifier
    ;; @return (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint): route stats and error code
    (get-route-stats (route-id (buff 32)) (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint))
  )
)

;; ===========================================
;; CLP POOL TRAIT
;; ===========================================
;; Interface for Concentrated Liquidity Pool operations
;;
;; This trait provides functions specific to concentrated liquidity pools
;; with tick-based positioning and NFT management.
;;
;; Example usage:
;;   (use-trait clp-pool .all-traits.clp-pool-trait)
(define-trait clp-pool-trait
  (
    ;; Initialize the pool with token pair and fee
    ;; @param token-a: first token
    ;; @param token-b: second token
    ;; @param fee-rate: fee in basis points
    ;; @param tick: initial tick
    ;; @return (response bool uint): success flag and error code
    (initialize (token-a principal) (token-b principal) (fee-rate uint) (tick int) (response bool uint))
    
    ;; Set the NFT contract for position management
    ;; @param contract-address: NFT contract address
    ;; @return (response bool uint): success flag and error code
    (set-position-nft-contract (contract-address principal) (response bool uint))
    
    ;; Mint a new concentrated liquidity position
    ;; @param recipient: position owner
    ;; @param tick-lower: lower tick bound
    ;; @param tick-upper: upper tick bound
    ;; @param amount: liquidity amount
    ;; @return (response (tuple (position-id uint) (liquidity uint) (amount-x uint) (amount-y uint)) uint): position data and error code
    (mint-position (recipient principal) (tick-lower int) (tick-upper int) (amount uint) (response (tuple (position-id uint) (liquidity uint) (amount-x uint) (amount-y uint)) uint))
    
    ;; Burn a concentrated liquidity position
    ;; @param position-id: position identifier
    ;; @return (response (tuple (fees-x uint) (fees-y uint)) uint): fees earned and error code
    (burn-position (position-id uint) (response (tuple (fees-x uint) (fees-y uint)) uint))
    
    ;; Collect fees from a position
    ;; @param position-id: position identifier
    ;; @param recipient: fee recipient
    ;; @return (response (tuple (amount-x uint) (amount-y uint)) uint): collected amounts and error code
    (collect-position (position-id uint) (recipient principal) (response (tuple (amount-x uint) (amount-y uint)) uint))
  )
)
;; ===========================================
;; Interface for DEX liquidity pools
;;
;; This trait defines the standard interface that all DEX pools must implement
;; to be compatible with the Conxian DEX router and factory.
;;
;; Example usage:
;;   (impl-trait .all-traits.pool-trait)
(define-trait pool-trait
  (
    ;; Get the pool's token pair
    ;; @return (response (tuple (token-x principal) (token-y principal)) uint): token pair and error code
    (get-tokens () (response (tuple (token-x principal) (token-y principal)) uint))
    
    ;; Get the pool's fee tier
    ;; @return (response uint uint): fee in basis points and error code
    (get-fee () (response uint uint))
    
    ;; Get pool liquidity for a token
    ;; @param token: token to check liquidity for
    ;; @return (response uint uint): liquidity amount and error code
    (get-liquidity (token principal) (response uint uint))
    
    ;; Swap tokens in the pool
    ;; @param token-in: input token
    ;; @param token-out: output token  
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum acceptable output amount
    ;; @param recipient: recipient of output tokens
    ;; @return (response uint uint): output amount and error code
    (swap (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (recipient principal) (response uint uint))
    
    ;; Add liquidity to the pool
    ;; @param token-x-amount: amount of token-x to add
    ;; @param token-y-amount: amount of token-y to add
    ;; @param min-token-x-amount: minimum token-x amount (slippage protection)
    ;; @param min-token-y-amount: minimum token-y amount (slippage protection)
    ;; @param recipient: recipient of liquidity tokens/shares
    ;; @return (response (tuple (liquidity uint) (token-x-amount uint) (token-y-amount uint)) uint): liquidity added and error code
    (add-liquidity (token-x-amount uint) (token-y-amount uint) (min-token-x-amount uint) (min-token-y-amount uint) (recipient principal) (response (tuple (liquidity uint) (token-x-amount uint) (token-y-amount uint)) uint))
    
    ;; Remove liquidity from the pool
    ;; @param liquidity: amount of liquidity to remove
    ;; @param min-token-x-amount: minimum token-x amount (slippage protection)
    ;; @param min-token-y-amount: minimum token-y amount (slippage protection)
    ;; @param recipient: recipient of removed tokens
    ;; @return (response (tuple (token-x-amount uint) (token-y-amount uint)) uint): tokens removed and error code
    (remove-liquidity (liquidity uint) (min-token-x-amount uint) (min-token-y-amount uint) (recipient principal) (response (tuple (token-x-amount uint) (token-y-amount uint)) uint))
    
    ;; Get amount out for a given amount in
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response uint uint): expected output amount and error code
    (get-amount-out (token-in principal) (token-out principal) (amount-in uint) (response uint uint))
    
    ;; Get amount in for a desired amount out
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-out: desired amount of output token
    ;; @return (response uint uint): required input amount and error code
    (get-amount-in (token-in principal) (token-out principal) (amount-out uint) (response uint uint))
  )
)
;; ===========================================
;; BTC ADAPTER TRAIT
;; ===========================================
;; Interface for Bitcoin integration functionality
;;
;; This trait provides functions to wrap and unwrap Bitcoin
;; for use within the Stacks ecosystem.
;;
;; Example usage:
;;   (use-trait btc-adapter .all-traits.btc-adapter-trait)
(define-trait btc-adapter-trait
  (
    ;; Wrap Bitcoin into a Stacks token
    ;; @param amount: amount of BTC to wrap
    ;; @param btc-tx-id: Bitcoin transaction ID
    ;; @return (response uint uint): wrapped amount and error code
    (wrap-btc (amount uint) (btc-tx-id (buff 32)) (response uint uint))
    
    ;; Unwrap Stacks token back to Bitcoin
    ;; @param amount: amount to unwrap
    ;; @param btc-address: Bitcoin address to send to
    ;; @return (response bool uint): success flag and error code
    (unwrap-btc (amount uint) (btc-address (buff 64)) (response bool uint))
    
    ;; Get wrapped Bitcoin balance for a user
    ;; @param user: user principal
    ;; @return (response uint uint): wrapped balance and error code
    (get-wrapped-balance (user principal) (response uint uint))
  )
)

;; ===========================================
;; FUNDING TRAIT
;; ===========================================
;; Interface for funding rate calculations and position funding
;;
;; This trait provides functions for perpetual contract funding mechanisms
;; including rate calculation and position funding application.
;;
;; Example usage:
;;   (use-trait funding .all-traits.funding-trait)
;;   (define-public (update-rates (funding-contract principal))
;;     (contract-call? funding-contract update-funding-rate asset))
(define-trait funding-trait
  (
    ;; Update funding rate for an asset
    ;; @param asset: asset to update funding rate for
    ;; @return (response (tuple ...) uint): funding rate data and error code
    (update-funding-rate (asset principal) (response (tuple (funding-rate int) (index-price uint) (timestamp uint) (cumulative-funding int)) uint))

    ;; Apply funding to a position
    ;; @param position-owner: owner of the position
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): funding payment data and error code
    (apply-funding-to-position (position-owner principal) (position-id uint) (response (tuple (funding-rate int) (funding-payment uint) (new-collateral uint) (timestamp uint)) uint))

    ;; Get current funding rate for an asset
    ;; @param asset: asset to get funding rate for
    ;; @return (response (tuple ...) uint): current funding rate data and error code
    (get-current-funding-rate (asset principal) (response (tuple (rate int) (last-updated uint) (next-update uint)) uint))

    ;; Get funding rate history
    ;; @param asset: asset to get history for
    ;; @param from-block: start block
    ;; @param to-block: end block
    ;; @param limit: maximum number of entries
    ;; @return (response (list ...) uint): funding rate history and error code
    (get-funding-rate-history (asset principal) (from-block uint) (to-block uint) (limit uint) (response (list 20 (tuple (rate int) (index-price uint) (open-interest-long uint) (open-interest-short uint) (timestamp uint))) uint))

    ;; Set funding parameters (admin only)
    ;; @param interval: funding interval in blocks
    ;; @param max-rate: maximum funding rate
    ;; @param sensitivity: funding rate sensitivity
    ;; @return (response bool uint): success flag and error code
    (set-funding-parameters (interval uint) (max-rate uint) (sensitivity uint) (response bool uint))
  )
)

;; ===========================================
;; LIQUIDATION TRAIT
;; ===========================================
;; Interface for position liquidation functionality
;;
;; This trait provides functions for liquidating underwater positions,
;; batch liquidations, and position health monitoring.
;;
;; Example usage:
;;   (use-trait liquidation .all-traits.liquidation-trait)
;;   (define-public (liquidate-user-position (liquidation-contract principal) (position-id uint))
;;     (contract-call? liquidation-contract liquidate-position tx-sender position-id max-slippage))
(define-trait liquidation-trait
  (
    ;; Liquidate a single position
    ;; @param position-owner: owner of the position to liquidate
    ;; @param position-id: position identifier
    ;; @param max-slippage: maximum allowed slippage
    ;; @return (response bool uint): success flag and error code
    (liquidate-position (position-owner principal) (position-id uint) (max-slippage uint) (response bool uint))

    ;; Liquidate multiple positions in batch
    ;; @param positions: list of positions to liquidate
    ;; @param max-slippage: maximum allowed slippage
    ;; @return (response (list 20 (response bool uint)) uint): liquidation results and error code
    (liquidate-positions (positions (list 20 (tuple (owner principal) (id uint)))) (max-slippage uint) (response (list 20 (response bool uint)) uint))

    ;; Check position health status
    ;; @param position-owner: owner of the position
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): health metrics and error code
    (check-position-health (position-owner principal) (position-id uint) (response (tuple (margin-ratio uint) (liquidation-price uint) (current-price uint) (health-factor uint) (is-liquidatable bool)) uint))

    ;; Set liquidation reward parameters (admin only)
    ;; @param min-reward: minimum liquidation reward
    ;; @param max-reward: maximum liquidation reward
    ;; @return (response bool uint): success flag and error code
    (set-liquidation-rewards (min-reward uint) (max-reward uint) (response bool uint))

    ;; Set insurance fund address (admin only)
    ;; @param fund: new insurance fund address
    ;; @return (response bool uint): success flag and error code
    (set-insurance-fund (fund principal) (response bool uint))
  )
)

;; ===========================================
;; RISK TRAIT
;; ===========================================
;; Interface for risk management and position analysis
;;
;; This trait provides functions for calculating liquidation prices,
;; margin ratios, and other risk metrics for trading positions.
;;
;; Example usage:
;;   (use-trait risk .all-traits.risk-trait)
;;   (define-public (calculate-risk (risk-contract principal) (position-id uint))
;;     (contract-call? risk-contract get-liquidation-price position price))
(define-trait risk-trait
  (
    ;; Get liquidation price for a position
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @return (response uint uint): liquidation price and error code
    (get-liquidation-price (position (tuple (asset principal) (size int) (collateral uint) (entry-price uint) (maintenance-margin uint))) (current-price uint) (response uint uint))

    ;; Calculate margin ratio for a position
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @return (response uint uint): margin ratio and error code
    (calculate-margin-ratio (position (tuple (asset principal) (size int) (collateral uint) (entry-price uint) (maintenance-margin uint))) (current-price uint) (response uint uint))

    ;; Check if position is at risk of liquidation
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @param maintenance-margin: maintenance margin requirement
    ;; @return (response bool uint): true if at risk, false otherwise, and error code
    (is-position-at-risk (position (tuple (asset principal) (size int) (collateral uint) (entry-price uint))) (current-price uint) (maintenance-margin uint) (response bool uint))

    ;; Calculate PnL for a position
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @return (response int uint): profit/loss amount and error code
    (calculate-pnl (position (tuple (asset principal) (size int) (entry-price uint))) (current-price uint) (response int uint))

    ;; Get risk parameters
    ;; @return (response (tuple ...) uint): current risk parameters and error code
    (get-risk-parameters () (response (tuple (min-collateral-ratio uint) (liquidation-penalty uint) (maintenance-margin uint)) uint))
  )
)

;; ===========================================
;; BATCH AUCTION TRAIT
;; ===========================================
;; Interface for batch auction mechanisms
;;
;; This trait provides functions for batch-based price discovery
;; where multiple orders are collected and executed at a single price.
;;
;; Example usage:
;;   (use-trait batch-auction .all-traits.batch-auction-trait)
(define-trait batch-auction-trait
  (
    ;; Submit a bid to the batch auction
    ;; @param amount: amount of tokens to bid
    ;; @param price: bid price
    ;; @return (response uint uint): bid ID and error code
    (submit-bid (amount uint) (price uint) (response uint uint))

    ;; Cancel a submitted bid
    ;; @param bid-id: bid identifier
    ;; @return (response bool uint): success flag and error code
    (cancel-bid (bid-id uint) (response bool uint))

    ;; Execute the batch auction
    ;; @return (response (tuple (clearing-price uint) (total-volume uint) (orders-filled uint)) uint): auction results and error code
    (execute-auction () (response (tuple (clearing-price uint) (total-volume uint) (orders-filled uint)) uint))

    ;; Get auction status
    ;; @return (response (tuple (status (string-ascii 20)) (start-time uint) (end-time uint) (total-bids uint)) uint): status and error code
    (get-auction-status () (response (tuple (status (string-ascii 20)) (start-time uint) (end-time uint) (total-bids uint)) uint))

    ;; Get clearing price for the current batch
    ;; @return (response uint uint): clearing price and error code
    (get-clearing-price () (response uint uint))
  )
)

;; ===========================================
;; BUDGET MANAGER TRAIT
;; ===========================================
;; Interface for treasury allocation and budget management
;;
;; This trait provides functions for managing protocol treasury
;; allocations and budget proposals within the DAO governance system.
;;
;; Example usage:
;;   (use-trait budget-manager .all-traits.budget-manager-trait)
(define-trait budget-manager-trait
  (
    ;; Create a new budget allocation
    ;; @param name: budget name
    ;; @param description: budget description
    ;; @param amount: allocation amount
    ;; @param duration: budget duration in blocks
    ;; @return (response uint uint): budget ID and error code
    (create-budget (name (string-ascii 64)) (description (string-utf8 256)) (amount uint) (duration uint) (response uint uint))

    ;; Execute a budget allocation
    ;; @param budget-id: budget identifier
    ;; @param recipient: recipient address
    ;; @return (response bool uint): success flag and error code
    (execute-allocation (budget-id uint) (recipient principal) (response bool uint))

    ;; Get budget details
    ;; @param budget-id: budget identifier
    ;; @return (response (tuple ...) uint): budget details and error code
    (get-budget (budget-id uint) (response (tuple (name (string-ascii 64)) (description (string-utf8 256)) (amount uint) (spent uint) (duration uint) (created-at uint) (status (string-ascii 20))) uint))

    ;; Update budget status
    ;; @param budget-id: budget identifier
    ;; @param status: new status
    ;; @return (response bool uint): success flag and error code
    (update-budget-status (budget-id uint) (status (string-ascii 20)) (response bool uint))
  )
)

;; ===========================================
;; KEEPER COORDINATOR TRAIT
;; ===========================================
;; Interface for automated keeper task coordination
;;
;; This trait provides functions for managing automated tasks
;; such as interest accrual, liquidations, and protocol maintenance.
;;
;; Example usage:
;;   (use-trait keeper .all-traits.keeper-coordinator-trait)
(define-trait keeper-coordinator-trait
  (
    ;; Execute automated interest accrual
    ;; @return (response uint uint): amount accrued and error code
    (execute-interest-accrual () (response uint uint))

    ;; Execute automated liquidations
    ;; @return (response uint uint): number of liquidations and error code
    (execute-liquidations () (response uint uint))

    ;; Execute automated rebalancing
    ;; @return (response bool uint): success flag and error code
    (execute-rebalancing () (response bool uint))

    ;; Execute fee distribution
    ;; @return (response uint uint): fees distributed and error code
    (execute-fee-distribution () (response uint uint))

    ;; Get task status
    ;; @param task-id: task identifier
    ;; @return (response (tuple ...) uint): task status and error code
    (get-task-status (task-id uint) (response (tuple (status (string-ascii 20)) (last-executed uint) (next-execution uint) (success-count uint) (failure-count uint)) uint))
  )
)
;; ===========================================
;; Interface for governance proposals
;;
;; This trait provides functions for creating, voting on, and
;; executing governance proposals within the DAO system.
;;
;; Example usage:
;;   (use-trait proposal .all-traits.proposal-trait)
(define-trait proposal-trait
  (
    ;; Create a new proposal
    ;; @param title: proposal title
    ;; @param description: proposal description
    ;; @param actions: list of actions to execute
    ;; @param duration: voting duration in blocks
    ;; @return (response uint uint): proposal ID and error code
    (create-proposal (title (string-ascii 128)) (description (string-utf8 1024)) (actions (list 10 (tuple (contract principal) (function (string-ascii 64)) (parameters (buff 512))))) (duration uint) (response uint uint))

    ;; Vote on a proposal
    ;; @param proposal-id: proposal identifier
    ;; @param vote: vote choice (for/against/abstain)
    ;; @param amount: voting power amount
    ;; @return (response bool uint): success flag and error code
    (vote (proposal-id uint) (vote (string-ascii 10)) (amount uint) (response bool uint))

    ;; Execute a proposal
    ;; @param proposal-id: proposal identifier
    ;; @return (response bool uint): success flag and error code
    (execute-proposal (proposal-id uint) (response bool uint))

    ;; Get proposal status
    ;; @param proposal-id: proposal identifier
    ;; @return (response (tuple ...) uint): proposal status and error code
    (get-proposal-status (proposal-id uint) (response (tuple (title (string-ascii 128)) (description (string-utf8 1024)) (proposer principal) (start-block uint) (end-block uint) (votes-for uint) (votes-against uint) (status (string-ascii 20))) uint))
  )
)
;; ===========================================
;; Interface for dimensional system functionality
;;
;; This trait provides core functions for the dimensional DeFi system
;; including position management, dimensional calculations, and system state.
;;
;; Example usage:
;;   (use-trait dimensional .all-traits.dimensional-trait)
;;   (define-public (get-dimensional-data (dim-contract principal))
;;     (contract-call? dim-contract get-dimensional-state))
(define-trait dimensional-trait
  (
    ;; Get dimensional system state
    ;; @return (response (tuple ...) uint): system state and error code
    (get-dimensional-state () (response (tuple (total-value-locked uint) (active-positions uint) (system-health (string-ascii 20))) uint))

    ;; Get position by owner and ID
    ;; @param owner: position owner
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): position data and error code
    (get-position-by-owner (owner principal) (position-id uint) (response (tuple (asset principal) (size int) (collateral uint) (entry-price uint) (status (string-ascii 20))) uint))

    ;; Update position data
    ;; @param owner: position owner
    ;; @param position-id: position identifier
    ;; @param updates: updated position data
    ;; @return (response bool uint): success flag and error code
    (update-position (owner principal) (position-id uint) (updates (tuple (collateral (optional uint)))) (response bool uint))

    ;; Force close a position (admin/liquidation only)
    ;; @param owner: position owner
    ;; @param position-id: position identifier
    ;; @param price: closing price
    ;; @return (response bool uint): success flag and error code
    (force-close-position (owner principal) (position-id uint) (price uint) (response bool uint))

    ;; Get system constants
    ;; @return (response (tuple ...) uint): system constants and error code
    (get-constants () (response (tuple (max-positions uint) (min-collateral uint) (maintenance-margin uint)) uint))
  )
)

;; ===========================================
;; DIM REGISTRY TRAIT
;; ===========================================
;; Interface for dimensional registry and component management
;;
;; This trait provides functions for managing dimension weights
;; and registering system components under the dimensional architecture.
;;
;; Example usage:
;;   (use-trait dim-registry .all-traits.dim-registry-trait)
(define-trait dim-registry-trait
  (
    ;; Register a new dimension
    ;; @param id: dimension ID
    ;; @param weight: initial weight for the dimension
    ;; @return (response uint uint): dimension ID and error code
    (register-dimension (id uint) (weight uint) (response uint uint))

    ;; Update dimension weight
    ;; @param dim-id: dimension ID to update
    ;; @param new-weight: new weight value
    ;; @return (response uint uint): success flag and error code
    (update-dimension-weight (dim-id uint) (new-weight uint) (response bool uint))

    ;; Get dimension weight
    ;; @param id: dimension ID
    ;; @return (response uint uint): weight value and error code
    (get-dimension-weight (id uint) (response uint uint))

    ;; Register oracle contract
    ;; @param oracle: oracle contract principal
    ;; @return (response bool uint): success flag and error code
    (register-oracle (oracle principal) (response bool uint))

    ;; Unregister oracle contract
    ;; @param oracle: oracle contract principal
    ;; @return (response bool uint): success flag and error code
    (unregister-oracle (oracle principal) (response bool uint))

    ;; Check if oracle is registered
    ;; @param oracle: oracle contract principal
    ;; @return (response bool uint): registration status and error code
    (is-oracle-registered (oracle principal) (response bool uint))

    ;; Get all registered dimensions
    ;; @return (response (list 50 (tuple (id uint) (weight uint))) uint): dimensions list and error code
    (get-all-dimensions () (response (list 50 (tuple (id uint) (weight uint))) uint))
  )
)

;; ===========================================
;; ADVANCED ROUTER DIJKSTRA TRAIT
;; ===========================================
;; Interface for advanced routing using Dijkstra's algorithm
;;
;; This trait provides functions for building dimensional token graphs
;; and finding optimal swap paths across multiple pools.
;;
;; Example usage:
;;   (use-trait advanced-router .all-traits.advanced-router-dijkstra-trait)
(define-trait advanced-router-dijkstra-trait
  (
    ;; Add token node to routing graph
    ;; @param token: token principal to add
    ;; @return (response uint uint): token index and error code
    (add-token-node (token principal) (response uint uint))

    ;; Add edge between tokens (pool connection)
    ;; @param token-from: source token
    ;; @param token-to: destination token
    ;; @param pool: pool contract connecting tokens
    ;; @param fee: swap fee for this pool
    ;; @param liquidity: available liquidity
    ;; @return (response bool uint): success flag and error code
    (add-pool-edge (token-from principal) (token-to principal) (pool principal) (fee uint) (liquidity uint) (response bool uint))

    ;; Find optimal swap path
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: input amount
    ;; @return (response (tuple ...) uint): optimal path data and error code
    (find-optimal-path (token-in principal) (token-out principal) (amount-in uint) (response (tuple (path (list 20 principal)) (output uint) (hops uint) (total-fee uint)) uint))

    ;; Execute swap along optimal path
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: input amount
    ;; @param min-amount-out: minimum acceptable output
    ;; @param recipient: recipient address
    ;; @return (response uint uint): output amount and error code
    (execute-optimal-swap (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint) (recipient principal) (response uint uint))

    ;; Get graph statistics
    ;; @return (response (tuple ...) uint): graph stats and error code
    (get-graph-stats () (response (tuple (nodes uint) (edges uint) (total-liquidity uint)) uint))

    ;; Remove token from graph
    ;; @param token: token to remove
    ;; @return (response bool uint): success flag and error code
    (remove-token-node (token principal) (response bool uint))

    ;; Update edge liquidity
    ;; @param token-from: source token
    ;; @param token-to: destination token
    ;; @param new-liquidity: updated liquidity
    ;; @return (response bool uint): success flag and error code
    (update-edge-liquidity (token-from principal) (token-to principal) (new-liquidity uint) (response bool uint))
  )
)

;; ===========================================
;; POSITION NFT TRAIT
;; ===========================================
;; Interface for NFT position representation in dimensional system
;;
;; This trait provides functions for managing NFT representations
;; of dimensional positions and concentrated liquidity positions.
;;
;; Example usage:
;;   (use-trait position-nft .all-traits.position-nft-trait)
(define-trait position-nft-trait
  (
    ;; Mint position NFT
    ;; @param recipient: NFT recipient
    ;; @param position-data: position information
    ;; @return (response uint uint): token ID and error code
    (mint-position-nft (recipient principal) (position-data (tuple (position-id uint) (pool principal) (lower-tick int) (upper-tick int) (liquidity uint))) (response uint uint))

    ;; Burn position NFT
    ;; @param token-id: NFT token ID
    ;; @param owner: current owner
    ;; @return (response bool uint): success flag and error code
    (burn-position-nft (token-id uint) (owner principal) (response bool uint))

    ;; Transfer position NFT
    ;; @param token-id: NFT token ID
    ;; @param sender: current owner
    ;; @param recipient: new owner
    ;; @return (response bool uint): success flag and error code
    (transfer-position-nft (token-id uint) (sender principal) (recipient principal) (response bool uint))

    ;; Get position data from NFT
    ;; @param token-id: NFT token ID
    ;; @return (response (tuple ...) uint): position data and error code
    (get-position-from-nft (token-id uint) (response (tuple (position-id uint) (pool principal) (lower-tick int) (upper-tick int) (liquidity uint)) uint))

    ;; Set pool contract (admin only)
    ;; @param pool: authorized pool contract
    ;; @return (response bool uint): success flag and error code
    (set-authorized-pool (pool principal) (response bool uint))

    ;; Get NFT metadata URI
    ;; @param token-id: NFT token ID
    ;; @return (response (optional (string-utf8 256)) uint): metadata URI and error code
    (get-nft-metadata (token-id uint) (response (optional (string-utf8 256)) uint))
  )
)

;; ===========================================
;; GOVERNANCE TRAIT
;; ===========================================
;; Interface for governance and parameter management
;;
;; This trait provides functions for managing protocol parameters
;; and governance decisions within the dimensional system.
;;
;; Example usage:
;;   (use-trait governance .all-traits.governance-trait)
(define-trait governance-trait
  (
    ;; Propose a parameter change
    ;; @param parameter: parameter name
    ;; @param value: new value
    ;; @param description: proposal description
    ;; @return (response uint uint): proposal ID and error code
    (propose-parameter-change (parameter (string-ascii 64)) (value uint) (description (string-utf8 256)) (response uint uint))

    ;; Vote on a proposal
    ;; @param proposal-id: proposal identifier
    ;; @param approve: vote choice
    ;; @return (response bool uint): success flag and error code
    (vote-on-proposal (proposal-id uint) (approve bool) (response bool uint))

    ;; Execute a passed proposal
    ;; @param proposal-id: proposal identifier
    ;; @return (response bool uint): success flag and error code
    (execute-proposal (proposal-id uint) (response bool uint))

    ;; Get proposal status
    ;; @param proposal-id: proposal identifier
    ;; @return (response (tuple ...) uint): proposal status and error code
    (get-proposal-status (proposal-id uint) (response (tuple (proposer principal) (parameter (string-ascii 64)) (value uint) (votes-for uint) (votes-against uint) (status (string-ascii 20)) (deadline uint)) uint))

    ;; Set governance parameters
    ;; @param voting-delay: delay before voting starts
    ;; @param voting-period: voting duration
    ;; @return (response bool uint): success flag and error code
    (set-governance-params (voting-delay uint) (voting-period uint) (response bool uint))

    ;; Get current governance parameters
    ;; @return (response (tuple ...) uint): governance parameters and error code
    (get-governance-params () (response (tuple (voting-delay uint) (voting-period uint) (proposal-threshold uint)) uint))
  )
)

;; ===========================================
;; DIMENSIONAL ROUTER TRAIT
;; ===========================================
;; Interface for dimensional-aware routing and swap execution
;;
;; This trait provides functions for routing through the dimensional system,
;; integrating with dimensional positions, risk management, and optimal path finding.
;;
;; Example usage:
;;   (use-trait dimensional-router .all-traits.dimensional-router-trait)
(define-trait dimensional-router-trait
  (
    ;; Add DEX factory to dimensional routing system
    ;; @param factory: DEX factory contract principal
    ;; @return (response bool uint): success flag and error code
    (add-dex-factory (factory principal) (response bool uint))

    ;; Execute swap with dimensional awareness
    ;; @param amount-in: input token amount
    ;; @param amount-out-min: minimum output amount
    ;; @param path: token swap path
    ;; @param to: recipient address
    ;; @param deadline: transaction deadline
    ;; @return (response uint uint): output amount and error code
    (swap-exact-tokens-for-tokens (amount-in uint) (amount-out-min uint) (path (list 10 principal)) (to principal) (deadline uint) (response uint uint))

    ;; Get dimensional routing fees
    ;; @return (response (tuple ...) uint): fee structure and error code
    (get-dimensional-fees () (response (tuple (protocol-fee uint) (routing-fee uint) (dimensional-bonus uint)) uint))

    ;; Check if path is dimensional-optimized
    ;; @param path: token swap path
    ;; @return (response bool uint): optimization status and error code
    (is-dimensional-optimized (path (list 10 principal)) (response bool uint))

    ;; Get dimensional route statistics
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @return (response (tuple ...) uint): route statistics and error code
    (get-route-stats (token-in principal) (token-out principal) (response (tuple (hops uint) (estimated-output uint) (price-impact uint) (dimensional-multiplier uint)) uint))
  )
)