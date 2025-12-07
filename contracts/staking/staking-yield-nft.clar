;; staking-yield-nft.clar
;; Comprehensive staking and yield farming NFT system
;; Represents staking positions, yield farming participation, and reward tier achievements

(use-trait sip-009-nft-trait .defi-traits.sip-009-nft-trait)
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

(impl-trait .defi-traits.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u11000))
(define-constant ERR_INVALID_STAKE (err u11001))
(define-constant ERR_STAKE_NOT_FOUND (err u11002))
(define-constant ERR_STAKE_LOCKED (err u11003))
(define-constant ERR_INSUFFICIENT_REWARDS (err u11004))
(define-constant ERR_INVALID_FARM (err u11005))
(define-constant ERR_FARM_NOT_ACTIVE (err u11006))

;; Staking Constants
(define-constant BLOCKS_PER_DAY u17280)        ;; 24 hours * 120 (5s blocks)
(define-constant BLOCKS_PER_MONTH u518400)     ;; 30 days
(define-constant BLOCKS_PER_YEAR u6307200)     ;; 365 days

(define-constant MIN_STAKE_AMOUNT u1000000)          ;; 1 STX minimum
(define-constant MAX_STAKE_AMOUNT u1000000000)        ;; 1000 STX maximum
(define-constant MIN_LOCK_DURATION u17280)            ;; 1 day minimum (previously u100)
(define-constant MAX_LOCK_DURATION u63072000)         ;; 10 years maximum (previously u100000)
(define-constant BASE_YIELD_RATE u500)                 ;; 5% base yield rate
(define-constant YIELD_BOOST_MULTIPLIER u1500)         ;; 1.5x yield boost multiplier

;; Staking NFT Types
(define-constant NFT_TYPE_STAKING_POSITION u1)        ;; Staking position NFT
(define-constant NFT_TYPE_YIELD_FARM u2)             ;; Yield farming position NFT
(define-constant NFT_TYPE_REWARD_TIER u3)            ;; Reward tier achievement NFT
(define-constant NFT_TYPE_LOCKUP_BONUS u4)           ;; Lockup bonus certificate NFT
(define-constant NFT_TYPE_COMPOUND_REWARD u5)         ;; Compound reward multiplier NFT

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)
(define-data-var next-stake-id uint u1)
(define-data-var next-farm-id uint u1)
(define-data-var base-token-uri (optional (string-utf8 256)) none)
(define-data-var staking-treasury principal tx-sender)

;; ===== NFT Definition =====
(define-non-fungible-token staking-nft uint)

;; ===== Staking Data Structures =====

;; Staking position NFTs
(define-map staking-positions
  { token-id: uint }
  {
    owner: principal,
    stake-amount: uint,                          ;; Amount staked
    stake-token: principal,                       ;; Token being staked
    lock-duration: uint,                         ;; Lock duration in blocks
    start-block: uint,                           ;; When staking started
    end-block: uint,                             ;; When staking ends
    yield-rate: uint,                            ;; Current yield rate (basis points)
    accumulated-rewards: uint,                    ;; Total rewards accumulated
    compound-frequency: uint,                     ;; Compound frequency (blocks)
    auto-compound: bool,                          ;; Whether to auto-compound
    stake-status: uint,                           ;; 1=active, 2=completed, 3=withdrawn
    lockup-tier: uint,                            ;; 1=basic, 2=enhanced, 3=premium, 4=elite
    special-privileges: (list 10 (string-ascii 50)),
    visual-tier: uint,                            ;; Visual appearance tier
    governance-weight: uint,                      ;; Enhanced governance weight
    revenue-share: uint,                          ;; Revenue sharing percentage
    last-compound-block: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; Yield farming positions
(define-map yield-farms
  { farm-id: uint }
  {
    farmer: principal,
    farm-type: uint,                             ;; 1=single, 2=lp, 3=multi
    staked-assets: (list 5 { token: principal, amount: uint }), ;; Staked assets
    farm-contract: principal,                    ;; Farm contract address
    start-block: uint,
    end-block: uint,
    yield-rates: (list 5 uint),                  ;; Yield rates per asset
    accumulated-yields: (list 5 uint),           ;; Accumulated yields per asset
    farm-status: uint,                           ;; 1=active, 2=completed, 3=emergency
    farm-tier: uint,                              ;; 1=basic, 2=advanced, 3=expert, 4=master
    bonus-multipliers: (list 5 uint),             ;; Bonus multipliers per asset
    special-permissions: (list 10 (string-ascii 50)),
    visual-effects: (list 5 (string-ascii 30)),
    governance-weight: uint,
    revenue-share: uint,
    nft-token-id: uint,                          ;; Associated NFT
    last-harvest-block: uint,
    creation-block: uint
  })

;; Reward tier achievements
(define-map reward-tiers
  { token-id: uint }
  {
    owner: principal,
    tier-level: uint,                            ;; 1-10 tier levels
    tier-name: (string-ascii 50),               ;; Tier name (e.g., "Bronze Farmer")
    requirements: (list 10 { type: uint, value: uint }), ;; Requirements to achieve
    benefits: (list 10 (string-ascii 50)),       ;; Benefits of this tier
    yield-bonus: uint,                           ;; Yield bonus percentage
    governance-bonus: uint,                      ;; Governance bonus percentage
    special-access: (list 5 (string-ascii 50)),   ;; Special access rights
    visual-tier: uint,                           ;; Visual appearance tier
    achievement-date: uint,                      ;; When tier was achieved
    progression-points: uint,                    ;; Points toward next tier
    nft-token-id: uint,                          ;; Associated NFT
    creation-block: uint
  })

;; Lockup bonus certificates
(define-map lockup-bonuses
  { token-id: uint }
  {
    owner: principal,
    original-stake-id: uint,                     ;; Original staking position
    lock-extension: uint,                         ;; Additional lock duration
    bonus-yield-rate: uint,                       ;; Bonus yield rate
    bonus-multiplier: uint,                       ;; Yield multiplier
    bonus-duration: uint,                         ;; How long bonus lasts
    bonus-status: uint,                           ;; 1=active, 2=expired, 3=claimed
    special-privileges: (list 5 (string-ascii 50)),
    visual-effects: (list 3 (string-ascii 30)),
    governance-weight: uint,
    revenue-share: uint,
    creation-block: uint,
    expiry-block: uint
  })

;; Compound reward multipliers
(define-map compound-rewards
  { token-id: uint }
  {
    owner: principal,
    stake-id: uint,                              ;; Associated staking position
    compound-count: uint,                        ;; Number of compounds
    compound-multiplier: uint,                    ;; Current multiplier
    max-multiplier: uint,                         ;; Maximum achievable multiplier
    next-compound-block: uint,                    ;; Next compound eligibility
    compound-history: (list 20 { block: uint, amount: uint, multiplier: uint }), ;; Compound history
    special-permissions: (list 5 (string-ascii 50)),
    visual-tier: uint,
    governance-weight: uint,
    revenue-share: uint,
    creation-block: uint,
    last-compound-block: uint
  })

;; User staking profiles
(define-map user-staking-profiles
  { user: principal }
  {
    total-staked: uint,                           ;; Total amount staked
    total-earned: uint,                           ;; Total rewards earned
    active-positions: uint,                       ;; Number of active positions
    completed-positions: uint,                    ;; Number of completed positions
    average-lock-duration: uint,                  ;; Average lock duration
    highest-tier-achieved: uint,                  ;; Highest reward tier achieved
    staking-reputation: uint,                      ;; 0-10000 reputation score
    special-privileges: (list 15 (string-ascii 50)),
    preferred-lock-durations: (list 5 uint),      ;; Preferred lock durations
    auto-compound-settings: (list 5 bool),       ;; Auto-compound settings per position
    governance-weight-multiplier: uint,           ;; Governance weight multiplier
    revenue-share-tier: uint,                      ;; Revenue share tier
    last-activity-block: uint
  })

;; Staking pool configurations
(define-map staking-pools
  { pool-id: uint }
  {
    pool-name: (string-ascii 50),
    staking-token: principal,                     ;; Token that can be staked
    base-yield-rate: uint,                        ;; Base yield rate
    minimum-stake: uint,                          ;; Minimum stake amount
    maximum-stake: uint,                          ;; Maximum stake amount
    minimum-lock: uint,                          ;; Minimum lock duration
    maximum-lock: uint,                          ;; Maximum lock duration
    pool-status: uint,                            ;; 1=active, 2=paused, 3=closed
    total-staked: uint,                           ;; Total staked in pool
    pool-tiers: (list 5 { threshold: uint, bonus: uint }), ;; Tier thresholds and bonuses
    special-features: (list 10 (string-ascii 50)), ;; Special features
    creation-block: uint,
    last-update-block: uint
  })

;; ===== Public Functions =====

;; @desc Creates a new staking position NFT
;; @param stake-amount The amount to stake
;; @param stake-token The token being staked
;; @param lock-duration The lock duration in blocks
;; @param auto-compound Whether to auto-compound rewards
;; @param compound-frequency Compound frequency in blocks
;; @returns Response with new token ID or error
(define-public (create-staking-position-nft
  (stake-amount uint)
  (stake-token <sip-010-ft-trait>)
  (lock-duration uint)
  (auto-compound bool)
  (compound-frequency uint))
  (begin
    (asserts! (and (>= stake-amount MIN_STAKE_AMOUNT) (<= stake-amount MAX_STAKE_AMOUNT)) ERR_INVALID_STAKE)
    (asserts! (and (>= lock-duration MIN_LOCK_DURATION) (<= lock-duration MAX_LOCK_DURATION)) ERR_INVALID_STAKE)
    (asserts! (> compound-frequency u0) ERR_INVALID_STAKE)
    
    ;; Transfer staking tokens to contract
    ;; (try! (contract-call? stake-token transfer-from tx-sender (as-contract tx-sender) stake-amount))
    
    (let ((token-id (var-get next-token-id))
          (stake-principal (contract-of stake-token))
          (end-block (+ block-height lock-duration))
          (yield-rate (calculate-staking-yield-rate stake-amount lock-duration))
          (lockup-tier (calculate-lockup-tier stake-amount lock-duration)))
      
      ;; Create staking position
      (map-set staking-positions
        { token-id: token-id }
        {
          owner: tx-sender,
          stake-amount: stake-amount,
          stake-token: stake-principal,
          lock-duration: lock-duration,
          start-block: block-height,
          end-block: end-block,
          yield-rate: yield-rate,
          accumulated-rewards: u0,
          compound-frequency: compound-frequency,
          auto-compound: auto-compound,
          stake-status: u1, ;; Active
          lockup-tier: lockup-tier,
          special-privileges: (get-staking-privileges lockup-tier),
          visual-tier: (calculate-staking-visual-tier stake-amount lockup-tier),
          governance-weight: (calculate-staking-governance-weight stake-amount lockup-tier),
          revenue-share: (calculate-staking-revenue-share lockup-tier),
          last-compound-block: block-height,
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update user staking profile
      (update-user-staking-profile tx-sender stake-amount u0)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "staking-position-nft-created",
        token-id: token-id,
        owner: tx-sender,
        stake-amount: stake-amount,
        stake-token: stake-principal,
        lock-duration: lock-duration,
        end-block: end-block,
        yield-rate: yield-rate,
        lockup-tier: lockup-tier
      })
      
      (ok token-id)
    )
  )
)

;; @desc Creates a new yield farming position NFT
;; @param farm-type The farm type (1=single, 2=lp, 3=multi)
;; @param staked-assets List of staked assets
;; @param farm-contract The farm contract address
;; @param duration The farming duration in blocks
;; @returns Response with farm ID and NFT token ID or error
(define-public (create-yield-farm-nft
  (farm-type uint)
  (staked-assets (list 5 { token: principal, amount: uint }))
  (farm-contract principal)
  (duration uint))
  (begin
    (asserts! (and (>= farm-type u1) (<= farm-type u3)) ERR_INVALID_FARM)
    (asserts! (> duration u0) ERR_INVALID_FARM)
    (asserts! (is-valid-staked-assets staked-assets) ERR_INVALID_STAKE)
    
    ;; Verify farm contract is active
    (asserts! (is-farm-contract-active farm-contract) ERR_FARM_NOT_ACTIVE)
    
    (let ((farm-id (var-get next-farm-id))
          (token-id (var-get next-token-id))
          (end-block (+ block-height duration))
          (yield-rates (calculate-farm-yield-rates staked-assets farm-type))
          (farm-tier (calculate-farm-tier staked-assets duration)))
      
      ;; Create yield farm
      (map-set yield-farms
        { farm-id: farm-id }
        {
          farmer: tx-sender,
          farm-type: farm-type,
          staked-assets: staked-assets,
          farm-contract: farm-contract,
          start-block: block-height,
          end-block: end-block,
          yield-rates: yield-rates,
          accumulated-yields: (list u0 u0 u0 u0 u0), ;; Initialize with zeros
          farm-status: u1, ;; Active
          farm-tier: farm-tier,
          bonus-multipliers: (calculate-farm-bonuses farm-tier),
          special-permissions: (get-farm-privileges farm-tier),
          visual-effects: (get-farm-visual-effects farm-tier),
          governance-weight: (calculate-farm-governance-weight staked-assets farm-tier),
          revenue-share: (calculate-farm-revenue-share farm-tier),
          nft-token-id: token-id,
          last-harvest-block: block-height,
          creation-block: block-height
        })
      
      ;; Create associated NFT
      (map-set staking-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_YIELD_FARM,
          stake-id: none,
          farm-id: (some farm-id),
          reward-tier-id: none,
          lockup-bonus-id: none,
          compound-reward-id: none,
          staking-weight: (calculate-total-stake-weight staked-assets),
          yield-bonus: (calculate-total-yield-bonus yield-rates),
          visual-tier: farm-tier,
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update user staking profile
      (update-user-staking-profile-on-farm tx-sender staked-assets)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-farm-id (+ farm-id u1))
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "yield-farm-nft-created",
        farm-id: farm-id,
        token-id: token-id,
        farmer: tx-sender,
        farm-type: farm-type,
        staked-assets: staked-assets,
        end-block: end-block,
        farm-tier: farm-tier
      })
      
      (ok { farm-id: farm-id, token-id: token-id })
    )
  )
)

;; @desc Creates a reward tier achievement NFT
;; @param tier-level The tier level (1-10)
;; @param tier-name The tier name
;; @param requirements Requirements to achieve this tier
;; @param benefits Benefits of this tier
;; @returns Response with new token ID or error
(define-public (create-reward-tier-nft
  (tier-level uint)
  (tier-name (string-ascii 50))
  (requirements (list 10 { type: uint, value: uint }))
  (benefits (list 10 (string-ascii 50))))
  (begin
    (asserts! (and (>= tier-level u1) (<= tier-level u10)) ERR_INVALID_STAKE)
    (asserts! (meets-tier-requirements tx-sender requirements) ERR_INVALID_STAKE)
    
    (let ((token-id (var-get next-token-id)))
      
      ;; Create reward tier
      (map-set reward-tiers
        { token-id: token-id }
        {
          owner: tx-sender,
          tier-level: tier-level,
          tier-name: tier-name,
          requirements: requirements,
          benefits: benefits,
          yield-bonus: (calculate-tier-yield-bonus tier-level),
          governance-bonus: (calculate-tier-governance-bonus tier-level),
          special-access: (get-tier-special-access tier-level),
          visual-tier: tier-level,
          achievement-date: block-height,
          progression-points: u0,
          nft-token-id: token-id,
          creation-block: block-height
        })
      
      ;; Update user staking profile
      (update-user-staking-profile-on-tier tx-sender tier-level)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "reward-tier-nft-created",
        token-id: token-id,
        owner: tx-sender,
        tier-level: tier-level,
        tier-name: tier-name,
        achievement-date: block-height
      })
      
      (ok token-id)
    )
  )
)

;; @desc Creates a lockup bonus certificate NFT
;; @param original-stake-id The original staking position token ID
;; @param lock-extension Additional lock duration
;; @param bonus-yield-rate Bonus yield rate
;; @returns Response with new token ID or error
(define-public (create-lockup-bonus-nft
  (original-stake-id uint)
  (lock-extension uint)
  (bonus-yield-rate uint))
  (begin
    (let ((stake-position (unwrap! (map-get? staking-positions { token-id: original-stake-id }) ERR_STAKE_NOT_FOUND)))
      (asserts! (is-eq tx-sender (get owner stake-position)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get stake-status stake-position) u1) ERR_STAKE_LOCKED) ;; Must be active
      (asserts! (> lock-extension u0) ERR_INVALID_STAKE)
      
      (let ((token-id (var-get next-token-id))
            (bonus-multiplier (calculate-lockup-bonus-multiplier lock-extension))
            (bonus-duration (+ (get end-block stake-position) lock-extension))
            (expiry-block (+ block-height lock-extension)))
        
        ;; Create lockup bonus certificate
        (map-set lockup-bonuses
          { token-id: token-id }
          {
            owner: tx-sender,
            original-stake-id: original-stake-id,
            lock-extension: lock-extension,
            bonus-yield-rate: bonus-yield-rate,
            bonus-multiplier: bonus-multiplier,
            bonus-duration: bonus-duration,
            bonus-status: u1, ;; Active
            special-privileges: (get-lockup-privileges bonus-multiplier),
            visual-effects: (get-lockup-visual-effects bonus-multiplier),
            governance-weight: (calculate-lockup-governance-weight bonus-multiplier),
            revenue-share: (calculate-lockup-revenue-share bonus-multiplier),
            creation-block: block-height,
            expiry-block: expiry-block
          })
        
        ;; Update original staking position with extended lock
        (map-set staking-positions
          { token-id: original-stake-id }
          (merge stake-position {
            end-block: bonus-duration,
            yield-rate: (+ (get yield-rate stake-position) bonus-yield-rate)
          }))
        
        ;; Mint NFT
        (mint-nft token-id tx-sender)
        
        (var-set next-token-id (+ token-id u1))
        
        (print {
          event: "lockup-bonus-nft-created",
          token-id: token-id,
          owner: tx-sender,
          original-stake-id: original-stake-id,
          lock-extension: lock-extension,
          bonus-yield-rate: bonus-yield-rate,
          bonus-multiplier: bonus-multiplier,
          new-end-block: bonus-duration
        })
        
        (ok token-id)
      )
    )
  )
)

;; @desc Creates a compound reward multiplier NFT
;; @param stake-id The associated staking position token ID
;; @param compound-count Number of compounds completed
;; @returns Response with new token ID or error
(define-public (create-compound-reward-nft (stake-id uint) (compound-count uint))
  (let ((stake-position (unwrap! (map-get? staking-positions { token-id: stake-id }) ERR_STAKE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner stake-position)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get stake-status stake-position) u1) ERR_STAKE_LOCKED) ;; Must be active
    (asserts! (> compound-count u0) ERR_INVALID_STAKE)
    
    (let ((token-id (var-get next-token-id))
          (compound-multiplier (calculate-compound-multiplier compound-count))
          (max-multiplier (calculate-max-compound-multiplier stake-position)))
      
      ;; Create compound reward
      (map-set compound-rewards
        { token-id: token-id }
        {
          owner: tx-sender,
          stake-id: stake-id,
          compound-count: compound_count,
          compound-multiplier: compound-multiplier,
          max-multiplier: max-multiplier,
          next-compound-block: (+ block-height (get compound-frequency stake-position)),
          compound-history: (list { block: block-height, amount: (get accumulated-rewards stake-position), multiplier: compound-multiplier }),
          special-permissions: (get-compound-privileges compound-multiplier),
          visual-tier: (calculate-compound-visual-tier compound-multiplier),
          governance-weight: (calculate-compound-governance-weight compound-multiplier),
          revenue-share: (calculate-compound-revenue-share compound-multiplier),
          creation-block: block-height,
          last-compound-block: block-height
        })
      
      ;; Update staking position with compound multiplier
      (map-set staking-positions
        { token-id: stake_id }
        (merge stake-position {
          yield-rate: (* (get yield-rate stake-position) compound-multiplier)
        }))
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "compound-reward-nft-created",
        token-id: token-id,
        owner: tx-sender,
        stake-id: stake_id,
        compound-count: compound_count,
        compound-multiplier: compound-multiplier,
        new-yield-rate: (* (get yield-rate stake-position) compound-multiplier)
      })
      
      (ok token-id)
    )
  )
)

;; @desc Harvests rewards from a staking position
;; @param token-id The staking position token ID
;; @returns Response with reward amount or error
(define-public (harvest-staking-rewards (token-id uint))
  (let ((stake-position (unwrap! (map-get? staking-positions { token-id: token-id }) ERR_STAKE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner stake-position)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get stake-status stake-position) u1) ERR_STAKE_LOCKED) ;; Must be active
    
    (let ((current-rewards (calculate-current-rewards stake-position)))
      (asserts! (> current-rewards u0) ERR_INSUFFICIENT_REWARDS)
      
      ;; Update accumulated rewards
      (map-set staking-positions
        { token-id: token-id }
        (merge stake-position {
          accumulated-rewards: (+ (get accumulated-rewards stake-position) current-rewards),
          last-compound-block: block-height
        }))
      
      ;; Update user profile
      (update-user-staking-profile-on-harvest tx-sender current-rewards)
      
      ;; Transfer rewards (in real implementation)
      ;; (try! (contract-call? reward-token transfer (as-contract tx-sender) tx-sender current-rewards))
      
      (print {
        event: "staking-rewards-harvested",
        token-id: token-id,
        owner: tx-sender,
        reward-amount: current-rewards,
        total-accumulated: (+ (get accumulated-rewards stake-position) current-rewards)
      })
      
      (ok current-rewards)
    )
  )
)

;; @desc Withdraws from a staking position
;; @param token-id The staking position token ID
;; @returns Response with withdrawn amount and rewards or error
(define-public (withdraw-staking-position (token-id uint))
  (let ((stake-position (unwrap! (map-get? staking-positions { token-id: token-id }) ERR_STAKE_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner stake-position)) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get end-block stake-position)) ERR_STAKE_LOCKED) ;; Must be unlocked
    (asserts! (is-eq (get stake-status stake_position) u1) ERR_STAKE_LOCKED) ;; Must be active
    
    (let ((current-rewards (calculate-current-rewards stake-position))
          (total-withdrawal (+ (get stake-amount stake-position) current-rewards)))
      
      ;; Update position status
      (map-set staking-positions
        { token-id: token-id }
        (merge stake-position {
          stake-status: u3, ;; Withdrawn
          last-activity-block: block-height
        }))
      
      ;; Update user profile
      (update-user-staking-profile-on_withdraw tx-sender (get stake-amount stake-position) current-rewards)
      
      ;; Transfer stake and rewards (in real implementation)
      ;; (try! (contract-call? stake-token transfer (as-contract tx-sender) tx-sender (get stake-amount stake-position)))
      ;; (try! (contract-call? reward-token transfer (as-contract tx-sender) tx-sender current-rewards))
      
      (print {
        event: "staking-position-withdrawn",
        token-id: token-id,
        owner: tx-sender,
        stake-amount: (get stake-amount stake-position),
        reward-amount: current-rewards,
        total-withdrawal: total-withdrawal
      })
      
      (ok { stake-amount: (get stake-amount stake-position), reward-amount: current-rewards })
    )
  )
)

;; ===== SIP-009 Implementation =====

(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (var-get base-token-uri)))

(define-read-only (get-owner (token-id uint))
  (ok (map-get? staking-nft-metadata { token-id: token-id })))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((nft-data (unwrap! (map-get? staking-nft-metadata { token-id: token-id }) ERR_POSITION_NOT_FOUND)))
    (asserts! (is-eq sender (get owner nft-data)) ERR_UNAUTHORIZED)
    
    ;; Transfer NFT ownership
    (nft-transfer? staking-nft token-id sender recipient)
    
    ;; Update metadata
    (map-set staking-nft-metadata
      { token-id: token-id }
      (merge nft-data { owner: recipient, last-activity-block: block-height }))
    
    ;; Handle specific NFT type transfers
    (match (get nft-type nft-data)
      nft-type
        (handle-staking-nft-transfer token-id nft-type sender recipient)
      error-response
        (ok true))
    
    (print {
      event: "staking-nft-transferred",
      token-id: token-id,
      from: sender,
      to: recipient,
      nft-type: (get nft-type nft-data)
    })
    
    (ok true)
  )
)

;; ===== Staking NFT Metadata =====

(define-map staking-nft-metadata
  { token-id: uint }
  {
    owner: principal,
    nft-type: uint,
    stake-id: (optional uint),
    farm-id: (optional uint),
    reward-tier-id: (optional uint),
    lockup-bonus-id: (optional uint),
    compound-reward-id: (optional uint),
    staking-weight: uint,
    yield-bonus: uint,
    visual-tier: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; ===== Private Helper Functions =====

(define-private (mint-nft (token-id uint) (recipient principal))
  (nft-mint? staking-nft token-id recipient))

(define-private (calculate-staking-yield-rate (amount uint) (lock-duration uint))
  (let (
        (base-rate BASE_YIELD_RATE)
        (amount-bonus
          (cond
            ((>= amount u100000000) u200) ;; 2% bonus for large stakes
            ((>= amount u10000000) u100)  ;; 1% bonus for medium stakes
            (true u0)))                   ;; No bonus for small stakes
        (lock-bonus
          (cond
            ((>= lock-duration BLOCKS_PER_YEAR) u300)      ;; 3% bonus for >1 year locks
            ((>= lock-duration BLOCKS_PER_MONTH) u150)     ;; 1.5% bonus for >1 month locks
            (true u50)))                                   ;; 0.5% bonus for short locks
       )
    (+ base-rate amount-bonus lock-bonus)))

(define-private (calculate-lockup-tier (amount uint) (lock-duration uint))
  (cond
    ((and (>= amount u50000000) (>= lock-duration BLOCKS_PER_YEAR)) u4)    ;; Elite: >50 STX & >1 Year
    ((and (>= amount u10000000) (>= lock-duration BLOCKS_PER_MONTH)) u3)   ;; Premium: >10 STX & >1 Month
    ((and (>= amount u1000000) (>= lock-duration u120960)) u2)             ;; Enhanced: >1 STX & >1 Week (7 days)
    (true u1)))                                                            ;; Basic

(define-private (calculate-staking-visual-tier (amount uint) (lockup-tier uint))
  (cond
    ((>= amount u100000000) u5) ;; Legendary - golden animated
    ((>= amount u10000000) u4)  ;; Epic - silver glowing
    ((>= amount u1000000) u3)   ;; Rare - bronze special
    (true u2)))                   ;; Common - standard

(define-private (calculate-staking-governance-weight (amount uint) (lockup-tier uint))
  (let ((base-weight (/ amount u1000000))) ;; 1 weight per 1 STX
    (* base-weight (match lockup-tier
                     u4 u2000 ;; 2x for elite
                     u3 u1500 ;; 1.5x for premium
                     u2 u1200 ;; 1.2x for enhanced
                     u1 u1000)))) ;; 1x for basic

(define-private (calculate-staking-revenue-share (lockup-tier uint))
  (match lockup-tier
    u4 u500 ;; 5% for elite
    u3 u300 ;; 3% for premium
    u2 u200 ;; 2% for enhanced
    u1 u100)) ;; 1% for basic

(define-private (get-staking-privileges (lockup-tier uint))
  (match lockup-tier
    u4 (list "elite-staking" "priority-support" "enhanced-yield" "exclusive-access")
    u3 (list "premium-staking" "priority-yield" "enhanced-support")
    u2 (list "enhanced-staking" "improved-yield" "standard-support")
    u1 (list "basic-staking" "standard-yield")))

(define-private (calculate-farm-yield-rates (assets (list 5 { token: principal, amount: uint })) (farm-type uint))
  (map (lambda (asset) (+ BASE_YIELD_RATE (calculate-asset-yield-bonus (get token asset) (get amount asset)))) assets))

(define-private (calculate-asset-yield-bonus (token principal) (amount uint))
  (cond
    ((>= amount u50000000) u400) ;; 4% bonus for large amounts
    ((>= amount u10000000) u200) ;; 2% bonus for medium amounts
    ((>= amount u1000000) u100)  ;; 1% bonus for small amounts
    (true u0)))                   ;; No bonus

(define-private (calculate-farm-tier (assets (list 5 { token: principal, amount: uint })) (duration uint))
  (let ((total-value (fold (lambda (asset acc) (+ acc (get amount asset))) assets u0)))
    (cond
      ((and (>= total-value u100000000) (>= duration BLOCKS_PER_YEAR)) u4) ;; Master: >1 Year
      ((and (>= total-value u10000000) (>= duration BLOCKS_PER_MONTH)) u3) ;; Expert: >1 Month
      ((and (>= total-value u1000000) (>= duration u120960)) u2)           ;; Advanced: >1 Week
      (true u1))))                                                         ;; Basic

(define-private (get-farm-privileges (farm-tier uint))
  (match farm-tier
    u4 (list "master-farming" "maximum-yield" "priority-harvest" "exclusive-pools")
    u3 (list "expert-farming" "enhanced-yield" "priority-access")
    u2 (list "advanced-farming" "improved-yield" "standard-pools")
    u1 (list "basic-farming" "standard-yield" "public-pools")))

(define-private (get-farm-visual-effects (farm-tier uint))
  (match farm-tier
    u4 (list "rainbow-border" "star-animation" "harvest-effect" "master-glow")
    u3 (list "gold-border" "pulse-animation" "harvest-effect")
    u2 (list "silver-border" "glow-animation" "harvest-effect")
    u1 (list "bronze-border" "shimmer-animation")))

(define-private (calculate-farm-governance-weight (assets (list 5 { token: principal, amount: uint })) (farm-tier uint))
  (let ((base-weight (/ (fold (lambda (asset acc) (+ acc (get amount asset))) assets u0) u1000000)))
    (* base-weight (match farm-tier
                     u4 u2500 ;; 2.5x for master
                     u3 u1800 ;; 1.8x for expert
                     u2 u1300 ;; 1.3x for advanced
                     u1 u1000)))) ;; 1x for basic

(define-private (calculate-farm-revenue-share (farm-tier uint))
  (match farm-tier
    u4 u600 ;; 6% for master
    u3 u400 ;; 4% for expert
    u2 u250 ;; 2.5% for advanced
    u1 u150)) ;; 1.5% for basic

(define-private (calculate-total-stake-weight (assets (list 5 { token: principal, amount: uint })))
  (fold (lambda (asset acc) (+ acc (get amount asset))) assets u0))

(define-private (calculate-total-yield-bonus (rates (list 5 uint)))
  (fold (lambda (rate acc) (+ acc rate)) rates u0))

(define-private (calculate-tier-yield-bonus (tier-level uint))
  (cond
    ((>= tier-level u8) u800)  ;; 8% bonus for tier 8+
    ((>= tier-level u6) u600)  ;; 6% bonus for tier 6-7
    ((>= tier-level u4) u400)  ;; 4% bonus for tier 4-5
    ((>= tier-level u2) u200)  ;; 2% bonus for tier 2-3
    (true u100)))               ;; 1% bonus for tier 1

(define-private (calculate-tier-governance-bonus (tier-level uint))
  (cond
    ((>= tier-level u8) u3000) ;; 3x bonus for tier 8+
    ((>= tier-level u6) u2000) ;; 2x bonus for tier 6-7
    ((>= tier-level u4) u1500) ;; 1.5x bonus for tier 4-5
    ((>= tier-level u2) u1200) ;; 1.2x bonus for tier 2-3
    (true u1000)))               ;; 1x bonus for tier 1

(define-private (get-tier-special-access (tier-level uint))
  (cond
    ((is-eq tier-level u10) (list "legendary-access" "exclusive-pools" "priority-everything"))
    ((is-eq tier-level u8) (list "elite-access" "exclusive-pools" "priority-harvest"))
    ((is-eq tier-level u6) (list "advanced-access" "priority-pools"))
    ((is-eq tier-level u4) (list "enhanced-access" "standard-pools"))
    ((is-eq tier-level u2) (list "basic-access" "public-pools"))
    (true (list "limited-access"))))

(define-private (calculate-lockup-bonus-multiplier (lock-extension uint))
  (cond
    ((>= lock-extension u50000) u2000) ;; 2x for very long extensions
    ((>= lock-extension u10000) u1500) ;; 1.5x for long extensions
    ((>= lock-extension u1000) u1200)  ;; 1.2x for medium extensions
    (true u1000)))                       ;; 1x for short extensions

(define-private (get-lockup-privileges (multiplier uint))
  (cond
    ((>= multiplier u2000) (list "maximum-bonus" "priority-compound" "enhanced-yield"))
    ((>= multiplier u1500) (list "high-bonus" "priority-compound"))
    ((>= multiplier u1200) (list "medium-bonus" "standard-compound"))
    (true (list "basic-bonus"))))

(define-private (get-lockup-visual-effects (multiplier uint))
  (cond
    ((>= multiplier u2000) (list "rainbow-border" "star-animation" "bonus-effect"))
    ((>= multiplier u1500) (list "gold-border" "pulse-animation" "bonus-effect"))
    ((>= multiplier u1200) (list "silver-border" "glow-animation"))
    (true (list "bronze-border" "shimmer-animation"))))

(define-private (calculate-lockup-governance-weight (multiplier uint))
  (cond
    ((>= multiplier u2000) u2500) ;; 2.5x for maximum bonus
    ((>= multiplier u1500) u1800) ;; 1.8x for high bonus
    ((>= multiplier u1200) u1300) ;; 1.3x for medium bonus
    (true u1000)))                 ;; 1x for basic bonus

(define-private (calculate-lockup-revenue-share (multiplier uint))
  (cond
    ((>= multiplier u2000) u700) ;; 7% for maximum bonus
    ((>= multiplier u1500) u500) ;; 5% for high bonus
    ((>= multiplier u1200) u300) ;; 3% for medium bonus
    (true u200)))                 ;; 2% for basic bonus

(define-private (calculate-compound-multiplier (compound-count uint))
  (cond
    ((>= compound-count u20) u2000) ;; 2x for 20+ compounds
    ((>= compound-count u10) u1500) ;; 1.5x for 10-19 compounds
    ((>= compound-count u5) u1200)  ;; 1.2x for 5-9 compounds
    (true u1000)))                  ;; 1x for <5 compounds

(define-private (calculate-max-compound-multiplier (stake-position { token-id: uint, owner: principal, stake-amount: uint, stake-token: principal, lock-duration: uint, start-block: uint, end-block: uint, yield-rate: uint, accumulated-rewards: uint, compound-frequency: uint, auto-compound: bool, stake-status: uint, lockup-tier: uint, special-privileges: (list 10 (string-ascii 50)), visual-tier: uint, governance-weight: uint, revenue-share: uint, last-compound-block: uint, creation-block: uint, last-activity-block: uint }))
  (match (get lockup-tier stake-position)
    u4 u3000 ;; 3x max for elite
    u3 u2500 ;; 2.5x max for premium
    u2 u2000 ;; 2x max for enhanced
    u1 u1500)) ;; 1.5x max for basic

(define-private (get-compound-privileges (multiplier uint))
  (cond
    ((>= multiplier u2000) (list "maximum-compound" "auto-priority" "enhanced-yield"))
    ((>= multiplier u1500) (list "high-compound" "priority-compound"))
    ((>= multiplier u1200) (list "medium-compound" "standard-compound"))
    (true (list "basic-compound"))))

(define-private (calculate-compound-visual-tier (multiplier uint))
  (cond
    ((>= multiplier u2000) u5) ;; Legendary
    ((>= multiplier u1500) u4) ;; Epic
    ((>= multiplier u1200) u3) ;; Rare
    (true u2)))                 ;; Common

(define-private (calculate-compound-governance-weight (multiplier uint))
  (cond
    ((>= multiplier u2000) u2800) ;; 2.8x for maximum
    ((>= multiplier u1500) u2000) ;; 2x for high
    ((>= multiplier u1200) u1500) ;; 1.5x for medium
    (true u1200)))                 ;; 1.2x for basic

(define-private (calculate-compound-revenue-share (multiplier uint))
  (cond
    ((>= multiplier u2000) u800) ;; 8% for maximum
    ((>= multiplier u1500) u600) ;; 6% for high
    ((>= multiplier u1200) u400) ;; 4% for medium
    (true u300)))                 ;; 3% for basic

(define-private (calculate-current-rewards (stake-position { token-id: uint, owner: principal, stake-amount: uint, stake-token: principal, lock-duration: uint, start-block: uint, end-block: uint, yield-rate: uint, accumulated-rewards: uint, compound-frequency: uint, auto-compound: bool, stake-status: uint, lockup-tier: uint, special-privileges: (list 10 (string-ascii 50)), visual-tier: uint, governance-weight: uint, revenue-share: uint, last-compound-block: uint, creation-block: uint, last-activity-block: uint }))
  (let ((blocks-passed (- block-height (get last-compound-block stake-position)))
        (rate-per-block (/ (get yield-rate stake-position) u10000)))
    (* (get stake-amount stake-position) blocks-passed rate-per-block)))

(define-private (is-valid-staked-assets (assets (list 5 { token: principal, amount: uint })))
  (fold (lambda (asset acc) (and acc (> (get amount asset) u0))) assets true))

(define-private (is-farm-contract-active (farm-contract principal))
  ;; Check if farm contract is active
  true) ;; Simplified for now

(define-private (meets-tier-requirements (user principal) (requirements (list 10 { type: uint, value: uint })))
  ;; Check if user meets tier requirements
  true) ;; Simplified for now

(define-private (update-user-staking-profile (user principal) (stake-amount uint) (earned-amount uint))
  (let ((profile (default-to { total-staked: u0, total-earned: u0, active-positions: u0, completed-positions: u0, average-lock-duration: u0, highest-tier-achieved: u1, staking-reputation: u5000, special-privileges: (list), preferred-lock-durations: (list), auto-compound-settings: (list), governance-weight-multiplier: u1000, revenue-share-tier: u1, last-activity-block: u0 } (map-get? user-staking-profiles { user: user }))))
    (map-set user-staking-profiles
      { user: user }
      (merge profile {
        total-staked: (+ (get total-staked profile) stake-amount),
        total-earned: (+ (get total-earned profile) earned-amount),
        active-positions: (+ (get active-positions profile) u1),
        staking-reputation: (+ (get staking-reputation profile) u100), ;; +1% per stake
        last-activity-block: block-height
      }))))

(define-private (update-user-staking-profile-on-farm (user principal) (assets (list 5 { token: principal, amount: uint })))
  (let ((profile (default-to { total-staked: u0, total-earned: u0, active-positions: u0, completed-positions: u0, average-lock-duration: u0, highest-tier-achieved: u1, staking-reputation: u5000, special-privileges: (list), preferred-lock-durations: (list), auto-compound-settings: (list), governance-weight-multiplier: u1000, revenue-share-tier: u1, last-activity-block: u0 } (map-get? user-staking-profiles { user: user }))))
    (map-set user-staking-profiles
      { user: user }
      (merge profile {
        active-positions: (+ (get active-positions profile) u1),
        staking-reputation: (+ (get staking-reputation profile) u150), ;; +1.5% per farm
        last-activity-block: block-height
      }))))

(define-private (update-user-staking-profile-on-tier (user principal) (tier-level uint))
  (let ((profile (default-to { total-staked: u0, total-earned: u0, active-positions: u0, completed-positions: u0, average-lock-duration: u0, highest-tier-achieved: u1, staking-reputation: u5000, special-privileges: (list), preferred-lock-durations: (list), auto-compound-settings: (list), governance-weight-multiplier: u1000, revenue-share-tier: u1, last-activity-block: u0 } (map-get? user-staking-profiles { user: user }))))
    (map-set user-staking-profiles
      { user: user }
      (merge profile {
        highest-tier-achieved: (max (get highest-tier-achieved profile) tier-level),
        staking-reputation: (+ (get staking-reputation profile) (* tier-level u200)), ;; +2% per tier level
        last-activity-block: block-height
      }))))

(define-private (update-user-staking-profile-on_harvest (user principal) (reward-amount uint))
  (let ((profile (default-to { total-staked: u0, total-earned: u0, active-positions: u0, completed-positions: u0, average-lock-duration: u0, highest-tier-achieved: u1, staking-reputation: u5000, special-privileges: (list), preferred-lock-durations: (list), auto-compound-settings: (list), governance-weight-multiplier: u1000, revenue-share-tier: u1, last-activity-block: u0 } (map-get? user-staking-profiles { user: user }))))
    (map-set user-staking-profiles
      { user: user }
      (merge profile {
        total-earned: (+ (get total-earned profile) reward-amount),
        staking-reputation: (+ (get staking-reputation profile) u50), ;; +0.5% per harvest
        last-activity-block: block-height
      }))))

(define-private (update-user-staking-profile-on_withdraw (user principal) (stake-amount uint) (reward-amount uint))
  (let ((profile (default-to { total-staked: u0, total-earned: u0, active-positions: u0, completed-positions: u0, average-lock-duration: u0, highest-tier-achieved: u1, staking-reputation: u5000, special-privileges: (list), preferred-lock-durations: (list), auto-compound-settings: (list), governance-weight-multiplier: u1000, revenue-share-tier: u1, last-activity-block: u0 } (map-get? user-staking-profiles { user: user }))))
    (map-set user-staking-profiles
      { user: user }
      (merge profile {
        total-staked: (- (get total-staked profile) stake-amount),
        total-earned: (+ (get total-earned profile) reward-amount),
        active-positions: (- (get active-positions profile) u1),
        completed-positions: (+ (get completed-positions profile) u1),
        staking-reputation: (+ (get staking-reputation profile) u75), ;; +0.75% per withdrawal
        last-activity-block: block-height
      }))))

(define-private (handle-staking-nft-transfer (token-id uint) (nft-type uint) (from principal) (to principal))
  (match nft-type
    NFT_TYPE_STAKING_POSITION
      ;; Transfer staking position rights
      (map-set staking-positions
        { token-id: token-id }
        (merge (unwrap-panic (map-get? staking-positions { token-id: token-id })) { owner: to, last-activity-block: block-height }))
    NFT_TYPE_YIELD_FARM
      ;; Transfer farm rights
      (let ((farm-id (unwrap-panic (get farm-id (unwrap-panic (map-get? staking-nft-metadata { token-id: token-id }))))))
        (map-set yield-farms
          { farm-id: farm-id }
          (merge (unwrap-panic (map-get? yield-farms { farm-id: farm-id })) { farmer: to })))
    NFT_TYPE_REWARD_TIER
      ;; Transfer tier achievement
      (map-set reward-tiers
        { token-id: token-id }
        (merge (unwrap-panic (map-get? reward-tiers { token-id: token-id })) { owner: to }))
    NFT_TYPE_LOCKUP_BONUS
      ;; Transfer lockup bonus
      (map-set lockup-bonuses
        { token-id: token-id }
        (merge (unwrap-panic (map-get? lockup-bonuses { token-id: token-id })) { owner: to }))
    NFT_TYPE_COMPOUND_REWARD
      ;; Transfer compound reward
      (map-set compound-rewards
        { token-id: token-id }
        (merge (unwrap-panic (map-get? compound-rewards { token-id: token-id })) { owner: to }))
    else true)) ;; Other types transfer normally

;; ===== Read-Only Functions =====

(define-read-only (get-staking-position (token-id uint))
  (map-get? staking-positions { token-id: token-id }))

(define-read-only (get-yield-farm (farm-id uint))
  (map-get? yield-farms { farm-id: farm-id }))

(define-read-only (get-reward-tier (token-id uint))
  (map-get? reward-tiers { token-id: token-id }))

(define-read-only (get-lockup-bonus (token-id uint))
  (map-get? lockup-bonuses { token-id: token-id }))

(define-read-only (get-compound-reward (token-id uint))
  (map-get? compound-rewards { token-id: token-id }))

(define-read-only (get-user-staking-profile (user principal))
  (map-get? user-staking-profiles { user: user }))

(define-read-only (get-staking-pool (pool-id uint))
  (map-get? staking-pools { pool-id: pool-id }))

(define-read-only (get-staking-nft-metadata (token-id uint))
  (map-get? staking-nft-metadata { token-id: token-id }))

(define-read-only (get-user-staking-positions (user principal))
  ;; Return all staking positions owned by user
  (list))

(define-read-only (get-user-yield-farms (user principal))
  ;; Return all yield farms owned by user
  (list))

(define-read-only (get-user-reward-tiers (user principal))
  ;; Return all reward tiers owned by user
  (list))

(define-read-only (calculate-expected-rewards (token-id uint) (blocks-to-add uint))
  ;; Calculate expected rewards for additional blocks
  (let (
        (position (unwrap-panic (map-get? staking-positions { token-id: token-id })))
        (rate-per-block (/ (get yield-rate position) u10000))
        (total-rewards (* (get stake-amount position) blocks-to-add rate-per-block))
       )
    (ok total-rewards)))
