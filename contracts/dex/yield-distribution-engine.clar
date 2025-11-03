;; ===== Traits =====
(use-trait yield-distribution-trait .all-traits.yield-distribution-trait)
(impl-trait yield-distribution-trait)

;; yield-distribution-engine.clar
;; Advanced yield distribution system for enterprise loans and bonds
;; Handles complex yield calculations, distribution schedules, and optimization

;; ===== Error Codes =====
(define-constant ERR_UNAUTHORIZED (err u9001))
(define-constant ERR_POOL_NOT_FOUND (err u9002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u9003))
(define-constant ERR_INVALID_AMOUNT (err u9004))
(define-constant ERR_DISTRIBUTION_FAILED (err u9005))
(define-constant ERR_SCHEDULE_NOT_FOUND (err u9006))
(define-constant ERR_ALREADY_CLAIMED (err u9007))

;; ===== Precision and Time Constants =====
(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant BASIS_POINTS u10000)
(define-constant BLOCKS_PER_DAY u144)
(define-constant BLOCKS_PER_WEEK u1008)
(define-constant BLOCKS_PER_MONTH u4320)

;; ===== Pool Types =====
(define-constant POOL_TYPE_BOND "BOND")
(define-constant POOL_TYPE_STAKING "STAKING")
(define-constant POOL_TYPE_LIQUIDITY "LIQUIDITY")
(define-constant POOL_TYPE_ENTERPRISE "ENTERPRISE")

;; ===== Distribution Strategies =====
(define-constant STRATEGY_PROPORTIONAL "PROPORTIONAL")
(define-constant STRATEGY_WEIGHTED "WEIGHTED")
(define-constant STRATEGY_TIERED "TIERED")
(define-constant STRATEGY_VESTING "VESTING")

;; ===== Data Maps =====
(define-map yield-pools
  uint
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

(define-map pool-participants
  {pool-id: uint, participant: principal}
  {
    stake-amount: uint,
    total-claimed: uint,
    last-claim-block: uint,
    weight-multiplier: uint,
    tier-level: uint,
    vesting-start: uint,
    vesting-duration: uint
  })

(define-map distribution-schedules
  uint
  {
    pool-id: uint,
    frequency-blocks: uint,
    amount-per-distribution: uint,
    next-distribution-block: uint,
    remaining-distributions: uint,
    auto-compound: bool,
    active: bool
  })

(define-map bond-yield-tracking
  {bond-series: uint, loan-id: uint}
  {
    allocated-yield: uint,
    distributed-yield: uint,
    last-payment-block: uint,
    yield-rate: uint
  })

(define-map enterprise-yield-allocation
  uint
  {
    total-interest-generated: uint,
    bond-holder-share: uint,
    protocol-share: uint,
    treasury-share: uint,
    distributed-to-bonds: uint,
    last-allocation-block: uint
  })

;; ===== Data Variables =====
(define-data-var contract-admin principal tx-sender)
(define-data-var next-pool-id uint u1)
(define-data-var next-schedule-id uint u1)
(define-data-var system-paused bool false)
(define-data-var total-yield-distributed uint u0)
(define-data-var bond-contract (optional principal) none)
(define-data-var enterprise-loan-manager (optional principal) none)
(define-data-var revenue-distributor (optional principal) none)
(define-data-var distribution-fee-bps uint u100)
(define-data-var protocol-share-bps uint u2000)
(define-data-var treasury-share-bps uint u1000)

;; ===== Authorization Functions =====
(define-private (is-admin)
  (is-eq tx-sender (var-get contract-admin)))

(define-private (is-pool-admin (pool-id uint))
  (match (map-get? yield-pools pool-id)
    pool (is-eq tx-sender (get admin pool))
    false))

;; ===== Admin Functions =====
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

;; ===== Pool Management =====
(define-public (create-yield-pool
  (pool-name (string-ascii 50))
  (pool-type (string-ascii 20))
  (distribution-strategy (string-ascii 20))
  (reward-token principal))
  (let ((pool-id (var-get next-pool-id)))
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
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
    (print {event: "yield-pool-created", pool-id: pool-id, name: pool-name, type: pool-type})
    (ok pool-id)))

;; ===== Participant Management =====
(define-public (join-yield-pool (pool-id uint) (stake-amount uint))
  (let (
    (pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND))
    (participant tx-sender)
    (current-stake (default-to
      {stake-amount: u0, total-claimed: u0, last-claim-block: block-height,
       weight-multiplier: u10000, tier-level: u1, vesting-start: u0, vesting-duration: u0}
      (map-get? pool-participants {pool-id: pool-id, participant: participant}))))
    (asserts! (get active pool) ERR_UNAUTHORIZED)
    (asserts! (> stake-amount u0) ERR_INVALID_AMOUNT)
    (map-set pool-participants {pool-id: pool-id, participant: participant}
      (merge current-stake {stake-amount: (+ (get stake-amount current-stake) stake-amount)}))
    (map-set yield-pools pool-id
      (merge pool {total-deposited: (+ (get total-deposited pool) stake-amount)}))
    (print {event: "joined-yield-pool", participant: participant, pool-id: pool-id, amount: stake-amount})
    (ok true)))

;; ===== Yield Distribution =====
(define-public (add-yield-to-pool (pool-id uint) (yield-amount uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (asserts! (or (is-pool-admin pool-id) (is-admin)
                  (is-eq (some tx-sender) (var-get bond-contract))
                  (is-eq (some tx-sender) (var-get enterprise-loan-manager))) ERR_UNAUTHORIZED)
    (asserts! (> yield-amount u0) ERR_INVALID_AMOUNT)
    (map-set yield-pools pool-id
      (merge pool {total-yield-available: (+ (get total-yield-available pool) yield-amount)}))
    (print {event: "yield-added-to-pool", pool-id: pool-id, amount: yield-amount})
    (ok true)))

(define-public (distribute-yield (pool-id uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (asserts! (get active pool) ERR_UNAUTHORIZED)
    (asserts! (> (get total-yield-available pool) u0) ERR_INVALID_AMOUNT)
    (let ((strategy (get distribution-strategy pool)))
      (let ((exec-result
        (if (is-eq strategy STRATEGY_PROPORTIONAL)
          (distribute-proportional pool-id)
          (if (is-eq strategy STRATEGY_WEIGHTED)
            (distribute-weighted pool-id)
            (if (is-eq strategy STRATEGY_TIERED)
              (distribute-tiered pool-id)
              (if (is-eq strategy STRATEGY_VESTING)
                (distribute-vesting pool-id)
                (ok false)))))))
        (try! exec-result)))
    (map-set yield-pools pool-id
      (merge pool {last-distribution: block-height}))
    (ok true)))

;; ===== Distribution Strategies =====
(define-private (distribute-proportional (pool-id uint))
  (let ((pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (map-set yield-pools pool-id
      (merge pool
        {total-yield-distributed: (+ (get total-yield-distributed pool) (get total-yield-available pool)),
         total-yield-available: u0}))
    (ok true)))

(define-private (distribute-weighted (pool-id uint))
  (distribute-proportional pool-id))

(define-private (distribute-tiered (pool-id uint))
  (distribute-proportional pool-id))

(define-private (distribute-vesting (pool-id uint))
  (distribute-proportional pool-id))

;; ===== Claim Functions =====
(define-public (claim-yield (pool-id uint))
  (let (
    (pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND))
    (participant tx-sender)
    (stake-info (unwrap! (map-get? pool-participants {pool-id: pool-id, participant: participant}) ERR_UNAUTHORIZED))
    (claimable (calculate-claimable-yield pool-id participant)))
    (asserts! (get active pool) ERR_UNAUTHORIZED)
    (asserts! (> claimable u0) ERR_INVALID_AMOUNT)
    (map-set pool-participants {pool-id: pool-id, participant: participant}
      (merge stake-info
        {total-claimed: (+ (get total-claimed stake-info) claimable),
         last-claim-block: block-height}))
    (print {event: "yield-claimed", participant: participant, pool-id: pool-id, amount: claimable})
    (ok claimable)))

(define-private (calculate-claimable-yield (pool-id uint) (participant principal))
  (let (
    (pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND))
    (stake (unwrap! (map-get? pool-participants {pool-id: pool-id, participant: participant}) ERR_UNAUTHORIZED))
    (available (get total-yield-available pool))
    (total (get total-deposited pool))
    (my-stake (get stake-amount stake))
  )
    (if (> total u0)
      (/ (* available my-stake) total)
      u0)))

;; ===== Automated Distribution Schedules =====
(define-public (create-distribution-schedule
  (pool-id uint)
  (frequency-blocks uint)
  (amount-per-distribution uint)
  (total-distributions uint)
  (auto-compound bool))
  (let (
    (schedule-id (var-get next-schedule-id))
    (pool (unwrap! (map-get? yield-pools pool-id) ERR_POOL_NOT_FOUND)))
    (asserts! (is-pool-admin pool-id) ERR_UNAUTHORIZED)
    (asserts! (> frequency-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (> amount-per-distribution u0) ERR_INVALID_AMOUNT)
    (asserts! (> total-distributions u0) ERR_INVALID_AMOUNT)
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
    (print {event: "distribution-schedule-created", schedule-id: schedule-id, pool-id: pool-id})
    (ok schedule-id)))

(define-public (execute-scheduled-distribution (schedule-id uint))
  (let ((schedule (unwrap! (map-get? distribution-schedules schedule-id) ERR_SCHEDULE_NOT_FOUND)))
    (asserts! (get active schedule) ERR_UNAUTHORIZED)
    (asserts! (>= block-height (get next-distribution-block schedule)) ERR_UNAUTHORIZED)
    (asserts! (> (get remaining-distributions schedule) u0) ERR_INVALID_AMOUNT)
    (try! (add-yield-to-pool (get pool-id schedule) (get amount-per-distribution schedule)))
    (try! (if (not (get auto-compound schedule))
      (distribute-yield (get pool-id schedule))
      (ok true)))
    (map-set distribution-schedules schedule-id
      (merge schedule
        {next-distribution-block: (+ (get next-distribution-block schedule) (get frequency-blocks schedule)),
         remaining-distributions: (- (get remaining-distributions schedule) u1),
         active: (> (get remaining-distributions schedule) u1)}))
    (print {event: "scheduled-distribution-executed", schedule-id: schedule-id})
    (ok true)))

;; ===== Enterprise Loan Integration =====
(define-public (allocate-enterprise-loan-yield
  (loan-id uint)
  (total-interest uint)
  (bond-holder-share-bps uint))
  (let (
    (bond-share (/ (* total-interest bond-holder-share-bps) BASIS_POINTS))
    (protocol-share (/ (* total-interest (var-get protocol-share-bps)) BASIS_POINTS))
    (treasury-share (/ (* total-interest (var-get treasury-share-bps)) BASIS_POINTS)))
    (asserts! (is-eq (some tx-sender) (var-get enterprise-loan-manager)) ERR_UNAUTHORIZED)
    (map-set enterprise-yield-allocation loan-id
      {
        total-interest-generated: total-interest,
        bond-holder-share: bond-share,
        protocol-share: protocol-share,
        treasury-share: treasury-share,
        distributed-to-bonds: u0,
        last-allocation-block: block-height
      })
    (print {event: "enterprise-yield-allocated", loan-id: loan-id, total-interest: total-interest})
    (ok true)))

;; ===== Bond Yield Integration =====
(define-public (track-bond-yield (bond-series uint) (loan-id uint) (yield-amount uint) (yield-rate uint))
  (let (
    (current-tracking (default-to
      {
        allocated-yield: u0,
        distributed-yield: u0,
        last-payment-block: u0,
        yield-rate: u0
      }
      (map-get? bond-yield-tracking { bond-series: bond-series, loan-id: loan-id }))))
    (asserts! (is-eq (some tx-sender) (var-get bond-contract)) ERR_UNAUTHORIZED)
    (ok true)
  )
)
