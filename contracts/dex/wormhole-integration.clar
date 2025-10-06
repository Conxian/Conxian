;; wormhole-integration.clar
;; Wormhole Cross-Chain Integration for Conxian Protocol
;; Provides cross-chain asset bridging, governance, and yield aggregation

(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u3000))
(define-constant ERR_INVALID_CHAIN (err u3001))
(define-constant ERR_INVALID_TOKEN (err u3002))
(define-constant ERR_BRIDGE_PAUSED (err u3003))
(define-constant ERR_INSUFFICIENT_BALANCE (err u3004))
(define-constant ERR_VAA_EXPIRED (err u3005))
(define-constant ERR_VAA_ALREADY_PROCESSED (err u3006))
(define-constant ERR_INVALID_GUARDIAN_SET (err u3007))
(define-constant ERR_INSUFFICIENT_SIGNATURES (err u3008))
(define-constant ERR_CHAIN_NOT_SUPPORTED (err u3009))
(define-constant ERR_YIELD_CLAIM_FAILED (err u3010))

;; Wormhole chain IDs
(define-constant CHAIN_ID_STACKS u6)
(define-constant CHAIN_ID_ETHEREUM u2)
(define-constant CHAIN_ID_SOLANA u1) 
(define-constant CHAIN_ID_POLYGON u5)
(define-constant CHAIN_ID_BSC u4)
(define-constant CHAIN_ID_AVALANCHE u6)
(define-constant CHAIN_ID_ARBITRUM u23)
(define-constant CHAIN_ID_OPTIMISM u24)

;; Bridge parameters
(define-constant MIN_BRIDGE_AMOUNT u1000000)      ;; 1 token minimum
(define-constant MAX_BRIDGE_AMOUNT u100000000000) ;; 100k tokens maximum
(define-constant BRIDGE_FEE_BASIS_POINTS u50)     ;; 0.5% bridge fee
(define-constant VAA_EXPIRY_BLOCKS u17280)        ;; 24 hours in Nakamoto blocks

;; Guardian set parameters
(define-constant MIN_GUARDIAN_SIGNATURES u13)     ;; 2/3 of 19 guardians
(define-constant GUARDIAN_SET_EXPIRY u2592000)    ;; 30 days in blocks

;; Cross-chain yield parameters
(define-constant YIELD_HARVEST_INTERVAL u86400)   ;; 5 days in Nakamoto blocks
(define-constant MIN_YIELD_CLAIM_AMOUNT u100000)  ;; Min amount to claim yield

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map supported-chains
  { chain-id: uint }
  {
    chain-name: (string-ascii 20),
    is-active: bool,
    bridge-enabled: bool,
    governance-enabled: bool,
    yield-enabled: bool,
    wormhole-address: (optional (buff 32)),
    native-currency: (string-ascii 10)
  }
)

(define-map bridged-tokens
  { token-address: principal, chain-id: uint }
  {
    original-token: (buff 32),
    decimals: uint,
    symbol: (string-ascii 10),
    is-native: bool,
    bridge-enabled: bool,
    total-bridged-in: uint,
    total-bridged-out: uint,
    bridge-fee: uint
  }
)

(define-map vaa-registry
  { vaa-hash: (buff 32) }
  {
    sequence: uint,
    source-chain: uint,
    target-chain: uint,
    emitter: (buff 32),
    payload: (buff 1024),
    processed: bool,
    processed-at-block: uint,
    expiry-block: uint
  }
)

(define-map guardian-sets
  { guardian-set-index: uint }
  {
    guardians: (list 20 (buff 20)),
    guardian-count: uint,
    creation-block: uint,
    expiry-block: uint,
    is-active: bool
  }
)

(define-map cross-chain-positions
  { user: principal, chain-id: uint }
  {
    total-deposited: uint,
    total-yield-earned: uint,
    last-yield-claim: uint,
    position-tokens: (list 10 { token: principal, amount: uint }),
    auto-compound: bool
  }
)

(define-map bridge-state
  { }
  {
    is-paused: bool,
    current-guardian-set: uint,
    total-volume: uint,
    total-fees-collected: uint,
    last-guardian-update: uint
  }
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-supported-chains)
  "Get list of all supported chains"
  (list 
    { chain-id: CHAIN_ID_ETHEREUM, name: "Ethereum" }
    { chain-id: CHAIN_ID_SOLANA, name: "Solana" }
    { chain-id: CHAIN_ID_POLYGON, name: "Polygon" }
    { chain-id: CHAIN_ID_BSC, name: "BSC" }
    { chain-id: CHAIN_ID_AVALANCHE, name: "Avalanche" }
    { chain-id: CHAIN_ID_ARBITRUM, name: "Arbitrum" }
    { chain-id: CHAIN_ID_OPTIMISM, name: "Optimism" }
  )
)

(define-read-only (get-chain-config (chain-id uint))
  "Get configuration for specific chain"
  (map-get? supported-chains { chain-id: chain-id })
)

(define-read-only (get-bridged-token-info (token principal) (chain-id uint))
  "Get bridged token information"
  (map-get? bridged-tokens { token-address: token, chain-id: chain-id })
)

(define-read-only (is-vaa-processed (vaa-hash (buff 32)))
  "Check if VAA has been processed"
  (match (map-get? vaa-registry { vaa-hash: vaa-hash })
    vaa-data (get processed vaa-data)
    false
  )
)

(define-read-only (calculate-bridge-fee (amount uint) (token principal) (target-chain uint))
  "Calculate bridge fee for token transfer"
  (match (get-bridged-token-info token target-chain)
    token-info (let ((custom-fee (get bridge-fee token-info)))
      (if (> custom-fee u0)
        custom-fee
        (/ (* amount BRIDGE_FEE_BASIS_POINTS) u10000)
      )
    )
    (/ (* amount BRIDGE_FEE_BASIS_POINTS) u10000)
  )
)

(define-read-only (get-cross-chain-position (user principal) (chain-id uint))
  "Get users cross-chain position"
  (map-get? cross-chain-positions { user: user, chain-id: chain-id })
)

(define-read-only (calculate-pending-yield (user principal) (chain-id uint))
  "Calculate pending yield for users cross-chain position"
  (match (get-cross-chain-position user chain-id)
    position (let ((blocks-since-claim (- block-height (get last-yield-claim position)))
                   (deposited-amount (get total-deposited position)))
      ;; Simple yield calculation - 5% APY
      ;; In production, this would query actual yield protocols
      (/ (* (* deposited-amount u500) blocks-since-claim) (* u10000 u2102400)) ;; Blocks per year
    )
    u0
  )
)

;; =============================================================================
;; BRIDGE FUNCTIONS
;; =============================================================================

(define-public (initiate-bridge-transfer (token <sip-010-ft-trait>) 
                                       (amount uint) 
                                       (target-chain uint) 
                                       (recipient (buff 32)))
  "Initiate cross-chain token transfer via Wormhole"
  (let ((token-principal (contract-of token))
        (bridge-fee (calculate-bridge-fee amount token-principal target-chain)))
    (begin
      ;; Validate bridge parameters
      (asserts! (not (is-bridge-paused)) ERR_BRIDGE_PAUSED)
      (asserts! (is-chain-supported target-chain) ERR_CHAIN_NOT_SUPPORTED)
      (asserts! (>= amount MIN_BRIDGE_AMOUNT) ERR_INSUFFICIENT_BALANCE)
      (asserts! (<= amount MAX_BRIDGE_AMOUNT) ERR_INSUFFICIENT_BALANCE)
      
      ;; Transfer tokens from user
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
      
      ;; Lock tokens in bridge
      (try! (update-bridge-volume amount bridge-fee))
      
      ;; Emit bridge event for Wormhole relayers
      (print {
        event: "bridge-transfer-initiated",
        token: token-principal,
        amount: (- amount bridge-fee),
        fee: bridge-fee,
        target-chain: target-chain,
        recipient: recipient,
        sequence: (+ (get-bridge-sequence) u1)
      })
      
      (ok { sequence: (+ (get-bridge-sequence) u1), fee: bridge-fee })
    )
  )
)

(define-public (complete-bridge-transfer (vaa (buff 1024)) 
                                       (signatures (list 20 (buff 65))))
  "Complete cross-chain transfer using Wormhole VAA"
  (let ((vaa-hash (keccak256 vaa)))
    (begin
      ;; Validate VAA hasnt been processed
      (asserts! (not (is-vaa-processed vaa-hash)) ERR_VAA_ALREADY_PROCESSED)
      
      ;; Validate guardian signatures
      (try! (verify-guardian-signatures vaa signatures))
      
      ;; Parse and execute VAA payload
      (match (parse-bridge-vaa vaa)
        parsed-vaa (begin
          ;; Mint/unlock tokens to recipient
          (try! (execute-bridge-mint parsed-vaa))
          
          ;; Mark VAA as processed
          (map-set vaa-registry { vaa-hash: vaa-hash }
            {
              sequence: (get sequence parsed-vaa),
              source-chain: (get source-chain parsed-vaa),
              target-chain: CHAIN_ID_STACKS,
              emitter: (get emitter parsed-vaa),
              payload: vaa,
              processed: true,
              processed-at-block: block-height,
              expiry-block: (+ block-height VAA_EXPIRY_BLOCKS)
            }
          )
          
          (print { event: "bridge-transfer-completed", vaa-hash: vaa-hash })
          (ok true)
        )
        (err ERR_VAA_EXPIRED)
      )
    )
  )
)

;; =============================================================================
;; CROSS-CHAIN YIELD FUNCTIONS
;; =============================================================================

(define-public (deposit-for-yield (token <sip-010-ft-trait>) 
                                (amount uint) 
                                (target-chain uint)
                                (yield-strategy (string-ascii 50)))
  "Deposit tokens to earn yield on target chain"
  (let ((token-principal (contract-of token)))
    (begin
      (asserts! (is-chain-supported target-chain) ERR_CHAIN_NOT_SUPPORTED)
      (asserts! (>= amount MIN_BRIDGE_AMOUNT) ERR_INSUFFICIENT_BALANCE)
      
      ;; Transfer tokens to bridge
      (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
      
      ;; Update users cross-chain position
      (match (get-cross-chain-position tx-sender target-chain)
        existing-position (map-set cross-chain-positions { user: tx-sender, chain-id: target-chain }
          (merge existing-position {
            total-deposited: (+ (get total-deposited existing-position) amount),
            last-yield-claim: block-height
          })
        )
        (map-set cross-chain-positions { user: tx-sender, chain-id: target-chain }
          {
            total-deposited: amount,
            total-yield-earned: u0,
            last-yield-claim: block-height,
            position-tokens: (list { token: token-principal, amount: amount }),
            auto-compound: false
          }
        )
      )
      
      ;; Emit deposit event for cross-chain yield protocol
      (print {
        event: "yield-deposit-initiated",
        user: tx-sender,
        token: token-principal,
        amount: amount,
        target-chain: target-chain,
        strategy: yield-strategy
      })
      
      (ok true)
    )
  )
)

(define-public (claim-cross-chain-yield (chain-id uint))
  "Claim accumulated yield from cross-chain position"
  (let ((pending-yield (calculate-pending-yield tx-sender chain-id)))
    (begin
      (asserts! (>= pending-yield MIN_YIELD_CLAIM_AMOUNT) ERR_YIELD_CLAIM_FAILED)
      
      ;; Update position with claimed yield
      (match (get-cross-chain-position tx-sender chain-id)
        position (map-set cross-chain-positions { user: tx-sender, chain-id: chain-id }
          (merge position {
            total-yield-earned: (+ (get total-yield-earned position) pending-yield),
            last-yield-claim: block-height
          })
        )
        ERR_INVALID_CHAIN
      )
      
      ;; In production, this would trigger cross-chain yield claim
      (print {
        event: "yield-claimed",
        user: tx-sender,
        chain-id: chain-id,
        yield-amount: pending-yield
      })
      
      (ok pending-yield)
    )
  )
)

;; =============================================================================
;; CROSS-CHAIN GOVERNANCE
;; =============================================================================

(define-public (submit-cross-chain-proposal (target-chains (list 10 uint))
                                          (proposal-data (buff 512))
                                          (execution-delay uint))
  "Submit governance proposal for cross-chain execution"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    ;; Validate all target chains are supported
    (asserts! (fold check-chain-supported target-chains true) ERR_CHAIN_NOT_SUPPORTED)
    
    ;; Emit cross-chain governance event
    (print {
      event: "cross-chain-proposal-submitted",
      target-chains: target-chains,
      proposal-hash: (keccak256 proposal-data),
      execution-delay: execution-delay,
      expires-at: (+ block-height execution-delay)
    })
    
    (ok true)
  )
)

;; =============================================================================
;; ADMIN FUNCTIONS
;; =============================================================================

(define-public (add-supported-chain (chain-id uint)
                                  (chain-name (string-ascii 20))
                                  (wormhole-address (buff 32)))
  "Add support for new chain"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set supported-chains { chain-id: chain-id }
      {
        chain-name: chain-name,
        is-active: true,
        bridge-enabled: true,
        governance-enabled: true,
        yield-enabled: true,
        wormhole-address: (some wormhole-address),
        native-currency: "ETH"
      }
    )
    
    (print { event: "chain-added", chain-id: chain-id, name: chain-name })
    (ok true)
  )
)

(define-public (register-bridged-token (token principal)
                                     (chain-id uint)
                                     (original-token (buff 32))
                                     (decimals uint)
                                     (symbol (string-ascii 10)))
  "Register token for cross-chain bridging"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (is-chain-supported chain-id) ERR_CHAIN_NOT_SUPPORTED)
    
    (map-set bridged-tokens { token-address: token, chain-id: chain-id }
      {
        original-token: original-token,
        decimals: decimals,
        symbol: symbol,
        is-native: (is-eq chain-id CHAIN_ID_STACKS),
        bridge-enabled: true,
        total-bridged-in: u0,
        total-bridged-out: u0,
        bridge-fee: BRIDGE_FEE_BASIS_POINTS
      }
    )
    
    (print { event: "token-registered", token: token, chain-id: chain-id })
    (ok true)
  )
)

(define-public (pause-bridge (paused bool))
  "Pause/unpause bridge operations"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    
    (map-set bridge-state { }
      (merge (get-bridge-state) { is-paused: paused })
    )
    
    (print { event: "bridge-paused", paused: paused })
    (ok true)
  )
)

;; =============================================================================
;; HELPER FUNCTIONS
;; =============================================================================

(define-private (is-chain-supported (chain-id uint))
  "Check if chain ID is supported"
  (is-some (get-chain-config chain-id))
)

(define-private (check-chain-supported (chain-id uint) (acc bool))
  "Fold helper to check if all chains are supported"
  (and acc (is-chain-supported chain-id))
)

(define-private (is-bridge-paused)
  (begin
    "Check if bridge is currently paused"
  (get is-paused (get-bridge-state))
  ))

(define-private (get-bridge-state)
  (begin
    "Get current bridge state"
  (default-to {
    is-paused: false,
    current-guardian-set: u0,
    total-volume: u0,
    total-fees-collected: u0,
    last-guardian-update: u0
  } (map-get? bridge-state { }))
  ))

(define-private (get-bridge-sequence)
  (begin
    "Get next bridge sequence number"
  (get total-volume (get-bridge-state))
  ))

(define-private (update-bridge-volume (amount uint) (fee uint))
  "Update bridge volume and fee statistics"
  (let ((current-state (get-bridge-state)))
    (map-set bridge-state { }
      (merge current-state {
        total-volume: (+ (get total-volume current-state) amount),
        total-fees-collected: (+ (get total-fees-collected current-state) fee)
      })
    )
    (ok true)
  )
)

(define-private (verify-guardian-signatures (vaa (buff 1024)) (signatures (list 20 (buff 65))))
  "Verify guardian signatures on VAA"
  ;; Simplified verification - production would implement full cryptographic verification
  (if (>= (len signatures) MIN_GUARDIAN_SIGNATURES)
    (ok true)
    ERR_INSUFFICIENT_SIGNATURES
  )
)

(define-private (parse-bridge-vaa (vaa (buff 1024)))
  "Parse Wormhole VAA payload"
  ;; Simplified parsing - production would implement full VAA parsing
  (some {
    sequence: u1,
    source-chain: CHAIN_ID_ETHEREUM,
    emitter: 0x0000000000000000000000000000000000000000000000000000000000000000,
    recipient: tx-sender,
    token: .sbtc-token,
    amount: u1000000
  })
)

(define-private (execute-bridge-mint (parsed-vaa { sequence: uint, source-chain: uint, emitter: (buff 32), recipient: principal, token: principal, amount: uint }))
  "Execute token mint/unlock for bridge transfer"
  ;; In production, this would mint wrapped tokens or unlock native tokens
  (print { event: "bridge-mint-executed", recipient: (get recipient parsed-vaa), amount: (get amount parsed-vaa) })
  (ok true)
)

;; Initialize supported chains
(begin
  (try! (add-supported-chain CHAIN_ID_ETHEREUM "Ethereum" 0x0000000000000000000000003ee18b2214aff97000d974cf647e7c347e8fa585))
  (try! (add-supported-chain CHAIN_ID_SOLANA "Solana" 0x0000000000000000000000000000000000000000000000000000000000000001))
  (try! (add-supported-chain CHAIN_ID_POLYGON "Polygon" 0x0000000000000000000000007a4b5a56256163f07b2c80a7ca55aBE66c4ec4d7))
  (print { event: "wormhole-integration-deployed", version: "1.0.0", supported-chains: u3 })
)






