;; yield-distribution-engine.clar
;; Advanced yield distribution system for enterprise loans and bonds
;; Handles complex yield calculations, distribution schedules, and optimization

(use-trait sip10 sip-010-trait.sip-010-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u9001))
(define-constant ERR_POOL_NOT_FOUND (err u9002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u9003))
(define-constant ERR_INVALID_AMOUNT (err u9004))
(define-constant ERR_DISTRIBUTION_FAILED (err u9005))
(define-constant ERR_SCHEDULE_NOT_FOUND (err u9006))
(define-constant ERR_ALREADY_CLAIMED (err u9007))

;; Precision and time constants
(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant BASIS_POINTS u10000)
(define-constant BLOCKS_PER_DAY u144) ;; Approximate
(define-constant BLOCKS_PER_WEEK u1008)
(define-constant BLOCKS_PER_MONTH u4320)

;; Yield pool types
(define-constant POOL_TYPE_BOND "BOND")
(define-constant POOL_TYPE_STAKING "STAKING")
(define-constant POOL_TYPE_LIQUIDITY "LIQUIDITY")
(define-constant POOL_TYPE_ENTERPRISE "ENTERPRISE")

;; Distribution strategies
(define-constant STRATEGY_PROPORTIONAL "PROPORTIONAL")
(define-constant STRATEGY_WEIGHTED "WEIGHTED")
(define-constant STRATEGY_TIERED "TIERED")
(define-constant STRATEGY_VESTING "VESTING")

;; Yield pool definitions
(define-map yield-pools
  uint ;; pool-id
  {
    pool-name: (string-ascii 50),
    pool-type: (string-ascii 20),
    total-deposited: uint,
    total-yield-available: uint,
    total-yield-distributed: uint,
    distribution-strategy: (string-ascii 20),
    reward-token: principal,
    creation-block: uint,
    last-distribution: uint,
    active: bool,
    admin: principal
  })

;; Participant stakes in pools
(define-map pool-participants
  {pool-id: uint, participant: principal}
  {
    stake-amount: uint,
    total-claimed: uint,
    last-claim-block: uint,
    weight-multiplier: uint, ;; For weighted distribution
    tier-level: uint, ;; For tiered distribution
    vesting-start: uint, ;; For vesting schedules
    vesting-duration: uint
  })

;; Distribution schedules for automated yield
(define-map distribution-schedules
  uint ;; schedule-id
  {
    pool-id: uint,
    frequency-blocks: uint, ;; How often to distribute
    amount-per-distribution: uint,
    next-distribution-block: uint,
    remaining-distributions: uint,
    auto-compound: bool,
    active: bool
  })

;; Bond-specific yield tracking
(define-map bond-yield-tracking
  {bond-series: uint, loan-id: uint}
  {
    allocated-yield: uint,
    distributed-yield: uint,
    last-payment-block: uint,
    yield-rate: uint
  })

;; Enterprise loan yield allocation
(define-map enterprise-yield-allocation
  uint ;; loan-id
  {
    total-interest-generated: uint,
    bond-holder-share: uint, ;; percentage in basis points
    protocol-share: uint,
    treasury-share: uint,
    distributed-to-bonds: uint,
    last-allocation-block: uint
  })

;; System state
(define-data-var contract-admin principal tx-sender)
(define-data-var next-pool-id uint u1)
(define-data-var next-schedule-id uint u1)
(define-data-var system-paused bool false)
(define-data-var total-yield-distributed uint u0)

;; Integration contracts
(define-data-var bond-contract (optional principal) none)
(define-data-var enterprise-loan-manager (optional principal) none)
(define-data-var revenue-distributor (optional principal) none)

;; Fee structure
(define-data-var distribution-fee-bps uint u100) ;; 1% distribution fee
(define-data-var protocol-share-bps uint u2000) ;; 20% to protocol
(define-data-var treasury-share-bps uint u1000) ;; 10% to treasury

;; === ADMIN FUNCTIONS ===
(define-private (is-admin)
  (is-eq tx-sender (var-get contract-admin)))

(define-private (is-pool-admin (pool-id uint))
  (match (map-get? yield-pools pool-id)
    pool (is-eq tx-sender (get admin pool))
    false))

(define-public (set-contract-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set contract-admin new-admin)
    (ok true)))

(define-public (set-integration-contracts 
  (bond-contract-ref principal) 
  (enterprise-manager-ref principal) 
  (revenue-dist-ref principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set bond-contract (some bond-contract-ref))
    (var-set enterprise-loan-manager (some enterprise-manager-ref))
    (var-set revenue-distributor (some revenue-dist-ref))
    (ok true)))

;; === YIELD POOL MANAGEMENT ===
(define-public (create-yield-pool
  (pool-name (string-ascii 50))
  (pool-type (string-ascii 20))
  (distribution-strategy (string-ascii 20))
  (reward-token principal))
  
  (let ((pool-id (var-get next-pool-id)))
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
    
    ;; Create pool
    (map-set yield-pools pool-id
      {
        pool-name: pool-name,
        pool-type: pool-type,
        total-deposited: u0,
        total-yield-available: u0,
        total-yield-distributed: u0,
        distribution-strategy: distribution-strategy,
        reward-token: reward-token,
        creation-block: block-height,
        last-distribution: block-height,
        active: true,
        admin: tx-sender
      })
    
    (var-set next-pool-id (+ pool-id u1))
    
    (print (tuple (event "yield-pool-created") (pool-id pool-id) (name pool-name) (type pool-type)))
    
    (ok pool-id)))

;; === PARTICIPANT MANAGEMENT ===
(define-public (join-yield-pool (pool-id uint) (stake-amount uint))
  (begin
    (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND))
          (participant tx-sender))
      
      (asserts! (get active pool) ERR_UNAUTHORIZED)
      (asserts! (> stake-amount u0) ERR_INVALID_AMOUNT)
      
      ;; Update or create participant record
      (let ((current-stake (default-to 
                             {stake-amount: u0, total-claimed: u0, last-claim-block: block-height,
                              weight-multiplier: u10000, tier-level: u1, vesting-start: u0, vesting-duration: u0}
                             (map-get? pool-participants {pool-id: pool-id, participant: participant}))))
        
        (map-set pool-participants {pool-id: pool-id, participant: participant}
          (merge current-stake {stake-amount: (+ (get stake-amount current-stake) stake-amount)}))
        
        ;; Update pool totals
        (map-set yield-pools pool-id
          (merge pool {total-deposited: (+ (get total-deposited pool) stake-amount)}))
        
        (print (tuple (event "joined-yield-pool") (participant participant) (pool-id pool-id) (amount stake-amount)))
        
        (ok true)))))

;; === YIELD DISTRIBUTION ===
(define-public (add-yield-to-pool (pool-id uint) (yield-amount uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    
    ;; Only pool admin or integrated contracts can add yield
    (asserts! (or (is-pool-admin pool-id) (is-admin)
                  (is-eq (some tx-sender) (var-get bond-contract))
                  (is-eq (some tx-sender) (var-get enterprise-loan-manager))) ERR_UNAUTHORIZED)
    
    (asserts! (> yield-amount u0) ERR_INVALID_AMOUNT)
    
    ;; Add yield to pool
    (map-set yield-pools pool-id
      (merge pool {total-yield-available: (+ (get total-yield-available pool) yield-amount)}))
    
    (print (tuple (event "yield-added-to-pool") (pool-id pool-id) (amount yield-amount)))
    
    (ok true)))

(define-public (distribute-yield (pool-id uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (begin
      (asserts! (get active pool) ERR_UNAUTHORIZED)
      (asserts! (> (get total-yield-available pool) u0) ERR_INVALID_AMOUNT)
      
      ;; Execute distribution based on strategy; convert strategy into a deterministic branch
      (let ((strategy (get distribution-strategy pool)))
        (let ((exec-result
                (if (is-eq strategy "PROPORTIONAL")
                  (distribute-proportional pool-id)
                  (if (is-eq strategy "WEIGHTED")
                    (distribute-weighted pool-id)
                    (if (is-eq strategy "TIERED")
                      (distribute-tiered pool-id)
                      (if (is-eq strategy "VESTING")
                        (distribute-vesting pool-id)
                        (ok false)))))))
          (try! exec-result)))
      
      ;; Update pool last distribution
      (map-set yield-pools pool-id
        (merge pool {last-distribution: block-height}))
      
      (ok true))))

;; === DISTRIBUTION STRATEGIES ===
(define-private (distribute-proportional (pool-id uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    ;; This is a simplified implementation - in practice would iterate through all participants
    ;; For now, just mark as distributed
    (map-set yield-pools pool-id
      (merge pool 
             {total-yield-distributed: (+ (get total-yield-distributed pool) (get total-yield-available pool)),
              total-yield-available: u0}))
    (ok true)))

(define-private (distribute-weighted (pool-id uint))
  ;; Weighted distribution based on multipliers
  (distribute-proportional pool-id)) ;; Simplified

(define-private (distribute-tiered (pool-id uint))
  ;; Tiered distribution with different rates per tier
  (distribute-proportional pool-id)) ;; Simplified

(define-private (distribute-vesting (pool-id uint))
  ;; Vesting-based distribution
  (distribute-proportional pool-id)) ;; Simplified

;; === CLAIM FUNCTIONS ===
(define-public (claim-yield (pool-id uint))
  (begin
    (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND))
          (participant tx-sender)
          (stake-info (unwrap! (map-get? pool-participants {pool-id: pool-id, participant: participant}) ERR_UNAUTHORIZED)))
      
      (asserts! (get active pool) ERR_UNAUTHORIZED)
      
      ;; Calculate claimable amount
      (let ((claimable (calculate-claimable-yield pool-id participant)))
        (asserts! (> claimable u0) ERR_INVALID_AMOUNT)
        
        ;; Update participant claim record
        (map-set pool-participants {pool-id: pool-id, participant: participant}
          (merge stake-info 
                 {total-claimed: (+ (get total-claimed stake-info) claimable),
                  last-claim-block: block-height}))
        
        ;; TODO: Transfer yield tokens to participant
        ;; (try! (as-contract (contract-call? (get reward-token pool) transfer claimable tx-sender participant none)))
        
        (print (tuple (event "yield-claimed") (participant participant) (pool-id pool-id) (amount claimable)))
        
        (ok claimable)))))

;; === AUTOMATED DISTRIBUTION SCHEDULES ===
(define-public (create-distribution-schedule
  (pool-id uint)
  (frequency-blocks uint)
  (amount-per-distribution uint)
  (total-distributions uint)
  (auto-compound bool))
  
  (let ((schedule-id (var-get next-schedule-id))
        (pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    
    (asserts! (is-pool-admin pool-id) ERR_UNAUTHORIZED)
    (asserts! (> frequency-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (> amount-per-distribution u0) ERR_INVALID_AMOUNT)
    (asserts! (> total-distributions u0) ERR_INVALID_AMOUNT)
    
    ;; Create schedule
    (map-set distribution-schedules schedule-id
      {
        pool-id: pool-id,
        frequency-blocks: frequency-blocks,
        amount-per-distribution: amount-per-distribution,
        next-distribution-block: (+ block-height frequency-blocks),
        remaining-distributions: total-distributions,
        auto-compound: auto-compound,
        active: true
      })
    
    (var-set next-schedule-id (+ schedule-id u1))
    
    (print (tuple (event "distribution-schedule-created") (schedule-id schedule-id) (pool-id pool-id)))
    
    (ok schedule-id)))

(define-public (execute-scheduled-distribution (schedule-id uint))
  (let ((schedule (unwrap! (map-get? distribution-schedules schedule-id) ERR_SCHEDULE_NOT_FOUND)))
    
    (asserts! (get active schedule) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get next-distribution-block schedule)) ERR_UNAUTHORIZED)
    (asserts! (> (get remaining-distributions schedule) u0) ERR_INVALID_AMOUNT)
    
    ;; Add yield to pool
    (try! (add-yield-to-pool (get pool-id schedule) (get amount-per-distribution schedule)))
    
    ;; Distribute if not auto-compounding
    (try! (if (not (get auto-compound schedule))
            (distribute-yield (get pool-id schedule))
            (ok true)))
    
    ;; Update schedule
    (map-set distribution-schedules schedule-id
      (merge schedule 
             {next-distribution-block: (+ (get next-distribution-block schedule) (get frequency-blocks schedule)),
              remaining-distributions: (- (get remaining-distributions schedule) u1),
              active: (> (get remaining-distributions schedule) u1)}))
    
    (print (tuple (event "scheduled-distribution-executed") (schedule-id schedule-id)))
    
    (ok true)))

;; === ENTERPRISE LOAN INTEGRATION ===
(define-public (allocate-enterprise-loan-yield 
  (loan-id uint) 
  (total-interest uint)
  (bond-holder-share-bps uint))
  (begin
    (let ((caller tx-sender))
      (asserts! (is-eq (some caller) (var-get enterprise-loan-manager)) ERR_UNAUTHORIZED)
      
      ;; Calculate yield allocations
      (let ((bond-share (/ (* total-interest bond-holder-share-bps) BASIS_POINTS))
            (protocol-share (/ (* total-interest (var-get protocol-share-bps)) BASIS_POINTS))
            (treasury-share (/ (* total-interest (var-get treasury-share-bps)) BASIS_POINTS))
            (remaining (- total-interest (+ bond-share protocol-share treasury-share))))
        
        ;; Record allocation
        (map-set enterprise-yield-allocation loan-id
          {
            total-interest-generated: total-interest,
            bond-holder-share: bond-share,
            protocol-share: protocol-share,
            treasury-share: treasury-share,
            distributed-to-bonds: u0,
            last-allocation-block: block-height
          })
        
        ;; TODO: Distribute to appropriate pools
        ;; (try! (add-yield-to-pool BOND_POOL_ID bond-share))
        
        (print (tuple (event "enterprise-yield-allocated") (loan-id loan-id) (total-interest total-interest)))
        
        (ok true)))))

;; === BOND YIELD INTEGRATION ===
(define-public (track-bond-yield (bond-series uint) (loan-id uint) (yield-amount uint) (yield-rate uint))
  (let ((caller tx-sender))
    (asserts! (is-eq (some caller) (var-get bond-contract)) ERR_UNAUTHORIZED)
    
    ;; Track bond-specific yield
    (let ((current-tracking (default-to 
                              {allocated-yield: u0, distributed-yield: u0, last-payment-block: u0, yield-rate: u0}
                              (map-get? bond-yield-tracking {bond-series: bond-series, loan-id: loan-id}))))
      
      (map-set bond-yield-tracking {bond-series: bond-series, loan-id: loan-id}
        (merge current-tracking 
               {allocated-yield: (+ (get allocated-yield current-tracking) yield-amount),
                last-payment-block: block-height,
                yield-rate: yield-rate}))
      
      (print (tuple (event "bond-yield-tracked") (bond-series bond-series) (loan-id loan-id) (yield yield-amount)))
      
      (ok true))))

;; === UTILITY FUNCTIONS ===
(define-private (calculate-claimable-yield (pool-id uint) (participant principal))
  (let ((pool (unwrap-panic (map-get? yield-pools pool-id)))
        (stake-info (unwrap-panic (map-get? pool-participants {pool-id: pool-id, participant: participant}))))
    
    (if (is-eq (get total-deposited pool) u0)
      u0
      (let ((participant-share (/ (* (get stake-amount stake-info) PRECISION) (get total-deposited pool)))
            (total-available (get total-yield-available pool)))
        (/ (* total-available participant-share) PRECISION)))))

;; === READ-ONLY FUNCTIONS ===
(define-read-only (get-yield-pool (pool-id uint))
  (map-get? yield-pools pool-id))

(define-read-only (get-participant-info (pool-id uint) (participant principal))
  (map-get? pool-participants {pool-id: pool-id, participant: participant}))

(define-read-only (get-distribution-schedule (schedule-id uint))
  (map-get? distribution-schedules schedule-id))

(define-read-only (get-claimable-yield (pool-id uint) (participant principal))
  (ok (calculate-claimable-yield pool-id participant)))

(define-read-only (get-enterprise-yield-allocation (loan-id uint))
  (map-get? enterprise-yield-allocation loan-id))

(define-read-only (get-bond-yield-tracking (bond-series uint) (loan-id uint))
  (map-get? bond-yield-tracking {bond-series: bond-series, loan-id: loan-id}))

(define-read-only (get-pool-stats (pool-id uint))
  (match (map-get? yield-pools pool-id)
    pool
      (ok (tuple
        (pool-id pool-id)
        (name (get pool-name pool))
        (type (get pool-type pool))
        (total-deposited (get total-deposited pool))
        (total-yield-available (get total-yield-available pool))
        (total-yield-distributed (get total-yield-distributed pool))
        (participant-count u0) ;; Would need to track this separately
        (active (get active pool))))
    ERR_POOL_NOT_FOUND))

(define-read-only (get-system-overview)
  (ok (tuple
    (total-pools (- (var-get next-pool-id) u1))
    (total-schedules (- (var-get next-schedule-id) u1))
    (total-yield-distributed (var-get total-yield-distributed))
    (system-paused (var-get system-paused))
    (distribution-fee-bps (var-get distribution-fee-bps)))))

;; === EMERGENCY FUNCTIONS ===
(define-public (emergency-pause)
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set system-paused true)
    (print (tuple (event "emergency-pause") (block block-height)))
    (ok true)))

(define-public (emergency-unpause)
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set system-paused false)
    (print (tuple (event "emergency-unpause") (block block-height)))
    (ok true)))

;; Batch processing for large distributions
(define-public (batch-distribute-yield (pool-ids (list 10 uint)))
  (let ((results (map distribute-yield pool-ids)))
    (print (tuple (event "batch-yield-distribution") (pools (len pool-ids))))
    (ok results)))

;; Advanced analytics
(define-read-only (calculate-apy (pool-id uint))
  ;; Calculate annualized percentage yield
  (match (map-get? yield-pools pool-id)
    pool
      (let ((total-yield-year (get total-yield-distributed pool)) ;; Simplified
            (total-deposited (get total-deposited pool)))
        (if (> total-deposited u0)
          (ok (/ (* total-yield-year BASIS_POINTS) total-deposited))
          (ok u0)))
    ERR_POOL_NOT_FOUND))





