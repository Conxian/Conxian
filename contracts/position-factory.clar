;; position-factory.clar
;; Enhanced factory contract for creating and managing differentiated position NFTs.

;; SIP-010: Fungible Token Standard
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
;; SIP-009: Non-Fungible Token Standard
(use-trait sip-009-nft-trait .defi-traits.sip-009-nft-trait)

;; ===== Constants =====
;; Error codes
(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_INVALID_INPUT (err u3001))
(define-constant ERR_POSITION_NOT_FOUND (err u3002))
(define-constant ERR_ZERO_AMOUNT (err u3003))
(define-constant ERR_INVALID_NFT_TYPE (err u3004))

;; NFT Type Constants
(define-constant NFT_TYPE_LAUNCH_LP u1) ;; Launch liquidity provider
(define-constant NFT_TYPE_NORMAL_LP u2) ;; Normal liquidity provider  
(define-constant NFT_TYPE_BOUNTY_HUNTER u3) ;; Bounty completion NFT
(define-constant NFT_TYPE_COMPETITION_WINNER u4) ;; Competition winner
(define-constant NFT_TYPE_FOUNDING_CONTRIBUTOR u5) ;; Original funder

;; ===== Data Variables =====
(define-data-var next-position-id uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var governance-address principal tx-sender)

;; ===== Enhanced Data Maps =====
;; Enhanced metadata for differentiated position NFTs
(define-map enhanced-position-metadata
  { position-id: uint }
  {
    owner: principal,
    nft-type: uint, ;; NFT type classification
    collateral-token: principal,
    collateral-amount: uint,
    debt-token: principal,
    debt-amount: uint,
    launch-phase: uint, ;; Launch phase when created
    special-privileges: (list 10 (string-ascii 50)), ;; Special privileges
    rarity-score: uint, ;; Rarity/scarcity score
    revenue-share: uint, ;; Revenue sharing percentage
    governance-weight: uint, ;; Enhanced governance weight
    creation-block: uint, ;; Block when created
    visual-tier: uint, ;; Visual appearance tier
    transfer-restricted: bool, ;; Transfer restrictions
  }
)

;; Legacy position metadata (for backward compatibility)
(define-map position-metadata
  { position-id: uint }
  {
    owner: principal,
    collateral-token: principal,
    collateral-amount: uint,
    debt-token: principal,
    debt-amount: uint,
    creation-block: uint,
  }
)

;; NFT type configuration
(define-map nft-type-configs
  uint
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    base-governance-weight: uint,
    base-revenue-share: uint,
    visual-style: (string-ascii 20),
    transfer-cooldown: uint,
    special-abilities: (list 5 (string-ascii 30)),
  }
)

;; Bounty management system
(define-map bounties
  { bounty-id: uint }
  {
    title: (string-ascii 100),
    description: (string-utf8 500),
    reward-amount: uint,
    reward-token: principal,
    difficulty: uint, ;; 1-5 difficulty rating
    category: (string-ascii 50), ;; Security, UI, Integration, etc.
    deadline-block: uint,
    max-submissions: uint,
    current-submissions: uint,
    is-active: bool,
    judging-criteria: (string-utf8 1000),
    special-rewards: (list 5 principal), ;; Additional NFT rewards
    created-by: principal,
    created-at: uint,
  }
)

;; Competition management system  
(define-map competitions
  { competition-id: uint }
  {
    name: (string-ascii 100),
    description: (string-utf8 1000),
    prize-pool: uint,
    entry-fee: uint,
    start-block: uint,
    end-block: uint,
    max-participants: uint,
    current-participants: uint,
    prize-distribution: (list 10 uint), ;; Prize distribution percentages
    special-nft-rewards: (list 5 principal), ;; Unique NFTs for winners
    leaderboard: (list 100 {
      participant: principal,
      score: uint,
    }),
    category: (string-ascii 50),
    judging-method: (string-ascii 30),
    created-by: principal,
    created-at: uint,
  }
)

;; Bounty and competition counters
(define-data-var next-bounty-id uint u1)
(define-data-var next-competition-id uint u1)

;; ===== Private Functions =====

;; @desc Checks if the caller is the contract owner.
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED))
)

;; @desc Checks if the caller is the governance address.
;; @returns A response with ok true if authorized, or an error.
(define-private (check-is-governance)
  (ok (asserts! (is-eq tx-sender (var-get governance-address)) ERR_UNAUTHORIZED))
)


;; ===== Helper Functions for NFT Calculations =====

;; Calculate rarity score based on contribution amount and NFT type
(define-private (calculate-rarity-score
    (amount uint)
    (nft-type uint)
  )
  (if (is-eq nft-type NFT_TYPE_LAUNCH_LP)
    (if (>= amount u10000000)
      u1000
      u500
    )
    (if (is-eq nft-type NFT_TYPE_NORMAL_LP)
      (if (>= amount u5000000)
        u600
        u300
      )
      u400
    )
  )
)

;; Calculate visual tier based on contribution amount and NFT type
(define-private (calculate-visual-tier
    (amount uint)
    (nft-type uint)
  )
  (if (is-eq nft-type NFT_TYPE_LAUNCH_LP)
    (if (>= amount u50000000)
      u5
      (if (>= amount u10000000)
        u4
        (if (>= amount u1000000)
          u3
          u2
        )
      )
    )
    (if (is-eq nft-type NFT_TYPE_NORMAL_LP)
      (if (>= amount u10000000)
        u3
        (if (>= amount u1000000)
          u2
          u1
        )
      )
      u2
    )
  )
)

;; Calculate bounty rarity based on achievement score and difficulty
(define-private (calculate-bounty-rarity
    (achievement-score uint)
    (difficulty uint)
  )
  (let ((base-score (* achievement-score difficulty)))
    (if (>= base-score u20)
      u1000
      (if (>= base-score u15)
        u800
        (if (>= base-score u10)
          u600
          (if (>= base-score u5)
            u400
            u200
          )
        )
      )
    )
  )
)

;; Calculate bounty visual tier based on achievement score and difficulty
(define-private (calculate-bounty-visual-tier
    (achievement-score uint)
    (difficulty uint)
  )
  (let ((base-score (* achievement-score difficulty)))
    (if (>= base-score u20)
      u5
      (if (>= base-score u15)
        u4
        (if (>= base-score u10)
          u3
          (if (>= base-score u5)
            u2
            u1
          )
        )
      )
    )
  )
)

;; Calculate competition rarity based on rank and participants
(define-private (calculate-competition-rarity
    (prize-rank uint)
    (max-participants uint)
  )
  (let ((participant-multiplier (/ max-participants u10)))
    (if (is-eq prize-rank u1)
      (* participant-multiplier u1000)
      (if (is-eq prize-rank u2)
        (* participant-multiplier u800)
        (if (is-eq prize-rank u3)
          (* participant-multiplier u600)
          (* participant-multiplier u400)
        )
      )
    )
  )
)

;; Calculate competition visual tier based on rank
(define-private (calculate-competition-visual-tier (prize-rank uint))
  (if (is-eq prize-rank u1)
    u5
    (if (is-eq prize-rank u2)
      u4
      (if (is-eq prize-rank u3)
        u3
        u2
      )
    )
  )
)

;; ===== Public Functions =====

;; @desc Creates a new launch LP NFT with enhanced privileges.
;; @param contribution-amount The amount contributed to launch funding.
;; @returns A response with the new position ID on success, or an error.
(define-public (create-launch-lp-nft (contribution-amount uint))
  (let (
      (position-id (var-get next-position-id))
      (current-block block-height)
      (launch-phase u1) ;; Default to bootstrap phase
    )
    (asserts! (> contribution-amount u0) ERR_ZERO_AMOUNT)

    (map-set enhanced-position-metadata { position-id: position-id } {
      owner: tx-sender,
      nft-type: NFT_TYPE_LAUNCH_LP,
      collateral-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      collateral-amount: contribution-amount,
      debt-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      debt-amount: u0,
      launch-phase: launch-phase,
      special-privileges: (list
        "early-access"         "enhanced-governance"         "revenue-share"
        "priority-support"
      ),
      rarity-score: (calculate-rarity-score contribution-amount NFT_TYPE_LAUNCH_LP),
      revenue-share: u500, ;; 5% revenue share
      governance-weight: u2000, ;; 2x governance weight
      creation-block: current-block,
      visual-tier: (calculate-visual-tier contribution-amount NFT_TYPE_LAUNCH_LP),
      transfer-restricted: true, ;; Prevent flipping
    })

    (var-set next-position-id (+ position-id u1))

    (print {
      event: "launch-lp-nft-created",
      position-id: position-id,
      owner: tx-sender,
      contribution-amount: contribution-amount,
      rarity-score: (calculate-rarity-score contribution-amount NFT_TYPE_LAUNCH_LP),
      governance-weight: u2000,
      revenue-share: u500,
    })

    (ok position-id)
  )
)

;; @desc Creates a new normal LP NFT with standard privileges.
;; @param contribution-amount The amount contributed to operations funding.
;; @returns A response with the new position ID on success, or an error.
(define-public (create-normal-lp-nft (contribution-amount uint))
  (let (
      (position-id (var-get next-position-id))
      (current-block block-height)
      (launch-phase u1) ;; Default to bootstrap phase
    )
    (asserts! (> contribution-amount u0) ERR_ZERO_AMOUNT)

    (map-set enhanced-position-metadata { position-id: position-id } {
      owner: tx-sender,
      nft-type: NFT_TYPE_NORMAL_LP,
      collateral-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      collateral-amount: contribution-amount,
      debt-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      debt-amount: u0,
      launch-phase: launch-phase,
      special-privileges: (list "standard-access" "basic-governance"),
      rarity-score: (calculate-rarity-score contribution-amount NFT_TYPE_NORMAL_LP),
      revenue-share: u100, ;; 1% revenue share
      governance-weight: u1000, ;; 1x governance weight
      creation-block: current-block,
      visual-tier: (calculate-visual-tier contribution-amount NFT_TYPE_NORMAL_LP),
      transfer-restricted: false, ;; No transfer restrictions
    })

    (var-set next-position-id (+ position-id u1))

    (print {
      event: "normal-lp-nft-created",
      position-id: position-id,
      owner: tx-sender,
      contribution-amount: contribution-amount,
      rarity-score: (calculate-rarity-score contribution-amount NFT_TYPE_NORMAL_LP),
      governance-weight: u1000,
      revenue-share: u100,
    })

    (ok position-id)
  )
)

;; @desc Creates a bounty hunter NFT for completed bounties.
;; @param bounty-id The ID of the completed bounty.
;; @param achievement-score The score achieved in the bounty.
;; @returns A response with the new position ID on success, or an error.
(define-public (create-bounty-hunter-nft
    (bounty-id uint)
    (achievement-score uint)
  )
  (let (
      (position-id (var-get next-position-id))
      (current-block block-height)
      (bounty-info (unwrap! (map-get? bounties { bounty-id: bounty-id })
        ERR_POSITION_NOT_FOUND
      ))
    )
    (map-set enhanced-position-metadata { position-id: position-id } {
      owner: tx-sender,
      nft-type: NFT_TYPE_BOUNTY_HUNTER,
      collateral-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      collateral-amount: (get reward-amount bounty-info),
      debt-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      debt-amount: u0,
      launch-phase: u7, ;; Fully operational phase
      special-privileges: (list "bounty-access" "skill-recognition" "priority-bounties"),
      rarity-score: (calculate-bounty-rarity achievement-score (get difficulty bounty-info)),
      revenue-share: u300, ;; 3% revenue share
      governance-weight: u1500, ;; 1.5x governance weight
      creation-block: current-block,
      visual-tier: (calculate-bounty-visual-tier achievement-score
        (get difficulty bounty-info)
      ),
      transfer-restricted: false,
    })

    (var-set next-position-id (+ position-id u1))

    (print {
      event: "bounty-hunter-nft-created",
      position-id: position-id,
      owner: tx-sender,
      bounty-id: bounty-id,
      achievement-score: achievement-score,
      rarity-score: (calculate-bounty-rarity achievement-score (get difficulty bounty-info)),
    })

    (ok position-id)
  )
)

;; @desc Creates a competition winner NFT.
;; @param competition-id The ID of the competition.
;; @param final-score The final score achieved.
;; @param prize-rank The rank achieved (1st, 2nd, 3rd, etc.).
;; @returns A response with the new position ID on success, or an error.
(define-public (create-competition-winner-nft
    (competition-id uint)
    (final-score uint)
    (prize-rank uint)
  )
  (let (
      (position-id (var-get next-position-id))
      (current-block block-height)
      (competition-info (unwrap! (map-get? competitions { competition-id: competition-id })
        ERR_POSITION_NOT_FOUND
      ))
    )
    (map-set enhanced-position-metadata { position-id: position-id } {
      owner: tx-sender,
      nft-type: NFT_TYPE_COMPETITION_WINNER,
      collateral-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      collateral-amount: (get prize-pool competition-info),
      debt-token: 'STSZXAKV7DWTDZN2601WR31BM51BD3YTQXKCF9EZ.cxvg-token,
      debt-amount: u0,
      launch-phase: u7, ;; Fully operational phase
      special-privileges: (list "competition-access" "winner-status" "exclusive-events"),
      rarity-score: (calculate-competition-rarity prize-rank
        (get max-participants competition-info)
      ),
      revenue-share: u400, ;; 4% revenue share
      governance-weight: u1800, ;; 1.8x governance weight
      creation-block: current-block,
      visual-tier: (calculate-competition-visual-tier prize-rank),
      transfer-restricted: false,
    })

    (var-set next-position-id (+ position-id u1))

    (print {
      event: "competition-winner-nft-created",
      position-id: position-id,
      owner: tx-sender,
      competition-id: competition-id,
      final-score: final-score,
      prize-rank: prize-rank,
      rarity-score: (calculate-competition-rarity prize-rank
        (get max-participants competition-info)
      ),
    })

    (ok position-id)
  )
)

;; Legacy create-position function for backward compatibility
(define-public (create-position
    (collateral-token <sip-010-ft-trait>)
    (collateral-amount uint)
    (debt-token <sip-010-ft-trait>)
    (debt-amount uint)
  )
  (let (
      (position-id (var-get next-position-id))
      (current-block block-height)
      (collateral-principal (contract-of collateral-token))
      (debt-principal (contract-of debt-token))
    )
    (asserts! (> collateral-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (> debt-amount u0) ERR_ZERO_AMOUNT)

    (map-set position-metadata { position-id: position-id } {
      owner: tx-sender,
      collateral-token: collateral-principal,
      collateral-amount: collateral-amount,
      debt-token: debt-principal,
      debt-amount: debt-amount,
      creation-block: current-block,
    })

    (var-set next-position-id (+ position-id u1))

    (print {
      event: "position-created",
      position-id: position-id,
      owner: tx-sender,
      collateral-token: collateral-principal,
      collateral-amount: collateral-amount,
      debt-token: debt-principal,
      debt-amount: debt-amount,
    })

    (ok position-id)
  )
)


;; ===== Bounty Management Functions =====

;; @desc Creates a new bounty.
;; @param title The bounty title.
;; @param description The bounty description.
;; @param reward-amount The reward amount.
;; @param reward-token The reward token principal.
;; @param difficulty The difficulty rating (1-5).
;; @param category The bounty category.
;; @param deadline-block The deadline block height.
;; @param max-submissions Maximum number of submissions.
;; @returns A response with the new bounty ID on success, or an error.
(define-public (create-bounty
    (title (string-ascii 100))
    (description (string-utf8 500))
    (reward-amount uint)
    (reward-token principal)
    (difficulty uint)
    (category (string-ascii 50))
    (deadline-block uint)
    (max-submissions uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> reward-amount u0) ERR_ZERO_AMOUNT)
    (asserts! (and (>= difficulty u1) (<= difficulty u5)) ERR_INVALID_INPUT)
    (asserts! (> deadline-block block-height) ERR_INVALID_INPUT)

    (let ((bounty-id (var-get next-bounty-id)))
      (map-set bounties { bounty-id: bounty-id } {
        title: title,
        description: description,
        reward-amount: reward-amount,
        reward-token: reward-token,
        difficulty: difficulty,
        category: category,
        deadline-block: deadline-block,
        max-submissions: max-submissions,
        current-submissions: u0,
        is-active: true,
        judging-criteria: u"",
        special-rewards: (list),
        created-by: tx-sender,
        created-at: block-height,
      })

      (var-set next-bounty-id (+ bounty-id u1))

      (print {
        event: "bounty-created",
        bounty-id: bounty-id,
        title: title,
        reward-amount: reward-amount,
        difficulty: difficulty,
        category: category,
      })

      (ok bounty-id)
    )
  )
)

;; @desc Submits a solution to a bounty.
;; @param bounty-id The ID of the bounty.
;; @param solution-hash The hash of the submitted solution.
;; @returns A response with ok true on success, or an error.
(define-public (submit-bounty-solution
    (bounty-id uint)
    (solution-hash (string-ascii 64))
  )
  (let ((bounty (unwrap! (map-get? bounties { bounty-id: bounty-id }) ERR_POSITION_NOT_FOUND)))
    (asserts! (get is-active bounty) ERR_INVALID_INPUT)
    (asserts! (<= block-height (get deadline-block bounty)) ERR_INVALID_INPUT)
    (asserts! (< (get current-submissions bounty) (get max-submissions bounty))
      ERR_INVALID_INPUT
    )

    ;; Update submission count
    (map-set bounties { bounty-id: bounty-id }
      (merge bounty { current-submissions: (+ (get current-submissions bounty) u1) })
    )

    ;; In a real implementation, this would store the solution hash
    ;; and trigger a review process

    (print {
      event: "bounty-solution-submitted",
      bounty-id: bounty-id,
      submitter: tx-sender,
      solution-hash: solution-hash,
    })

    (ok true)
  )
)

;; @desc Creates a new competition.
;; @param name The competition name.
;; @param description The competition description.
;; @param prize-pool The total prize pool.
;; @param entry-fee The entry fee.
;; @param start-block The start block height.
;; @param end-block The end block height.
;; @param max-participants Maximum number of participants.
;; @param category The competition category.
;; @returns A response with the new competition ID on success, or an error.
(define-public (create-competition
    (name (string-ascii 100))
    (description (string-utf8 1000))
    (prize-pool uint)
    (entry-fee uint)
    (start-block uint)
    (end-block uint)
    (max-participants uint)
    (category (string-ascii 50))
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> prize-pool u0) ERR_ZERO_AMOUNT)
    (asserts! (> start-block block-height) ERR_INVALID_INPUT)
    (asserts! (> end-block start-block) ERR_INVALID_INPUT)

    (let ((competition-id (var-get next-competition-id)))
      (map-set competitions { competition-id: competition-id } {
        name: name,
        description: description,
        prize-pool: prize-pool,
        entry-fee: entry-fee,
        start-block: start-block,
        end-block: end-block,
        max-participants: max-participants,
        current-participants: u0,
        prize-distribution: (list u5000 u3000 u1500 u500), ;; 50%, 30%, 15%, 5%
        special-nft-rewards: (list),
        leaderboard: (list),
        category: category,
        judging-method: "score-based",
        created-by: tx-sender,
        created-at: block-height,
      })

      (var-set next-competition-id (+ competition-id u1))

      (print {
        event: "competition-created",
        competition-id: competition-id,
        name: name,
        prize-pool: prize-pool,
        category: category,
      })

      (ok competition-id)
    )
  )
)

;; @desc Updates the collateral amount for an existing position.
;; @param position-id The ID of the position to update.
;; @param new-collateral-amount The new collateral amount.
;; @returns A response with ok true on success, or an error.
(define-public (update-collateral
    (position-id uint)
    (new-collateral-amount uint)
  )
  (let ((position (unwrap! (map-get? position-metadata { position-id: position-id })
      ERR_POSITION_NOT_FOUND
    )))
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (> new-collateral-amount u0) ERR_ZERO_AMOUNT)

    (map-set position-metadata { position-id: position-id }
      (merge position { collateral-amount: new-collateral-amount })
    )
    (ok true)
  )
)

;; @desc Updates the debt amount for an existing position.
;; @param position-id The ID of the position to update.
;; @param new-debt-amount The new debt amount.
;; @returns A response with ok true on success, or an error.
(define-public (update-debt
    (position-id uint)
    (new-debt-amount uint)
  )
  (let ((position (unwrap! (map-get? position-metadata { position-id: position-id })
      ERR_POSITION_NOT_FOUND
    )))
    (asserts! (is-eq tx-sender (get owner position)) ERR_UNAUTHORIZED)
    (asserts! (> new-debt-amount u0) ERR_ZERO_AMOUNT)

    (map-set position-metadata { position-id: position-id }
      (merge position { debt-amount: new-debt-amount })
    )
    (ok true)
  )
)

;; @desc Sets the contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns A response with ok true on success, or an error.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Sets the governance address.
;; @param new-governance The principal of the new governance address.
;; @returns A response with ok true on success, or an error.
(define-public (set-governance-address (new-governance principal))
  (begin
    (try! (check-is-owner))
    (var-set governance-address new-governance)
    (ok true)
  )
)

;; ===== Read-only Functions =====

;; @desc Gets the metadata for a given position ID.
;; @param position-id The ID of the position NFT.
;; @returns An optional tuple containing the position metadata.
(define-read-only (get-position-metadata (position-id uint))
  (map-get? position-metadata { position-id: position-id })
)

;; @desc Gets the current contract owner.
;; @returns The principal of the contract owner.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; @desc Gets the current governance address.
;; @returns The principal of the governance address.
(define-read-only (get-governance-address)
  (ok (var-get governance-address))
)

;; @desc Gets the next available position ID.
;; @returns The next position ID that will be assigned.
(define-read-only (get-next-position-id)
  (ok (var-get next-position-id))
)

;; @desc Checks if a position exists.
;; @param position-id The ID of the position to check.
;; @returns True if the position exists, false otherwise.
(define-read-only (position-exists (position-id uint))
  (is-some (map-get? position-metadata { position-id: position-id }))
)
