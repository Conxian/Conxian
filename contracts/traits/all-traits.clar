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
;;   (use-trait flash_loan_receiver_trait .all-traits.flash-loan-receiver-trait)
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
(define-trait staking-trait
  (
    ;; Stake tokens into the contract
    ;; @param amount: number of tokens to stake
    ;; @return (response bool uint): success flag and error code
    (stake (uint) (response bool uint))
    
    ;; Unstake tokens from the contract
    ;; @param amount: number of tokens to unstake
    ;; @return (response bool uint): success flag and error code
    (unstake (uint) (response bool uint))
    
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

(define-trait access-control-trait
  (
    ;; Check if an account has a specific role
    ;; @param role: role identifier
    ;; @param account: principal to check
    ;; @return (response bool uint): true if account has role, false otherwise, and error code
    (has-role ((string-ascii 32) principal) (response bool uint))
    
    ;; Grant a role to an account
    ;; @param role: role identifier
    ;; @param account: principal to grant role to
    ;; @return (response bool uint): success flag and error code
    (grant-role ((string-ascii 32) principal) (response bool uint))
    
    ;; Revoke a role from an account
    ;; @param role: role identifier
    ;; @param account: principal to revoke role from
    ;; @return (response bool uint): success flag and error code
    (revoke-role ((string-ascii 32) principal) (response bool uint))
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
;;   (impl-trait flash_loan_receiver_trait)
(define-trait flash-loan-receiver-trait
  (
    ;; Execute operations with borrowed funds
    ;; @param asset: token being borrowed
    ;; @param amount: amount borrowed
    ;; @param premium: fee to be paid
    ;; @param initiator: address that initiated the flash loan
    ;; @param params: arbitrary data for custom logic
    ;; @return (response bool uint): success flag and error code
    (execute-operation (principal uint uint principal (buff 256)) (response bool uint))
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
    (get-price (principal) (response uint uint))
    
    ;; Update the price of an asset (admin only)
    ;; @param asset: token address to update price for
    ;; @param price: new price value
    ;; @return (response bool uint): success flag and error code
    (update-price (principal uint) (response bool uint))
    
    ;; Get price with timestamp information
    ;; @param asset: token address to get price for
    ;; @return (response (tuple (price uint) (timestamp uint)) uint): price data and error code
    (get-price-with-timestamp (principal) (response (tuple (price uint) (timestamp uint)) uint))

    ;; Get TWAP (Time Weighted Average Price)
    ;; @param asset: token address to get TWAP for
    ;; @param interval: time interval for TWAP calculation
    ;; @return (response uint uint): TWAP value and error code
    (get-twap (principal uint) (response uint uint))
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
    (register-oracle (principal) (response bool uint))
    
    ;; Unregister an existing oracle contract
    ;; @param oracle: principal of oracle contract to unregister
    ;; @return (response bool uint): success flag and error code
    (unregister-oracle (principal) (response bool uint))
    
    ;; Check if an oracle is registered
    ;; @param oracle: principal to check
    ;; @return (response bool uint): true if registered, false otherwise, and error code
    (is-oracle-registered (principal) (response bool uint))
    
    ;; Register a new dimension id with a weight
    ;; @param id: dimension identifier
    ;; @param weight: dimension weight (> 0)
    ;; @return (response uint uint): registered dimension id and error code
    (register-dimension (uint uint) (response uint uint))
    
    ;; Update an existing dimension's weight
    ;; @param dim-id: dimension identifier
    ;; @param new-weight: new weight (> 0)
    ;; @return (response bool uint): success flag and error code
    (update-dimension-weight (uint uint) (response bool uint))
    
    ;; Register a component (contract principal) as a new dimension
    ;; @param component: component contract principal
    ;; @param weight: initial weight (> 0)
    ;; @return (response uint uint): assigned dimension id and error code
    (register-component (principal uint) (response uint uint))
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
    (principal-to-buff (principal) (response (buff 32) uint))
    
    ;; Convert buffer to principal
    ;; @param b: buffer to convert
    ;; @return (response principal uint): principal and error code
    (buff-to-principal ((buff 128)) (response principal uint))
    
    ;; Convert string to unsigned integer
    ;; @param s: string to convert
    ;; @return (response uint uint): integer value and error code
    (string-to-uint ((string-ascii 32)) (response uint uint))
    
    ;; Convert unsigned integer to string
    ;; @param n: integer to convert
    ;; @return (response (string-ascii 32) uint): string representation and error code
    (uint-to-string (uint) (response (string-ascii 32) uint))
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
    (add-token (principal) (response uint uint))
    
    ;; Add an edge (pool connection) between two tokens
    ;; @param token-from: source token
    ;; @param token-to: destination token
    ;; @param pool: pool contract connecting the tokens
    ;; @param pool-type: type of pool (e.g., "constant-product")
    ;; @param liquidity: available liquidity in the pool
    ;; @param fee: swap fee for this pool
    ;; @return (response bool uint): success flag and error code
    (add-edge (principal principal principal (string-ascii 20) uint uint) (response bool uint))
    
    ;; Find the optimal swap path between two tokens
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint): optimal path data and error code
    (find-optimal-path (principal principal uint) (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint))
    
    ;; Execute a swap along the optimal path
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum acceptable output amount
    ;; @return (response (tuple (amount-out uint) (path (list 20 principal)) (hops uint) (distance uint)) uint): swap result and error code
    (swap-optimal-path (principal principal uint uint) (response (tuple (amount-out uint) (path (list 20 principal)) (hops uint) (distance uint)) uint))
    
    ;; Get statistics about the routing graph
    ;; @return (response (tuple (nodes uint) (edges uint)) uint): graph statistics and error code
    (get-graph-stats () (response (tuple (nodes uint) (edges uint)) uint))
    
    ;; Get the index of a token in the graph
    ;; @param token: token principal to look up
    ;; @return (response (optional uint) uint): token index and error code
    (get-token-index (principal) (response (optional uint) uint))
    
    ;; Get information about an edge between two tokens
    ;; @param from-token: source token
    ;; @param to-token: destination token
    ;; @return (response (optional (tuple ...)) uint): edge information and error code
    (get-edge-info (principal principal) (response (optional (tuple (pool principal) (pool-type (string-ascii 20)) (weight uint) (liquidity uint) (fee uint) (active bool))) uint))
    
    ;; Estimate output amount for a swap
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint): estimated output and error code
    (estimate-output (principal principal uint) (response (tuple (path (list 20 principal)) (distance uint) (hops uint)) uint))
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
    (verify-signature ((buff 1024) (buff 65) principal) (response bool uint))
    
    ;; Verify a signature for structured data
    ;; @param structured-data: structured data that was signed
    ;; @param signature: signature to verify
    ;; @param signer: expected signer principal
    ;; @return (response bool uint): true if valid, false otherwise, and error code
    (verify-structured-data ((buff 1024) (buff 65) principal) (response bool uint))
    
    ;; Initialize or update the domain separator
    ;; @param new-separator: new domain separator value
    ;; @return (response bool uint): success flag and error code
    (initialize-domain-separator ((buff 32)) (response bool uint))
  )
)

;; Governance DAO trait
(define-trait dao-trait
  (
    (get-voting-power (principal) (response uint uint))
    (has-voting-power (principal) (response bool uint))
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
    (issue-bond ((string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool uint))
    
    ;; Claim a coupon payment
    ;; @return (response uint uint): amount claimed and error code
    (claim-coupon () (response uint uint))
    
    ;; Redeem bond at maturity
    ;; @param payment-token: token to receive payment in
    ;; @return (response uint uint): amount redeemed and error code
    (redeem-at-maturity (principal) (response uint uint))
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
    (create-bond (uint uint uint uint principal bool uint (string-ascii 32) (string-ascii 10) uint uint) (response (tuple (bond-id uint) (bond-contract principal) (maturity-block uint)) uint))
    
    ;; Get bond details by address
    ;; @param bond-address: bond contract address
    ;; @return (response (tuple ...) uint): bond details and error code
    (get-bond-details (principal) (response (tuple (issuer principal) (principal-amount uint) (coupon-rate uint) (issue-block uint) (maturity-block uint) (collateral-amount uint) (collateral-token principal) (status (string-ascii 20)) (is-callable bool) (call-premium uint) (bond-contract principal) (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (face-value uint)) uint))
    
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
    (issue-bonds (uint uint uint uint) (response uint uint))
    
    ;; Redeem bonds at maturity
    ;; @param bond-id: bond identifier
    ;; @param amount: amount of bonds to redeem
    ;; @return (response uint uint): collateral returned and error code
    (redeem-bonds (uint uint) (response uint uint))
    
    ;; Claim coupon payments
    ;; @param bond-id: bond identifier
    ;; @return (response uint uint): coupon amount and error code
    (claim-coupon (uint) (response uint uint))
    
    ;; Get bond information
    ;; @param bond-id: bond identifier
    ;; @return (response (tuple ...) uint): bond details and error code
    (get-bond-info (uint) (response (tuple (collateral-amount uint) (bond-amount uint) (maturity-blocks uint) (coupon-rate uint) (issued-at uint) (issuer principal)) uint))
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
    (queue-migration (uint) (response uint uint))
    
    ;; Cancel a queued migration request
    ;; @param queue-id: queue entry identifier
    ;; @return (response uint uint): refunded amount and error code
    (cancel-migration (uint) (response uint uint))
    
    ;; Process pending migration requests
    ;; @param max-process: maximum number of requests to process
    ;; @return (response uint uint): number processed and error code
    (process-migrations (uint) (response uint uint))
    
    ;; Get migration queue statistics
    ;; @return (response (tuple ...) uint): queue statistics and error code
    (get-queue-stats () (response (tuple (total-queued uint) (processed uint) (average-wait uint)) uint))
    
    ;; Get user's queued migrations
    ;; @return (response (list 10 uint) uint): list of queue IDs and error code
    (get-user-migrations (principal) (response (list 10 uint) uint))
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
    (swap-exact-tokens-for-tokens (uint uint (list 10 principal) principal uint) (response (list 10 uint) uint))
    
    ;; Swap tokens for exact tokens
    ;; @param amount-out: desired output amount
    ;; @param amount-in-max: maximum input amount
    ;; @param path: swap path (token addresses)
    ;; @param to: recipient address
    ;; @param deadline: transaction deadline
    ;; @return (response (list uint) uint): amounts and error code
    (swap-tokens-for-exact-tokens (uint uint (list 10 principal) principal uint) (response (list 10 uint) uint))
    
    ;; Get amounts out for a given path
    ;; @param amount-in: input amount
    ;; @param path: swap path
    ;; @return (response (list uint) uint): output amounts and error code
    (get-amounts-out (uint (list 10 principal)) (response (list 10 uint) uint))
    
    ;; Get amounts in for a desired output
    ;; @param amount-out: desired output amount
    ;; @param path: swap path
    ;; @return (response (list uint) uint): input amounts and error code
    (get-amounts-in (uint (list 10 principal)) (response (list 10 uint) uint))
    
    ;; Remove liquidity from a pool
    ;; @param token-a: first token
    ;; @param token-b: second token
    ;; @param liquidity: liquidity amount
    ;; @param amount-a-min: minimum amount of token A
    ;; @param amount-b-min: minimum amount of token B
    ;; @param to: recipient address
    ;; @param deadline: transaction deadline
    ;; @return (response (tuple (amount-a uint) (amount-b uint)) uint): removed amounts and error code
    (remove-liquidity (principal principal uint uint uint principal uint) (response (tuple (amount-a uint) (amount-b uint)) uint))
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
    (distribute-yields (uint) (response uint uint))
    
    ;; Calculate optimal yield allocation
    ;; @param available-yield: yield available for allocation
    ;; @param strategies: list of yield strategies
    ;; @return (response (list 10 uint) uint): allocation amounts and error code
    (calculate-optimal-allocation (uint (list 10 principal)) (response (list 10 uint) uint))
    
    ;; Claim yields for a user
    ;; @param user: user principal
    ;; @return (response uint uint): claimed amount and error code
    (claim-yields (principal) (response uint uint))
    
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
    (submit-commitment ((buff 32)) (response uint uint))
    
    ;; Reveal and execute a committed transaction
    ;; @param commitment-id: commitment identifier
    ;; @param transaction-data: actual transaction data
    ;; @return (response bool uint): success flag and error code
    (reveal-and-execute (uint (buff 1024)) (response bool uint))
    
    ;; Check if a commitment is valid
    ;; @param commitment-id: commitment identifier
    ;; @return (response bool uint): validity flag and error code
    (is-commitment-valid (uint) (response bool uint))
    
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
    (submit-audit (principal (string-ascii 64) (string-utf8 256)) (response uint uint))

    ;; Vote on an audit
    ;; @param audit-id: ID of the audit to vote on
    ;; @param approve: true to approve, false to reject
    ;; @return (response bool uint): success flag and error code
    (vote (uint bool) (response bool uint))

    ;; Finalize audit after voting period
    ;; @param audit-id: ID of the audit to finalize
    ;; @return (response bool uint): success flag and error code
    (finalize-audit (uint) (response bool uint))

    ;; Get audit details
    ;; @param audit-id: ID of the audit
    ;; @return (response (tuple ...) uint): audit details and error code
    (get-audit (uint) (response (tuple
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
    (get-audit-status (uint) (response (tuple
      (status (string-ascii 20))
      (reason (optional (string-utf8 500)))
    ) uint))

    ;; Get audit votes
    ;; @param audit-id: ID of the audit
    ;; @return (response (tuple ...) uint): vote details and error code
    (get-audit-votes (uint) (response (tuple
      (for uint)
      (against uint)
      (voters (list 100 principal))
    ) uint))

    ;; Admin: Set voting period
    ;; @param blocks: voting period in blocks
    ;; @return (response bool uint): success flag and error code
    (set-voting-period (uint) (response bool uint))

    ;; Admin: Emergency pause an audit
    ;; @param audit-id: ID of the audit to pause
    ;; @param reason: reason for pausing
    ;; @return (response bool uint): success flag and error code
    (emergency-pause-audit (uint (string-utf8 500)) (response bool uint))
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

    ;; Check whether an account is the current owner
    ;; @param account: principal to check
    ;; @return (response bool uint): true if owner, false otherwise, and error code
    (is-owner (principal) (response bool uint))

    ;; Transfer ownership to a new principal
    ;; @param new-owner: new owner principal
    ;; @return (response bool uint): success flag and error code
    (transfer-ownership (principal) (response bool uint))
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
;;   (impl-trait pausable_trait)
(define-trait pausable-trait
  (
    ;; Check if the contract is currently paused
    ;; @return bool: true if paused, false otherwise
    (is-paused () (response bool uint))
    
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
    (compute-best-route (principal principal uint) (response (tuple (route-id (buff 32)) (hops uint)) uint))
    
    ;; Execute a pre-computed route
    ;; @param route-id: route identifier
    ;; @param recipient: recipient of output tokens
    ;; @return (response uint uint): output amount and error code
    (execute-route ((buff 32) principal) (response uint uint))
    
    ;; Get statistics about a route
    ;; @param route-id: route identifier
    ;; @return (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint): route stats and error code
    (get-route-stats ((buff 32)) (response (tuple (hops uint) (estimated-out uint) (expires-at uint)) uint))
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
    (initialize (principal principal uint int) (response bool uint))
    
    ;; Set the NFT contract for position management
    ;; @param contract-address: NFT contract address
    ;; @return (response bool uint): success flag and error code
    (set-position-nft-contract (principal) (response bool uint))
    
    ;; Mint a new concentrated liquidity position
    ;; @param recipient: position owner
    ;; @param tick-lower: lower tick bound
    ;; @param tick-upper: upper tick bound
    ;; @param amount: liquidity amount
    ;; @return (response (tuple (position-id uint) (liquidity uint) (amount-x uint) (amount-y uint)) uint): position data and error code
    (mint-position (principal int int uint) (response (tuple (position-id uint) (liquidity uint) (amount-x uint) (amount-y uint)) uint))
    
    ;; Burn a concentrated liquidity position
    ;; @param position-id: position identifier
    ;; @return (response (tuple (fees-x uint) (fees-y uint)) uint): fees earned and error code
    (burn-position (uint) (response (tuple (fees-x uint) (fees-y uint)) uint))
    
    ;; Collect fees from a position
    ;; @param position-id: position identifier
    ;; @param recipient: fee recipient
    ;; @return (response (tuple (amount-x uint) (amount-y uint)) uint): collected amounts and error code
    (collect-position (uint principal) (response (tuple (amount-x uint) (amount-y uint)) uint))
  )
)

;; ===========================================
;; Interface for DEX liquidity pools
;;
;; This trait defines the standard interface that all DEX pools must implement
;; to be compatible with the Conxian DEX router and factory.
;;
;; Example usage:
;;   (impl-trait pool_trait)
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
    (get-liquidity (principal) (response uint uint))
    
    ;; Swap tokens in the pool
    ;; @param token-in: input token
    ;; @param token-out: output token  
    ;; @param amount-in: amount of input token
    ;; @param min-amount-out: minimum acceptable output amount
    ;; @param recipient: recipient of output tokens
    ;; @return (response uint uint): output amount and error code
    (swap (principal principal uint uint principal) (response uint uint))
    
    ;; Add liquidity to the pool
    ;; @param token-x-amount: amount of token-x to add
    ;; @param token-y-amount: amount of token-y to add
    ;; @param min-token-x-amount: minimum token-x amount (slippage protection)
    ;; @param min-token-y-amount: minimum token-y amount (slippage protection)
    ;; @param recipient: recipient of liquidity tokens/shares
    ;; @return (response (tuple (liquidity uint) (token-x-amount uint) (token-y-amount uint)) uint): liquidity added and error code
    (add-liquidity (uint uint uint uint principal) (response (tuple (liquidity uint) (token-x-amount uint) (token-y-amount uint)) uint))
    
    ;; Remove liquidity from the pool
    ;; @param liquidity: amount of liquidity to remove
    ;; @param min-token-x-amount: minimum token-x amount (slippage protection)
    ;; @param min-token-y-amount: minimum token-y amount (slippage protection)
    ;; @param recipient: recipient of removed tokens
    ;; @return (response (tuple (token-x-amount uint) (token-y-amount uint)) uint): tokens removed and error code
    (remove-liquidity (uint uint uint principal) (response (tuple (token-x-amount uint) (token-y-amount uint)) uint))
    
    ;; Get amount out for a given amount in
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-in: amount of input token
    ;; @return (response uint uint): expected output amount and error code
    (get-amount-out (principal principal uint) (response uint uint))
    
    ;; Get amount in for a desired amount out
    ;; @param token-in: input token
    ;; @param token-out: output token
    ;; @param amount-out: desired amount of output token
    ;; @return (response uint uint): required input amount and error code
  (get-amount-in (principal principal uint) (response uint uint))
  )
)

;; ===========================================
;; DEX FACTORY V2 TRAIT
;; ===========================================
;; Interface for registering pool types and creating pools via the factory
;; Supports pool discovery and retrieval
;;
;; Example usage:
;;   (use-trait dex-factory-v2-trait .all-traits.dex-factory-v2-trait)
(define-trait dex-factory-v2-trait
  (
    ;; Register a pool type implementation
    ;; @param type-id: identifier for pool type (e.g., "constant-product", "stable", "weighted", "concentrated")
    ;; @param impl: principal of implementation contract
    ;; @return (response bool uint): success flag and error code
    (register-pool-type ((string-ascii 32) principal) (response bool uint))

    ;; Create a pool for a token pair using a given type
    ;; @param type-id: pool type identifier
    ;; @param token-a: first token principal
    ;; @param token-b: second token principal
    ;; @return (response principal uint): pool principal and error code
    (create-pool ((string-ascii 32) principal principal) (response principal uint))

    ;; Retrieve a pool principal for a given token pair
    ;; @param token-a: first token principal
    ;; @param token-b: second token principal
    ;; @return (response (optional principal) uint): optional pool principal and error code
    (get-pool (principal principal) (response (optional principal) uint))
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
    (wrap-btc (uint (buff 32)) (response uint uint))
    
    ;; Unwrap Stacks token back to Bitcoin
    ;; @param amount: amount to unwrap
    ;; @param btc-address: Bitcoin address to send to
    ;; @return (response bool uint): success flag and error code
    (unwrap-btc (uint (buff 64)) (response bool uint))
    
    ;; Get wrapped Bitcoin balance for a user
    ;; @param user: user principal
    ;; @return (response uint uint): wrapped balance and error code
    (get-wrapped-balance (principal) (response uint uint))
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
    (update-funding-rate (principal) (response (tuple (funding-rate int) (index-price uint) (timestamp uint) (cumulative-funding int)) uint))

    ;; Apply funding to a position
    ;; @param position-owner: owner of the position
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): funding payment data and error code
    (apply-funding-to-position (principal uint) (response (tuple (funding-rate int) (funding-payment uint) (new-collateral uint) (timestamp uint)) uint))

    ;; Get current funding rate for an asset
    ;; @param asset: asset to get funding rate for
    ;; @return (response (tuple ...) uint): current funding rate data and error code
    (get-current-funding-rate (principal) (response (tuple (rate int) (last-updated uint) (next-update uint)) uint))

    ;; Get funding rate history
    ;; @param asset: asset to get history for
    ;; @param from-block: start block
    ;; @param to-block: end block
    ;; @param limit: maximum number of entries
    ;; @return (response (list ...) uint): funding rate history and error code
    (get-funding-rate-history (principal uint uint uint) (response (list 20 (tuple (rate int) (index-price uint) (open-interest-long uint) (open-interest-short uint) (timestamp uint))) uint))

    ;; Set funding parameters (admin only)
    ;; @param interval: funding interval in blocks
    ;; @param max-rate: maximum funding rate
    ;; @param sensitivity: funding rate sensitivity
    ;; @return (response bool uint): success flag and error code
    (set-funding-parameters (uint uint uint) (response bool uint))
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
    (liquidate-position (principal uint uint) (response bool uint))

    ;; Liquidate multiple positions in batch
    ;; @param positions: list of positions to liquidate
    ;; @param max-slippage: maximum allowed slippage
    ;; @return (response (list 20 (response bool uint)) uint): liquidation results and error code
    (liquidate-positions ((list 20 (tuple (owner principal) (id uint))) uint) (response (list 20 (response bool uint)) uint))

    ;; Check position health status
    ;; @param position-owner: owner of the position
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): health metrics and error code
    (check-position-health (principal uint) (response (tuple (margin-ratio uint) (liquidation-price uint) (current-price uint) (health-factor uint) (is-liquidatable bool)) uint))

    ;; Set liquidation reward parameters (admin only)
    ;; @param min-reward: minimum liquidation reward
    ;; @param max-reward: maximum liquidation reward
    ;; @return (response bool uint): success flag and error code
    (set-liquidation-rewards (uint uint) (response bool uint))

    ;; Set insurance fund address (admin only)
    ;; @param fund: new insurance fund address
    ;; @return (response bool uint): success flag and error code
    (set-insurance-fund (principal) (response bool uint))
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
    (get-liquidation-price ((tuple (asset principal) (size int) (collateral uint) (entry-price uint) (maintenance-margin uint)) uint) (response uint uint))

    ;; Calculate margin ratio for a position
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @return (response uint uint): margin ratio and error code
    (calculate-margin-ratio ((tuple (asset principal) (size int) (collateral uint) (entry-price uint) (maintenance-margin uint)) uint) (response uint uint))

    ;; Check if position is at risk of liquidation
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @param maintenance-margin: maintenance margin requirement
    ;; @return (response bool uint): true if at risk, false otherwise, and error code
    (is-position-at-risk ((tuple (asset principal) (size int) (collateral uint) (entry-price uint)) uint uint) (response bool uint))

    ;; Calculate PnL for a position
    ;; @param position: position data
    ;; @param current-price: current market price
    ;; @return (response int uint): profit/loss amount and error code
    (calculate-pnl ((tuple (asset principal) (size int) (entry-price uint)) uint) (response int uint))

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
    (submit-bid (uint uint) (response uint uint))

    ;; Cancel a submitted bid
    ;; @param bid-id: bid identifier
    ;; @return (response bool uint): success flag and error code
    (cancel-bid (uint) (response bool uint))

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
    (create-budget ((string-ascii 64) (string-utf8 256) uint uint) (response uint uint))

    ;; Execute a budget allocation
    ;; @param budget-id: budget identifier
    ;; @param recipient: recipient address
    ;; @return (response bool uint): success flag and error code
    (execute-allocation (uint principal) (response bool uint))

    ;; Get budget details
    ;; @param budget-id: budget identifier
    ;; @return (response (tuple ...) uint): budget details and error code
    (get-budget (uint) (response (tuple (name (string-ascii 64)) (description (string-utf8 256)) (amount uint) (spent uint) (duration uint) (created-at uint) (status (string-ascii 20))) uint))

    ;; Update budget status
    ;; @param budget-id: budget identifier
    ;; @param status: new status
    ;; @return (response bool uint): success flag and error code
    (update-budget-status (uint (string-ascii 20)) (response bool uint))
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
    (get-task-status (uint) (response (tuple (status (string-ascii 20)) (last-executed uint) (next-execution uint) (success-count uint) (failure-count uint)) uint))
  )
)

;; ===========================================
;; Interface for yield strategy contracts
;;
;; This trait provides functions for DeFi yield strategies, including
;; deposit, withdrawal, harvesting, and emergency functions.
;;
;; Example usage:
;;   (use-trait strategy .all-traits.strategy-trait)
(define-trait strategy-trait
  (
    ;; Deposit tokens into the strategy
    ;; @param token-contract: the token contract to deposit
    ;; @param amount: amount of tokens to deposit
    ;; @return (response uint uint): deposited amount and error code
    (deposit (principal uint) (response uint uint))

    ;; Withdraw tokens from the strategy
    ;; @param token-contract: the token contract to withdraw from
    ;; @param amount: amount of tokens to withdraw
    ;; @return (response uint uint): withdrawn amount and error code
    (withdraw (principal uint) (response uint uint))

    ;; Harvest rewards from the strategy
    ;; @return (response bool uint): success flag and error code
    (harvest () (response bool uint))

    ;; Get the total value locked in the strategy
    ;; @return (response uint uint): TVL and error code
    (get-tvl () (response uint uint))

    ;; Get the annual percentage yield
    ;; @return (response uint uint): APY in basis points and error code
    (get-apy () (response uint uint))

    ;; Emergency exit - withdraw all funds immediately
    ;; @return (response uint uint): withdrawn amount and error code
    (emergency-exit () (response uint uint))

    ;; Get strategy information
    ;; @return (response (tuple ...) uint): strategy details and error code
    (get-strategy-info () (response (tuple (deployed uint) (current-value uint) (expected-apy uint) (risk-level uint)) uint))
  )
)

;; ===========================================
;; DUAL STACKING TRAIT
;; ===========================================
(define-trait dual-stacking-trait
  (
    (initialize (<sip-010-ft-trait> principal uint) (response bool uint))
    (record-delegations (uint (list 200 (tuple (user principal) (amount uint)))) (response bool uint))
    (deposit-reward (uint <sip-010-ft-trait> uint) (response bool uint))
    (claim (<sip-010-ft-trait>) (response uint uint))
    (get-user-claimable (principal) (response uint uint))
    (get-cycle-stats (uint) (response (tuple (total-delegated uint) (reward uint)) uint))
    (set-operator (principal) (response bool uint))
    (set-fee (uint) (response bool uint))
    (set-fee-recipient (principal) (response bool uint))
  )
)



(define-trait role-nft-ops
  (
    (mint-role ((string-ascii 32) principal) (response uint uint))
    (burn-role (uint) (response bool uint))
  )
)

;; Minimal oracle trait for price queries
(define-trait oracle-trait
  (
    (get-price (principal) (response uint uint))
  )
)

;; Minimal finance metrics trait implemented by monitoring/finance-metrics
(define-trait finance-metrics-trait
  (
    (set-writer-principal (principal) (response bool uint))
    (set-contract-owner (principal) (response bool uint))
    (record-ebitda ((string-ascii 32) uint) (response bool uint))
    (record-capex ((string-ascii 32) uint) (response bool uint))
    (record-opex ((string-ascii 32) uint) (response bool uint))
    (get-aggregate ((string-ascii 32) (string-ascii 8) uint) (response uint uint))
    (get-system-finance-summary (uint) (response (tuple (ebitda uint) (capex uint) (opex uint)) uint))
    (get-contract-owner () (response principal uint))
  )
)

;; Minimal dimensional engine trait placeholder
(define-trait dimensional-trait
  (
    (get-version () (response uint uint))
  )
)

;; Additional minimal trait stubs

(define-trait amm-trait
  (
    (swap (principal principal uint uint principal) (response uint uint))
    (add-liquidity (principal uint) (response uint uint))
    (get-reserves (principal principal) (response (tuple (reserve-a uint) (reserve-b uint)) uint))
  )
)

(define-trait analytics-aggregator-trait
  (
    (record-metric ((string-ascii 32) uint) (response bool uint))
    (get-metric ((string-ascii 32)) (response uint uint))
  )
)

(define-trait dimensional-core-trait
  (
    (get-version () (response uint uint))
  )
)

(define-trait error-codes-trait
  (
    (get-code (uint) (response uint uint))
  )
)

(define-trait factory-trait
  (
    (create-pool (principal principal uint) (response principal uint))
    (register-pool (principal) (response bool uint))
  )
)

(define-trait fixed-point-math-trait
  (
    (mul-down (uint uint) (response uint uint))
    (div-down (uint uint) (response uint uint))
  )
)

(define-trait governance-token-trait
  (
    (get-voting-power (principal) (response uint uint))
    (has-voting-power (principal) (response bool uint))
  )
)

(define-trait lending-system-trait
  (
    (deposit (principal uint) (response bool uint))
    (withdraw (principal uint) (response bool uint))
    (borrow (principal uint) (response uint uint))
    (repay (principal uint) (response bool uint))
  )
)

(define-trait math-trait
  (
    (sqrt (uint) (response uint uint))
    (pow (uint uint) (response uint uint))
  )
)

(define-trait monitoring-trait
  (
    (get-system-metrics () (response (tuple (latency uint) (throughput uint)) uint))
  )
)

(define-trait performance-optimizer-trait
  (
    (optimize (principal) (response bool uint))
  )
)

(define-trait pool-factory-trait
  (
    (create-pool (principal principal uint) (response principal uint))
    (register-pool (principal) (response bool uint))
  )
)

(define-trait price-initializer-trait
  (
    (get-price-with-minimum () (response (tuple (price uint) (min-price uint) (last-updated uint)) uint))
  )
)

(define-trait proposal-engine-trait
  (
    (propose ((string-ascii 256) (list 10 principal) (list 10 uint) (list 10 (string-ascii 64)) (list 10 (buff 1024)) uint uint) (response uint uint))
    (vote (uint bool uint) (response bool uint))
    (execute (uint) (response bool uint))
  )
)

(define-trait proposal-trait
  (
    (execute () (response bool uint))
  )
)

(define-trait risk-oracle-trait
  (
    (calculate-margin-requirements (principal uint uint) (response (tuple (initial-margin uint) (maintenance-margin uint) (max-leverage uint)) uint))
    (get-liquidation-price ((tuple (size int) (entry-price uint) (collateral uint)) principal) (response (tuple (price uint) (threshold uint) (is-liquidatable bool)) uint))
    (check-position-health ((tuple (size int) (entry-price uint) (collateral uint) (last-updated uint)) principal) (response (tuple (margin-ratio uint) (liquidation-price uint) (is-liquidatable bool) (health-factor uint) (pnl (tuple (unrealized uint) (roi uint))) (position (tuple (size int) (value uint) (collateral uint) (entry-price uint) (current-price uint)))) uint))
  )
)

(define-trait sip-010-ft-mintable-trait
  (
    (mint (principal uint) (response bool uint))
    (burn (principal uint) (response bool uint))
  )
)

(define-trait sip-010-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

(define-trait sip-018-trait
  (
    (get-domain-separator () (response (buff 32) uint))
    (get-structured-data-version () (response (string-ascii 16) uint))
    (verify-signature ((buff 1024) (buff 65) principal) (response bool uint))
    (verify-structured-data ((buff 1024) (buff 65) principal) (response bool uint))
    (initialize-domain-separator ((buff 32)) (response bool uint))
  )
)

(define-trait upgrade-controller-trait
  (
    (authorize-upgrade (principal (buff 32)) (response bool uint))
  )
)

;; ===========================================
;; END OF CENTRALIZED TRAIT DEFINITIONS
;; ===========================================
;;
;; All trait definitions above are the canonical definitions for the Conxian protocol.
;; Duplicate definitions have been removed to prevent conflicts.
;;
;; For trait usage:
;;   (use-trait <trait-name> .all-traits.<trait-name>)
;;   (impl-trait <trait-name>)  ;; where <trait-name> is defined via use-trait
;;