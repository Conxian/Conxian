;; enhanced-governance-nft.clar
;; Enhanced governance NFT system with proposal-specific voting rights,
;; delegation certificates, and reputation tracking

(use-trait sip-009-nft-trait .01-sip-standards.sip-009-nft-trait)
(use-trait sip-010-ft-trait .01-sip-standards.sip-010-ft-trait)

(impl-trait .01-sip-standards.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u9000))
(define-constant ERR_INVALID_PROPOSAL (err u9001))
(define-constant ERR_ALREADY_VOTED (err u9002))
(define-constant ERR_DELEGATION_EXPIRED (err u9003))
(define-constant ERR_INSUFFICIENT_WEIGHT (err u9004))
(define-constant ERR_REPUTATION_TOO_LOW (err u9005))

;; Governance NFT Types
(define-constant NFT_TYPE_PROPOSAL_VOTING u1)       ;; Proposal-specific voting rights
(define-constant NFT_TYPE_DELEGATION_CERT u2)        ;; Vote delegation certificate
(define-constant NFT_TYPE_REPUTATION_BADGE u3)       ;; Governance participation reputation
(define-constant NFT_TYPE_COUNCIL_MEMBER u4)         ;; Council membership NFT
(define-constant NFT_TYPE_VETO_POWER u5)              ;; Veto power certificate
(define-constant NFT_TYPE_QUORUM_BOOSTER u6)         ;; Quorum participation booster

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var next-delegation-id uint u1)
(define-data-var base-token-uri (optional (string-utf8 256)) none)

;; ===== NFT Definition =====
(define-non-fungible-token governance-nft uint)

;; ===== Enhanced Governance Data Structures =====

;; Proposal-specific voting NFTs
(define-map proposal-voting-nfts
  { token-id: uint }
  {
    owner: principal,
    proposal-id: uint,
    voting-weight: uint,                          ;; Enhanced voting weight
    vote-cast: (optional { vote: bool, voting-power: uint, vote-block: uint }),
    voting-deadline: uint,
    proposal-category: uint,                       ;; 1=protocol, 2=treasury, 3=governance, 4=security
    special-privileges: (list 10 (string-ascii 50)),
    reputation-boost: uint,                       ;; Reputation boost for participation
    visual-tier: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; Delegation certificates
(define-map delegation-certificates
  { delegation-id: uint }
  {
    delegator: principal,                          ;; Who is delegating
    delegatee: principal,                          ;; Who receives the vote
    voting-power: uint,                            ;; Amount of voting power delegated
    delegation-start: uint,                       ;; When delegation starts
    delegation-end: uint,                         ;; When delegation ends
    proposal-restrictions: (list 10 uint),        ;; Which proposal types can be voted on
    revocable: bool,                              ;; Can delegation be revoked early
    auto-renew: bool,                             ;; Auto-renew delegation
    fee-rate: uint,                               ;; Delegation fee rate
    nft-token-id: uint,                           ;; Associated NFT
    creation-block: uint
  })

;; Reputation badges
(define-map reputation-badges
  { token-id: uint }
  {
    owner: principal,
    reputation-score: uint,                       ;; 0-10000 reputation score
    participation-count: uint,                     ;; Number of proposals participated in
    voting-accuracy: uint,                         ;; Accuracy of voting (aligned with outcomes)
    expertise-areas: (list 5 (string-ascii 30)),   ;; Areas of expertise
    special-privileges: (list 10 (string-ascii 50)),
    visual-tier: uint,
    governance-weight-multiplier: uint,           ;; Multiplier for governance weight
    creation-block: uint,
    last-activity-block: uint
  })

;; Council membership NFTs
(define-map council-memberships
  { token-id: uint }
  {
    owner: principal,
    council-type: uint,                            ;; 1=core, 2=security, 3=treasury, 4=technical
    council-role: (string-ascii 50),               ;; Specific role within council
    voting-rights: (list 10 uint),                ;; Enhanced voting rights per category
    veto-power: uint,                             ;; Veto power strength
    veto-scope: (list 5 uint),                    ;; Which proposal types can be vetoed
    emergency-powers: (list 10 (string-ascii 50)), ;; Emergency powers
    term-start: uint,                             ;; Council term start
    term-end: uint,                               ;; Council term end
    responsibilities: (list 10 (string-ascii 50)),
    visual-tier: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; Veto power certificates
(define-map veto-certificates
  { token-id: uint }
  {
    owner: principal,
    veto-strength: uint,                          ;; Strength of veto power
    veto-scope: (list 5 uint),                    ;; Which proposal types can be vetoed
    veto-cooldown: uint,                          ;; Cooldown period between vetos
    remaining-vetoes: uint,                       ;; Remaining veto uses
    veto-conditions: (list 10 (string-ascii 50)), ;; Conditions for veto usage
    visual-tier: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; Quorum boosters
(define-map quorum-boosters
  { token-id: uint }
  {
    owner: principal,
    boost-amount: uint,                          ;; Quorum boost amount
    applicable-proposals: (list 10 uint),        ;; Proposal types this applies to
    boost-duration: uint,                        ;; How long boost lasts
    uses-remaining: uint,
    participation-reward: uint,                   ;; Reward for participation
    visual-tier: uint,
    creation-block: uint
  })

;; User governance profiles
(define-map user-governance-profiles
  { user: principal }
  {
    total-voting-weight: uint,
    base-voting-weight: uint,
    enhanced-weight-multiplier: uint,
    reputation-score: uint,
    participation-history: (list 100 { proposal-id: uint, vote: bool, block: uint }),
    council-memberships: (list 5 uint),          ;; Council NFT IDs
    delegation-history: (list 50 { delegator: principal, delegatee: principal, amount: uint, start: uint, end: uint }),
    reputation-tiers: (list 10 uint),             ;; Reputation badge NFT IDs
    emergency-contacts: (list 3 principal),
    last-activity-block: uint
  })

;; Governance NFT metadata
(define-map governance-nft-metadata
  { token-id: uint }
  {
    owner: principal,
    nft-type: uint,
    proposal-id: (optional uint),
    delegation-id: (optional uint),
    reputation-badge-id: (optional uint),
    council-membership-id: (optional uint),
    veto-certificate-id: (optional uint),
    quorum-booster-id: (optional uint),
    governance-weight: uint,
    visual-tier: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; ===== Public Functions =====

;; @desc Creates a new proposal-specific voting NFT
;; @param proposal-id The proposal ID this NFT is for
;; @param proposal-category The category of proposal (1=protocol, 2=treasury, 3=governance, 4=security)
;; @param voting-weight Enhanced voting weight for this proposal
;; @param voting-deadline When voting ends for this proposal
;; @param proposal-restrictions Any restrictions on voting
;; @returns Response with new token ID or error
(define-public (create-proposal-voting-nft
  (proposal-id uint)
  (proposal-category uint)
  (voting-weight uint)
  (voting-deadline uint)
  (proposal-restrictions (list 10 uint)))
  (begin
    (asserts! (and (>= proposal-category u1) (<= proposal-category u4)) ERR_INVALID_PROPOSAL)
    (asserts! (> voting-weight u0) ERR_INSUFFICIENT_WEIGHT)
    (asserts! (> voting-deadline block-height) ERR_INVALID_PROPOSAL)
    
    (let ((token-id (var-get next-token-id)))
      
      ;; Create proposal voting NFT
      (map-set proposal-voting-nfts
        { token-id: token-id }
        {
          owner: tx-sender,
          proposal-id: proposal-id,
          voting-weight: voting-weight,
          vote-cast: none,
          voting-deadline: voting-deadline,
          proposal-category: proposal-category,
          special-privileges: (get-proposal-privileges proposal-category),
          reputation-boost: (calculate-reputation-boost voting-weight),
          visual-tier: (calculate-voting-visual-tier voting-weight),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Create associated NFT metadata
      (map-set governance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_PROPOSAL_VOTING,
          proposal-id: (some proposal-id),
          delegation-id: none,
          reputation-badge-id: none,
          council-membership-id: none,
          veto-certificate-id: none,
          quorum-booster-id: none,
          governance-weight: voting-weight,
          visual-tier: (calculate-voting-visual-tier voting-weight),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update user governance profile
      (update-user-governance-profile tx-sender voting-weight u0)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "proposal-voting-nft-created",
        token-id: token-id,
        owner: tx-sender,
        proposal-id: proposal-id,
        proposal-category: proposal-category,
        voting-weight: voting-weight,
        voting-deadline: voting-deadline
      })
      
      (ok token-id)
    )
  )
)

;; @desc Creates a new delegation certificate NFT
;; @param delegatee Who receives the delegated voting power
;; @param voting-power Amount of voting power to delegate
;; @param delegation-end When delegation ends
;; @param proposal-restrictions Which proposal types can be voted on
;; @param revocable Whether delegation can be revoked early
;; @param auto-renew Whether to auto-renew delegation
;; @param fee-rate Delegation fee rate
;; @returns Response with new token ID and delegation ID or error
(define-public (create-delegation-certificate-nft
  (delegatee principal)
  (voting-power uint)
  (delegation-end uint)
  (proposal-restrictions (list 10 uint))
  (revocable bool)
  (auto-renew bool)
  (fee-rate uint))
  (begin
    (asserts! (> voting-power u0) ERR_INSUFFICIENT_WEIGHT)
    (asserts! (> delegation-end block-height) ERR_DELEGATION_EXPIRED)
    
    (let ((token-id (var-get next-token-id))
          (delegation-id (var-get next-delegation-id)))
      
      ;; Create delegation certificate
      (map-set delegation-certificates
        { delegation-id: delegation-id }
        {
          delegator: tx-sender,
          delegatee: delegatee,
          voting-power: voting-power,
          delegation-start: block-height,
          delegation-end: delegation-end,
          proposal-restrictions: proposal-restrictions,
          revocable: revocable,
          auto-renew: auto-renew,
          fee-rate: fee-rate,
          nft-token-id: token-id,
          creation-block: block-height
        })
      
      ;; Create associated NFT metadata
      (map-set governance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_DELEGATION_CERT,
          proposal-id: none,
          delegation-id: (some delegation-id),
          reputation-badge-id: none,
          council-membership-id: none,
          veto-certificate-id: none,
          quorum-booster-id: none,
          governance-weight: voting-power,
          visual-tier: (calculate-delegation-visual-tier voting-power),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update delegator profile (loses voting power temporarily)
      (update-user-governance-profile tx-sender u0 (- voting-power)) ;; Delegator loses weight
      
      ;; Update delegatee profile (gains voting power)
      (update-user-governance-profile delegatee voting-power u0)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      (var-set next-delegation-id (+ delegation-id u1))
      
      (print {
        event: "delegation-certificate-nft-created",
        token-id: token-id,
        delegation-id: delegation-id,
        delegator: tx-sender,
        delegatee: delegatee,
        voting-power: voting-power,
        delegation-end: delegation-end
      })
      
      (ok { token-id: token-id, delegation-id: delegation-id })
    )
  )
)

;; @desc Creates a new reputation badge NFT
;; @param reputation-score Initial reputation score
;; @param participation-count Number of proposals participated in
;; @param voting-accuracy Accuracy of voting
;; @param expertise-areas Areas of expertise
;; @returns Response with new token ID or error
(define-public (create-reputation-badge-nft
  (reputation-score uint)
  (participation-count uint)
  (voting-accuracy uint)
  (expertise-areas (list 5 (string-ascii 30))))
  (begin
    (asserts! (and (>= reputation-score u0) (<= reputation-score u10000)) ERR_REPUTATION_TOO_LOW)
    (asserts! (> participation-count u0) ERR_INSUFFICIENT_WEIGHT)
    
    (let ((token-id (var-get next-token-id))
          (reputation-tier (calculate-reputation-tier reputation-score)))
      
      ;; Create reputation badge
      (map-set reputation-badges
        { token-id: token-id }
        {
          owner: tx-sender,
          reputation-score: reputation-score,
          participation-count: participation-count,
          voting-accuracy: voting-accuracy,
          expertise-areas: expertise-areas,
          special-privileges: (get-reputation-privileges reputation-tier),
          visual-tier: reputation-tier,
          governance-weight-multiplier: (calculate-reputation-weight-multiplier reputation-tier),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Create associated NFT metadata
      (map-set governance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_REPUTATION_BADGE,
          proposal-id: none,
          delegation-id: none,
          reputation-badge-id: (some token-id),
          council-membership-id: none,
          veto-certificate-id: none,
          quorum-booster-id: none,
          governance-weight: (calculate-reputation-governance-weight reputation-score reputation-tier),
          visual-tier: reputation-tier,
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update user governance profile
      (update-user-governance-profile-on-reputation tx-sender reputation-score participation-count)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token-id u1))
      
      (print {
        event: "reputation-badge-nft-created",
        token-id: token-id,
        owner: tx-sender,
        reputation-score: reputation-score,
        reputation-tier: reputation-tier,
        participation-count: participation-count
      })
      
      (ok token-id)
    )
  )
)

;; @desc Casts a vote using a proposal voting NFT
;; @param token-id The proposal voting NFT token ID
;; @param vote The vote (true=support, false=oppose)
;; @returns Response with voting result or error
(define-public (cast-vote (token-id uint) (vote bool))
  (let ((voting-nft (unwrap! (map-get? proposal-voting-nfts { token-id: token-id }) ERR_INVALID_PROPOSAL)))
    (asserts! (is-eq tx-sender (get owner voting-nft)) ERR_UNAUTHORIZED)
    (asserts! (is-none (get vote-cast voting-nft)) ERR_ALREADY_VOTED)
    (asserts! (< block-height (get voting-deadline voting-nft)) ERR_INVALID_PROPOSAL)
    
    (let ((voting-power (get voting-weight voting-nft))
          (proposal-id (get proposal-id voting-nft)))
      
      ;; Record the vote
      (map-set proposal-voting-nfts
        { token-id: token-id }
        (merge voting-nft {
          vote-cast: (some { vote: vote, voting-power: voting-power, vote-block: block-height }),
          last-activity-block: block-height
        }))
      
      ;; Update user governance profile
      (update-user-governance-profile-on-vote tx-sender proposal-id vote)
      
      (print {
        event: "vote-cast",
        token-id: token-id,
        voter: tx-sender,
        proposal-id: proposal-id,
        vote: vote,
        voting-power: voting-power,
        vote-block: block-height
      })
      
      (ok { vote: vote, voting-power: voting-power })
    )
  )
)

;; @desc Revokes a delegation certificate
;; @param delegation-id The delegation ID to revoke
;; @returns Response with revocation result or error
(define-public (revoke-delegation (delegation-id uint))
  (let ((delegation (unwrap! (map-get? delegation-certificates { delegation-id: delegation-id }) ERR_DELEGATION_EXPIRED)))
    (asserts! (is-eq tx-sender (get delegator delegation)) ERR_UNAUTHORIZED)
    (asserts! (get revocable delegation) ERR_UNAUTHORIZED)
    
    ;; Calculate returned voting power
    (let ((returned-power (get voting-power delegation))
          (delegatee (get delegatee delegation)))
      
      ;; Remove delegation
      (map-delete delegation-certificates { delegation-id: delegation-id })
      
      ;; Update delegator profile (regains voting power)
      (update-user-governance-profile tx-sender returned-power u0)
      
      ;; Update delegatee profile (loses voting power)
      (update-user-governance-profile delegatee u0 (- (get voting-power delegation))) ;; Delegatee loses weight
      
      (print {
        event: "delegation-revoked",
        delegation-id: delegation-id,
        delegator: tx-sender,
        delegatee: delegatee,
        returned-voting-power: returned-power
      })
      
      (ok true)
    )
  )
)

;; ===== SIP-009 Implementation =====

(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (var-get base-token-uri)))

(define-read-only (get-owner (token-id uint))
  (ok (map-get? governance-nft-metadata { token-id: token-id })))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((nft-data (unwrap! (map-get? governance-nft-metadata { token-id: token-id }) ERR_UNAUTHORIZED)))
    (asserts! (is-eq sender (get owner nft-data)) ERR_UNAUTHORIZED)
    
    ;; Transfer NFT ownership
    (nft-transfer? governance-nft token-id sender recipient)
    
    ;; Update metadata
    (map-set governance-nft-metadata
      { token-id: token-id }
      (merge nft-data { owner: recipient, last-activity-block: block-height }))
    
    ;; Handle specific NFT type transfers
    (let ((nft-type (get nft-type nft-data)))
      (handle-governance-nft-transfer token-id nft-type sender recipient))
    
    (print {
      event: "governance-nft-transferred",
      token-id: token-id,
      from: sender,
      to: recipient,
      nft-type: (get nft-type nft-data)
    })
    
    (ok true)
  )
)

;; ===== Private Helper Functions =====

(define-private (mint-nft (token-id uint) (recipient principal))
  (nft-mint? governance-nft token-id recipient))

(define-private (handle-governance-nft-transfer (token-id uint) (nft-type uint) (sender principal) (recipient principal))
  (match nft-type
    NFT_TYPE_DELEGATION_CERT
      ;; Transfer delegation certificate
      (let ((delegation-id (unwrap-panic (get delegation-id (unwrap-panic (map-get? governance-nft-metadata { token-id: token-id })))))))
        (map-set delegation-certificates
          { delegation-id: delegation-id }
          { delegator: to, delegatee: (get delegatee (unwrap-panic (map-get? delegation-certificates { delegation-id: delegation-id }))), voting-power: (get voting-power (unwrap-panic (map-get? delegation-certificates { delegation-id: delegation-id }))), delegation-start: block-height, delegation-end: (get delegation-end (unwrap-panic (map-get? delegation-certificates { delegation-id: delegation-id }))), proposal-restrictions: (get proposal-restrictions (unwrap-panic (map-get? delegation-certificates { delegation-id: delegation-id }))), revocable: true, auto-renew: false, fee-rate: (get fee-rate (unwrap-panic (map-get? delegation-certificates { delegation-id: delegation-id }))), nft-token-id: token-id }))
    NFT_TYPE_PROPOSAL_VOTING
      ;; Transfer voting rights (if voting hasn't occurred)
      (when (is-none (get vote-cast (unwrap-panic (map-get? proposal-voting-nfts { token-id: token-id }))))))
        (map-set proposal-voting-nfts
          { token-id: token-id }
          (merge (unwrap-panic (map-get? proposal-voting-nfts { token-id: token-id })) { owner: to }))
    else true)) ;; Other types transfer normally

;; ===== Read-Only Functions =====

(define-read-only (get-proposal-voting-nft (token-id uint))
  (map-get? proposal-voting-nfts { token-id: token-id }))

(define-read-only (get-delegation-certificate (delegation-id uint))
  (map-get? delegation-certificates { delegation-id: delegation-id }))

(define-read-only (get-reputation-badge (token-id uint))
  (map-get? reputation-badges { token-id: token-id }))

(define-read-only (get-council-membership (token-id uint))
  (map-get? council-memberships { token-id: token-id }))

(define-read-only (get-veto-certificate (token-id uint))
  (map-get? veto-certificates { token-id: token-id }))

(define-read-only (get-quorum-booster (token-id uint))
  (map-get? quorum-boosters { token-id: token-id }))

(define-read-only (get-user-governance-profile (user principal))
  (map-get? user-governance-profiles { user: user }))

(define-read-only (get-governance-nft-metadata (token-id uint))
  (map-get? governance-nft-metadata { token-id: token-id }))

;; ===== Additional Helper Functions =====

(define-private (get-proposal-privileges (proposal-category uint))
  (match proposal-category
    u1 (list "protocol-governance" "core-changes")      ;; Protocol proposals
    u2 (list "treasury-management" "fund-allocation")  ;; Treasury proposals
    u3 (list "governance-rules" "voting-changes")      ;; Governance proposals
    u4 (list "security-audits" "risk-management")      ;; Security proposals
    else (list "basic-voting")))

(define-private (get-council-emergency-powers (council-type uint))
  (match council-type
    u1 (list "protocol-emergency" "critical-updates")  ;; Core council
    u2 (list "security-emergency" "veto-activation")   ;; Security council
    u3 (list "treasury-emergency" "fund-reallocation") ;; Treasury council
    u4 (list "technical-emergency" "system-maintenance") ;; Technical council
    else (list)))

(define-private (get-council-responsibilities (council-type uint))
  (match council-type
    u1 (list "protocol-oversight" "strategic-direction" "community-representation")
    u2 (list "security-audits" "risk-assessment" "vulnerability-management")
    u3 (list "treasury-management" "budget-oversight" "financial-planning")
    u4 (list "technical-review" "system-maintenance" "upgrade-approval")
    else (list "general-governance")))

(define-private (calculate-reputation-boost (voting-weight uint))
  (cond
    ((>= voting-weight u10000) u500)     ;; High weight = 5% boost
    ((>= voting-weight u5000) u300)      ;; Medium weight = 3% boost
    ((>= voting-weight u1000) u200)      ;; Low weight = 2% boost
    (true u100)))                         ;; Minimal = 1% boost

(define-private (calculate-voting-visual-tier (voting-weight uint))
  (cond
    ((>= voting-weight u10000) u5)       ;; Legendary - golden animated
    ((>= voting-weight u5000) u4)        ;; Epic - silver glowing
    ((>= voting-weight u1000) u3)        ;; Rare - bronze special
    (true u2)))                           ;; Common - standard

(define-private (calculate-delegation-visual-tier (voting-power uint))
  (cond
    ((>= voting-power u50000) u5)        ;; Legendary delegation
    ((>= voting-power u10000) u4)        ;; Epic delegation
    ((>= voting-power u5000) u3)         ;; Rare delegation
    (true u2)))                           ;; Common delegation

(define-private (calculate-reputation-tier (reputation-score uint))
  (cond
    ((>= reputation-score u9000) u10)     ;; Diamond tier
    ((>= reputation-score u8000) u9)       ;; Platinum tier
    ((>= reputation-score u7000) u8)       ;; Gold tier
    ((>= reputation-score u6000) u7)       ;; Silver tier
    ((>= reputation-score u5000) u6)       ;; Bronze tier
    ((>= reputation-score u4000) u5)       ;; Iron tier
    ((>= reputation-score u3000) u4)       ;; Steel tier
    ((>= reputation-score u2000) u3)       ;; Copper tier
    ((>= reputation-score u1000) u2)       ;; Tin tier
    (true u1)))                           ;; Wood tier

(define-private (calculate-reputation-weight-multiplier (reputation-tier uint))
  (cond
    ((>= reputation-tier u8) u2000)       ;; 2x for top tiers
    ((>= reputation-tier u6) u1500)       ;; 1.5x for high tiers
    ((>= reputation-tier u4) u1200)       ;; 1.2x for medium tiers
    (true u1000)))                        ;; 1x for lower tiers

(define-private (calculate-reputation-governance-weight (reputation-score uint) (reputation-tier uint))
  (+ (/ reputation-score u100) (* reputation-tier u100)))

(define-private (get-reputation-privileges (reputation-tier uint))
  (match reputation-tier
    u10 (list "legendary-reputation" "priority-voting" "exclusive-proposals")
    u8 (list "elite-reputation" "enhanced-voting" "priority-access")
    u6 (list "high-reputation" "improved-voting" "standard-access")
    u4 (list "medium-reputation" "standard-voting" "limited-access")
    u2 (list "low-reputation" "basic-voting")
    else (list "basic-reputation")))

(define-private (update-user-governance-profile (user principal) (voting-weight-change uint) (reputation-change uint))
  (match (map-get? user-governance-profiles { user: user })
    profile
      (map-set user-governance-profiles { user: user }
        (merge profile {
          total-voting-weight: (+ (get total-voting-weight profile) voting-weight-change),
          reputation-score: (+ (get reputation-score profile) reputation-change),
          last-activity-block: block-height
        }))
    none
      (map-set user-governance-profiles { user: user }
        {
          total-voting-weight: voting-weight-change,
          base-voting-weight: voting-weight-change,
          enhanced-weight-multiplier: u1000,
          reputation-score: reputation-change,
          participation-history: (list),
          council-memberships: (list),
          delegation-history: (list),
          reputation-tiers: (list),
          emergency-contacts: (list),
          last-activity-block: block-height
        })))

(define-private (update-user-governance-profile-on-vote (user principal) (proposal-id uint) (vote bool))
  (match (map-get? user-governance-profiles { user: user })
    profile
      (let ((new-entry { proposal-id: proposal-id, vote: vote, block: block-height })
            (current-history (get participation-history profile)))
        (map-set user-governance-profiles { user: user }
          (merge profile {
            participation-history: (cons new-entry current-history),
            last-activity-block: block-height
          })))
    none
      ;; Create new profile if doesn't exist
      (map-set user-governance-profiles { user: user }
        {
          total-voting-weight: u0,
          base-voting-weight: u0,
          enhanced-weight-multiplier: u1000,
          reputation-score: u0,
          participation-history: (list { proposal-id: proposal-id, vote: vote, block: block-height }),
          council-memberships: (list),
          delegation-history: (list),
          reputation-tiers: (list),
          emergency-contacts: (list),
          last-activity-block: block-height
        })))

(define-private (update-user-governance-profile-on-reputation (user principal) (reputation-score uint) (participation-count uint))
  (match (map-get? user-governance-profiles { user: user })
    profile
      (map-set user-governance-profiles { user: user }
        (merge profile {
          reputation-score: reputation-score,
          last-activity-block: block-height
        }))
    none
      ;; Create new profile if doesn't exist
      (map-set user-governance-profiles { user: user }
        {
          total-voting-weight: u0,
          base-voting-weight: u0,
          enhanced-weight-multiplier: u1000,
          reputation-score: reputation-score,
          participation-history: (list),
          council-memberships: (list),
          delegation-history: (list),
          reputation-tiers: (list),
          emergency-contacts: (list),
          last-activity-block: block-height
        })))
