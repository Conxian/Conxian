;; cxvg-utility.clar
;; CXVG Utility System - Fee discounts, proposal bonding, governance boosts
;; Addresses governance token utility sinks and voting power concentration risks

(use-trait token-trait .requirements.sip-010-trait-ft-standard.sip-010-trait-ft-standard)
(use-trait governance-token-trait .traits.governance-token-trait.governance-token-trait)

;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; Voting power tiers based on lock duration (blocks)
(define-constant TIER1_DURATION u10080)   ;; ~1 week
(define-constant TIER2_DURATION u43200)   ;; ~1 month
(define-constant TIER3_DURATION u129600)  ;; ~3 months
(define-constant TIER4_DURATION u525600)  ;; ~1 year

;; Voting multipliers (basis points)
(define-constant TIER1_MULTIPLIER u10000) ;; 1.0x
(define-constant TIER2_MULTIPLIER u15000) ;; 1.5x
(define-constant TIER3_MULTIPLIER u25000) ;; 2.5x
(define-constant TIER4_MULTIPLIER u40000) ;; 4.0x

;; Fee discount tiers (basis points)
(define-constant FEE_DISCOUNT_TIER1 u9500) ;; 5% discount
(define-constant FEE_DISCOUNT_TIER2 u9000) ;; 10% discount
(define-constant FEE_DISCOUNT_TIER3 u8500) ;; 15% discount
(define-constant FEE_DISCOUNT_TIER4 u8000) ;; 20% discount

;; Minimum bonding requirements
(define-constant MIN_PROPOSAL_BOND u100000)   ;; 100 CXVG minimum
(define-constant RISK_PROPOSAL_BOND u1000000) ;; 1M CXVG for high-risk proposals

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u600)
(define-constant ERR_INSUFFICIENT_BALANCE u601)
(define-constant ERR_INVALID_LOCK_DURATION u602)
(define-constant ERR_STILL_LOCKED u603)
(define-constant ERR_NO_LOCK_FOUND u604)
(define-constant ERR_INSUFFICIENT_BOND u605)
(define-constant ERR_PROPOSAL_NOT_FOUND u606)
(define-constant ERR_BOND_ALREADY_SLASHED u607)
(define-constant ERR_NOT_PROPOSAL_CREATOR u608)
(define-constant ERR_INVALID_AMOUNT u609)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var cxvg-contract (optional principal) none)
(define-data-var total-locked uint u0)
(define-data-var total-voting-power uint u0)

;; --- User Vote Escrow (veCXVG) ---
(define-map user-locks
  principal
  {
    amount: uint,
    unlock-height: uint,
    voting-power: uint,
    lock-tier: uint
  }
)

;; Historical voting power snapshots for proposal creation
(define-map voting-snapshots
  { user: principal, block: uint }
  { voting-power: uint }
)

;; --- Proposal Bonding System ---
(define-map proposal-bonds
  uint ;; proposal-id
  {
    creator: principal,
    bond-amount: uint,
    bond-type: uint, ;; 0=normal, 1=risk
    slashed: bool,
    created-at: uint
  }
)
(define-data-var next-proposal-id uint u1)

;; --- Fee Discount System ---
(define-map user-fee-discounts
  principal
  { discount-bps: uint, expires-at: uint }
)

;; --- Governance Boost System ---
(define-map dimensional-boosts
  principal
  {
    vault-boost-bps: uint, ;; Vault allocation boost
    farm-boost-bps: uint,  ;; Farm weight boost
    expires-at: uint
  }
)

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-cxvg-contract (new-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set cxvg-contract (some new-contract))
    (ok true)
  )
)

;; --- Lock/Unlock Functions ---

;; Lock CXVG for voting power and utility benefits
(define-public (lock-cxvg (amount uint) (duration uint))
  (let (
    (unlock-height (+ block-height duration))
    (existing-lock (default-to 
      { amount: u0, unlock-height: u0, voting-power: u0, lock-tier: u0 }
      (map-get? user-locks tx-sender)
    ))
    (tier (get-lock-tier duration))
    (multiplier (get-tier-multiplier tier))
    (new-amount (+ amount (get amount existing-lock)))
    (voting-power (/ (* new-amount multiplier) u10000))
  )
    (begin
      (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
      (asserts! (>= duration TIER1_DURATION) (err ERR_INVALID_LOCK_DURATION))
      
      ;; Update user lock
      (map-set user-locks tx-sender
        {
          amount: new-amount,
          unlock-height: unlock-height,
          voting-power: voting-power,
          lock-tier: tier
        }
      )
      
      ;; Update totals
      (var-set total-locked (+ (var-get total-locked) amount))
      (var-set total-voting-power (+ (var-get total-voting-power) voting-power))
      
      ;; Update user benefits
      (unwrap-panic (update-user-benefits tx-sender tier))
      
      ;; Create voting snapshot
      (map-set voting-snapshots 
        { user: tx-sender, block: block-height } 
        { voting-power: voting-power }
      )
      
      (ok { tier: tier, voting-power: voting-power, unlock-height: unlock-height })
    )
  )
)

;; Unlock expired CXVG
(define-public (unlock-cxvg)
  (match (map-get? user-locks tx-sender)
    lock-info
    (let (
      (amount (get amount lock-info))
      (voting-power (get voting-power lock-info))
    )
      (begin
        (asserts! (>= block-height (get unlock-height lock-info)) (err ERR_STILL_LOCKED))
        
        ;; Update totals
        (var-set total-locked (- (var-get total-locked) amount))
        (var-set total-voting-power (- (var-get total-voting-power) voting-power))
        
        ;; Remove user lock
        (map-delete user-locks tx-sender)
        
        ;; Clear user benefits
        (map-delete user-fee-discounts tx-sender)
        (map-delete dimensional-boosts tx-sender)
        
        ;; Create snapshot with zero voting power
        (map-set voting-snapshots 
          { user: tx-sender, block: block-height } 
          { voting-power: u0 }
        )
        
        (ok amount)
      )
    )
    (err ERR_NO_LOCK_FOUND)
  )
)

;; --- Proposal Bonding ---

;; Create proposal with bond
(define-public (create-bonded-proposal (bond-amount uint) (is-risk-proposal bool))
  (let (
    (proposal-id (var-get next-proposal-id))
    (required-bond (if is-risk-proposal RISK_PROPOSAL_BOND MIN_PROPOSAL_BOND))
    (bond-type (if is-risk-proposal u1 u0))
  )
    (begin
      (asserts! (>= bond-amount required-bond) (err ERR_INSUFFICIENT_BOND))
      
      (asserts! (is-some (map-get? user-locks tx-sender)) (err ERR_NO_LOCK_FOUND))
      (let ((lock-info (unwrap-panic (map-get? user-locks tx-sender))))
        (asserts! (>= (get voting-power lock-info) required-bond) (err ERR_INSUFFICIENT_BOND)))
      
      (map-set proposal-bonds proposal-id
        {
          creator: tx-sender,
          bond-amount: bond-amount,
          bond-type: bond-type,
          slashed: false,
          created-at: block-height
        }
      )
      
      (var-set next-proposal-id (+ proposal-id u1))
      (ok proposal-id)
    )
  )
)

;; Slash bond for failed/malicious proposal
(define-public (slash-proposal-bond (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    
    (match (map-get? proposal-bonds proposal-id)
      bond-info
      (begin
        (asserts! (not (get slashed bond-info)) (err ERR_BOND_ALREADY_SLASHED))
        
        (map-set proposal-bonds proposal-id
          (merge bond-info { slashed: true })
        )
        
        (ok (get bond-amount bond-info))
      )
      (err ERR_PROPOSAL_NOT_FOUND)
    )
  )
)

;; Return bond for successful proposal
(define-public (return-proposal-bond (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    
    (match (map-get? proposal-bonds proposal-id)
      bond-info
      (let (
        (creator (get creator bond-info))
        (amount (get bond-amount bond-info))
      )
        (begin
          (asserts! (not (get slashed bond-info)) (err ERR_BOND_ALREADY_SLASHED))
          (map-delete proposal-bonds proposal-id)
          (ok amount)
        )
      )
      (err ERR_PROPOSAL_NOT_FOUND)
    )
  )
)

;; --- Utility Benefits ---

;; Update user benefits based on lock tier
(define-private (update-user-benefits (user principal) (tier uint))
  (let (
    (discount (get-fee-discount tier))
    (vault-boost (get-vault-boost tier))
    (farm-boost (get-farm-boost tier))
    (expiry (+ block-height TIER4_DURATION))
  )
    (begin
      (map-set user-fee-discounts user
        { discount-bps: discount, expires-at: expiry }
      )
      
      (map-set dimensional-boosts user
        {
          vault-boost-bps: vault-boost,
          farm-boost-bps: farm-boost,
          expires-at: expiry
        }
      )
      
      (ok true)
    )
  )
)

;; --- Helper Functions ---
(define-read-only (get-lock-tier (duration uint))
  (if (>= duration TIER4_DURATION) u4
    (if (>= duration TIER3_DURATION) u3
      (if (>= duration TIER2_DURATION) u2 u1)
    )
  )
)

(define-read-only (get-tier-multiplier (tier uint))
  (if (is-eq tier u4) TIER4_MULTIPLIER
    (if (is-eq tier u3) TIER3_MULTIPLIER
      (if (is-eq tier u2) TIER2_MULTIPLIER TIER1_MULTIPLIER)
    )
  )
)

(define-read-only (get-fee-discount (tier uint))
  (if (is-eq tier u4) FEE_DISCOUNT_TIER4
    (if (is-eq tier u3) FEE_DISCOUNT_TIER3
      (if (is-eq tier u2) FEE_DISCOUNT_TIER2 FEE_DISCOUNT_TIER1)
    )
  )
)

(define-read-only (get-vault-boost (tier uint))
  (* tier u50) ;; 0.5% per tier max 2%
)

(define-read-only (get-farm-boost (tier uint))
  (* tier u100) ;; 1% per tier max 4%
)

;; --- External Interface Functions ---

;; Get user's current fee discount
(define-read-only (get-user-fee-discount (user principal))
  (match (map-get? user-fee-discounts user)
    discount-info
    (if (> (get expires-at discount-info) block-height)
      (get discount-bps discount-info)
      u10000
    )
    u10000
  )
)

;; Get user's current dimensional boosts
(define-read-only (get-user-boosts (user principal))
  (match (map-get? dimensional-boosts user)
    boost-info
    (if (> (get expires-at boost-info) block-height)
      boost-info
      { vault-boost-bps: u0, farm-boost-bps: u0, expires-at: u0 }
    )
    { vault-boost-bps: u0, farm-boost-bps: u0, expires-at: u0 }
  )
)

;; Get user's voting power at specific block
(define-read-only (get-voting-power-at (user principal) (block-height-target uint))
  (match (map-get? voting-snapshots { user: user, block: block-height-target })
    snapshot (get voting-power snapshot)
    (match (map-get? user-locks user)
      lock-info (get voting-power lock-info)
      u0
    )
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-user-lock-info (user principal))
  (map-get? user-locks user)
)

(define-read-only (get-proposal-bond-info (proposal-id uint))
  (map-get? proposal-bonds proposal-id)
)

(define-read-only (get-protocol-stats)
  {
    total-locked: (var-get total-locked),
    total-voting-power: (var-get total-voting-power),
    next-proposal-id: (var-get next-proposal-id),
    cxvg-contract: (var-get cxvg-contract)
  }
)

(define-read-only (get-user-complete-info (user principal))
  (let (
    (lock (get-user-lock-info user))
    (discount (get-user-fee-discount user))
    (boosts (get-user-boosts user))
  )
    {
      lock-info: lock,
      fee-discount-bps: discount,
      vault-boost-bps: (get vault-boost-bps boosts),
      farm-boost-bps: (get farm-boost-bps boosts),
      benefits-expire: (get expires-at boosts)
    }
  )
)
