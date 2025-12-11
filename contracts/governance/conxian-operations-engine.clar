;; conxian-operations-engine.clar
;; Automated operations & resilience governance seat for the Conxian Protocol.
;; Configuration, read-only views, and a first safe execute-vote implementation.

(define-constant ERR_UNAUTHORIZED (err u7000))

;; --- Core Configuration ---

(define-data-var contract-owner principal tx-sender)
(define-data-var proposal-engine principal .proposal-engine)
(define-data-var proposal-registry principal .proposal-registry)
(define-data-var governance-token principal .governance-token)
(define-data-var governance-voting principal .governance-voting)
(define-data-var governance-nft-contract (optional principal) none)
(define-data-var operations-council-token-id (optional uint) none)
(define-data-var metrics-registry (optional principal) none)

(define-data-var emission-controller (optional principal) none)

(define-data-var lending-system (optional principal) none)

(define-data-var mev-system (optional principal) none)

(define-data-var insurance-system (optional principal) none)

(define-data-var bridge-system (optional principal) none)

(define-map auto-support-proposals uint bool)
(define-map auto-abstain-proposals uint bool)

;; ===========================================
;; BEHAVIOR METRICS & REPUTATION SYSTEM
;; ===========================================
;; Track and incentivize excellent behavior across the protocol

;; User behavior metrics
(define-map user-behavior-metrics
  principal
  {
    reputation-score: uint, ;; 0-10000 reputation score
    governance-participation: uint, ;; Number of proposals voted on
    lending-health-score: uint, ;; Average health factor (0-10000)
    mev-protection-score: uint, ;; MEV protection usage score
    insurance-coverage-score: uint, ;; Insurance coverage score
    bridge-reliability-score: uint, ;; Cross-chain bridge reliability
    total-protocol-value: uint, ;; Total value contributed to protocol
    last-updated: uint, ;; Last metrics update block
    behavior-tier: uint, ;; 1=bronze, 2=silver, 3=gold, 4=platinum
    incentive-multiplier: uint, ;; Reward multiplier (100-300)
  }
)

;; Governance behavior tracking
(define-map governance-behavior
  principal
  {
    proposals-voted: uint,
    proposals-created: uint,
    voting-accuracy: uint, ;; Alignment with successful outcomes (0-10000)
    delegation-trust-score: uint, ;; Trust score as delegatee
    council-participation: uint, ;; Council meeting participation
    emergency-response-count: uint, ;; Participation in emergency actions
    last-vote-block: uint,
  }
)

;; Lending behavior tracking
(define-map lending-behavior
  principal
  {
    average-health-factor: uint, ;; Historical average health factor
    liquidation-count: uint, ;; Number of liquidations (lower is better)
    timely-repayment-count: uint, ;; On-time repayments
    collateral-management-score: uint, ;; Quality of collateral management
    lending-volume: uint, ;; Total lending activity volume
    last-updated: uint,
  }
)

;; MEV protection behavior
(define-map mev-behavior
  principal
  {
    protection-usage-count: uint, ;; Times MEV protection was used
    attacks-prevented: uint, ;; Attacks successfully prevented
    protected-volume: uint, ;; Total volume protected
    mev-awareness-score: uint, ;; Understanding of MEV risks (0-10000)
    last-updated: uint,
  }
)

;; Insurance behavior
(define-map insurance-behavior
  principal
  {
    coverage-utilization: uint, ;; How well coverage is utilized
    claims-filed: uint, ;; Number of claims
    claims-approved: uint, ;; Approved claims (quality indicator)
    premium-payment-reliability: uint, ;; Payment reliability score
    risk-management-score: uint, ;; Overall risk management quality
    last-updated: uint,
  }
)

;; Bridge behavior
(define-map bridge-behavior
  principal
  {
    successful-bridges: uint, ;; Successful cross-chain transfers
    failed-bridges: uint, ;; Failed transfers
    bridge-volume: uint, ;; Total bridged volume
    bridge-reliability: uint, ;; Reliability score (0-10000)
    security-awareness-score: uint, ;; Bridge security awareness
    last-updated: uint,
  }
)

;; Behavior tier thresholds
(define-constant TIER_BRONZE_THRESHOLD u1000)
(define-constant TIER_SILVER_THRESHOLD u3000)
(define-constant TIER_GOLD_THRESHOLD u6000)
(define-constant TIER_PLATINUM_THRESHOLD u9000)

;; Incentive multipliers by tier
(define-constant MULTIPLIER_BRONZE u100) ;; 1.0x
(define-constant MULTIPLIER_SILVER u125) ;; 1.25x
(define-constant MULTIPLIER_GOLD u150) ;; 1.5x
(define-constant MULTIPLIER_PLATINUM u200) ;; 2.0x
(define-constant MULTIPLIER_MAX u300) ;; 3.0x (exceptional behavior)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

;; --- Public Read-Only Views ---

(define-read-only (get-config)
  {
    contract-owner: (var-get contract-owner),
    proposal-engine: (var-get proposal-engine),
    proposal-registry: (var-get proposal-registry),
    governance-token: (var-get governance-token),
    governance-voting: (var-get governance-voting),
    governance-nft-contract: (var-get governance-nft-contract),
    operations-council-token-id: (var-get operations-council-token-id),
    metrics-registry: (var-get metrics-registry),
    emission-controller: (var-get emission-controller),
    lending-system: (var-get lending-system),
    mev-system: (var-get mev-system),
    insurance-system: (var-get insurance-system),
    bridge-system: (var-get bridge-system)
  }
)

;; Placeholder policy fields. These will be expanded into structured
;; parameters as the engine is wired to real risk/treasury thresholds.
(define-read-only (get-policy)
  {
    legex-policy: u0,
    devex-policy: u0,
    opex-policy: u0,
    capex-policy: u0,
    invex-policy: u0
  }
)

;; --- Operations Status ---

(define-read-only (get-operations-status)
  (let (
        (health (contract-call? .token-system-coordinator get-system-health))
        (circuit-result (contract-call? .circuit-breaker is-circuit-open))
       )
    (let ((circuit-open (if (is-ok circuit-result)
                            (unwrap-panic circuit-result)
                            false)))
      {
        is-paused: (get is-paused health),
        emergency-mode: (get emergency-mode health),
        total-registered-tokens: (get total-registered-tokens health),
        total-users: (get total-users health),
        coordinator-version: (get coordinator-version health),
        circuit-open: circuit-open,
      }
    )
  )
)

(define-read-only (get-ops-dashboard)
  (let (
      (ops (get-operations-status))
      (policy (get-policy))
    )
    {
      is-paused: (get is-paused ops),
      emergency-mode: (get emergency-mode ops),
      circuit-open: (get circuit-open ops),
      total-registered-tokens: (get total-registered-tokens ops),
      total-users: (get total-users ops),
      coordinator-version: (get coordinator-version ops),
      legex-policy: (get legex-policy policy),
      devex-policy: (get devex-policy policy),
      opex-policy: (get opex-policy policy),
      capex-policy: (get capex-policy policy),
      invex-policy: (get invex-policy policy),
    }
  )
)

(define-public (get-emission-limits (token principal))
  (contract-call? .token-emission-controller get-token-emission-limits token)
)

;; ===========================================
;; DASHBOARD AGGREGATION FUNCTIONS
;; ===========================================
;; These functions aggregate data from various system contracts
;; Uses static contract references for production reliability

;; Get user's lending health factor from comprehensive lending system
(define-public (get-user-lending-health (user principal))
  (contract-call? .comprehensive-lending-system get-health-factor user)
)

;; Get user's insurance coverage summary
(define-public (get-user-insurance-dashboard (user principal))
  ;; Returns basic insurance metrics
  ;; TODO: Integrate with actual insurance contract when available
  (ok {
    has-coverage: false,
    total-coverage: u0,
    active-policies: u0,
    last-updated: block-height,
  })
)

;; Get user's MEV protection status
(define-public (get-user-mev-dashboard (user principal))
  ;; Returns MEV protection metrics
  ;; TODO: Integrate with mev-protector contract
  (ok {
    protection-active: false,
    protected-volume: u0,
    attacks-prevented: u0,
    last-updated: block-height,
  })
)

;; Get user's bridge positions
(define-public (get-user-bridge-dashboard (user principal))
  ;; Returns cross-chain bridge positions
  ;; TODO: Integrate with bridge contracts
  (ok {
    active-bridges: u0,
    total-bridged: u0,
    pending-transfers: u0,
    last-updated: block-height,
  })
)

;; Get emission governance metrics for a token
(define-public (get-emission-governance-dashboard (token principal))
  ;; Aggregates emission data from token-emission-controller
  ;; Returns structured emission metrics or defaults if data unavailable
  (ok {
    token: token,
    current-block: block-height,
    last-updated: block-height,
    note: "Call get-emission-limits and get-emission-epoch directly for detailed metrics",
  })
)

;; Get comprehensive operations dashboard
(define-read-only (get-operations-dashboard)
  {
    system-status: (get-operations-status),
    config: (get-config),
    block-height: block-height,
    timestamp: block-height,
  }
)

;; ===========================================

(define-public (get-emission-epoch
    (token principal)
    (epoch uint)
  )
  (contract-call? .token-emission-controller get-epoch-emissions token epoch)
)

;; ===========================================
;; BEHAVIOR METRICS READ-ONLY FUNCTIONS
;; ===========================================

(define-read-only (get-user-behavior-metrics (user principal))
  (default-to {
    reputation-score: u0,
    governance-participation: u0,
    lending-health-score: u0,
    mev-protection-score: u0,
    insurance-coverage-score: u0,
    bridge-reliability-score: u0,
    total-protocol-value: u0,
    last-updated: u0,
    behavior-tier: u1,
    incentive-multiplier: MULTIPLIER_BRONZE,
  }
    (map-get? user-behavior-metrics user)
  )
)

(define-read-only (get-governance-behavior (user principal))
  (default-to {
    proposals-voted: u0,
    proposals-created: u0,
    voting-accuracy: u0,
    delegation-trust-score: u0,
    council-participation: u0,
    emergency-response-count: u0,
    last-vote-block: u0,
  }
    (map-get? governance-behavior user)
  )
)

(define-read-only (get-lending-behavior (user principal))
  (default-to {
    average-health-factor: u0,
    liquidation-count: u0,
    timely-repayment-count: u0,
    collateral-management-score: u0,
    lending-volume: u0,
    last-updated: u0,
  }
    (map-get? lending-behavior user)
  )
)

(define-read-only (get-mev-behavior (user principal))
  (default-to {
    protection-usage-count: u0,
    attacks-prevented: u0,
    protected-volume: u0,
    mev-awareness-score: u0,
    last-updated: u0,
  }
    (map-get? mev-behavior user)
  )
)

(define-read-only (get-insurance-behavior (user principal))
  (default-to {
    coverage-utilization: u0,
    claims-filed: u0,
    claims-approved: u0,
    premium-payment-reliability: u0,
    risk-management-score: u0,
    last-updated: u0,
  }
    (map-get? insurance-behavior user)
  )
)

(define-read-only (get-bridge-behavior (user principal))
  (default-to {
    successful-bridges: u0,
    failed-bridges: u0,
    bridge-volume: u0,
    bridge-reliability: u0,
    security-awareness-score: u0,
    last-updated: u0,
  }
    (map-get? bridge-behavior user)
  )
)

;; Calculate comprehensive behavior score
(define-read-only (calculate-behavior-score (user principal))
  (let (
      (metrics (get-user-behavior-metrics user))
      (gov (get-governance-behavior user))
      (lending (get-lending-behavior user))
      (mev (get-mev-behavior user))
      (insurance (get-insurance-behavior user))
      (bridge (get-bridge-behavior user))
    )
    (let (
        ;; Weight each component (total = 10000)
        (gov-score (/ (* (get voting-accuracy gov) u2000) u10000)) ;; 20% weight
        (lending-score (/ (* (get collateral-management-score lending) u2500) u10000)) ;; 25% weight
        (mev-score (/ (* (get mev-awareness-score mev) u1500) u10000)) ;; 15% weight
        (insurance-score (/ (* (get risk-management-score insurance) u1500) u10000)) ;; 15% weight
        (bridge-score (/ (* (get bridge-reliability bridge) u1500) u10000)) ;; 15% weight
        (participation-bonus (/ (* (+ (get proposals-voted gov) (get proposals-created gov)) u10) u1)) ;; 10% weight
      )
      (+ gov-score lending-score mev-score insurance-score bridge-score
        participation-bonus
      )
    )
  )
)

;; Determine behavior tier based on score
(define-read-only (get-behavior-tier (score uint))
  (if (>= score TIER_PLATINUM_THRESHOLD)
    u4
    (if (>= score TIER_GOLD_THRESHOLD)
      u3
      (if (>= score TIER_SILVER_THRESHOLD)
        u2
        u1
      )
    )
  )
)

;; Get incentive multiplier based on tier
(define-read-only (get-incentive-multiplier (tier uint))
  (if (is-eq tier u4)
    MULTIPLIER_PLATINUM
    (if (is-eq tier u3)
      MULTIPLIER_GOLD
      (if (is-eq tier u2)
        MULTIPLIER_SILVER
        MULTIPLIER_BRONZE
      )
    )
  )
)

;; Comprehensive behavior dashboard
(define-read-only (get-user-behavior-dashboard (user principal))
  (let (
      (score (calculate-behavior-score user))
      (tier (get-behavior-tier score))
      (multiplier (get-incentive-multiplier tier))
    )
    {
      user: user,
      overall-score: score,
      behavior-tier: tier,
      incentive-multiplier: multiplier,
      metrics: (get-user-behavior-metrics user),
      governance: (get-governance-behavior user),
      lending: (get-lending-behavior user),
      mev: (get-mev-behavior user),
      insurance: (get-insurance-behavior user),
      bridge: (get-bridge-behavior user),
      last-updated: block-height,
    }
  )
)

;; Check that an operations council NFT seat is configured. Full ownership
;; verification would require a static NFT contract; for now we require both
;; contract and token-id to be set before allowing automated votes.
(define-private (has-operations-seat)
  (and (is-some (var-get governance-nft-contract))
       (is-some (var-get operations-council-token-id)))
)

;; --- Evaluation & Voting ---

(define-read-only (evaluate-proposal (proposal-id uint))
  (let ((ops (get-operations-status)))
    (if (or (get is-paused ops) (get emergency-mode ops) (get circuit-open ops))
      (ok {
        support: false,
        abstain: true,
        reason-code: u1   ;; SYSTEM_STRESSED
      })
      (let (
            (support-flag (default-to false (map-get? auto-support-proposals proposal-id)))
            (abstain-flag (default-to false (map-get? auto-abstain-proposals proposal-id)))
           )
        (if support-flag
          (ok {
            support: true,
            abstain: false,
            reason-code: u2
          })
          (if abstain-flag
            (ok {
              support: false,
              abstain: true,
              reason-code: u3
            })
            (ok {
              support: false,
              abstain: true,
              reason-code: u0
            })
          )
        )
      )
    )
  )
)

;; First safe execute-vote: only forwards a vote when the system is healthy.
;; The caller supplies support and votes-cast; the engine enforces ops guardrails.
(define-public (execute-vote (proposal-id uint) (support bool) (votes-cast uint))
  (let ((ops (get-operations-status)))
    (if (or (get is-paused ops) (get emergency-mode ops) (get circuit-open ops))
      (ok false)
      (if (not (has-operations-seat))
        (ok false)
        (as-contract (contract-call? .proposal-engine vote proposal-id support votes-cast))
      ))
  )
)

;; --- Admin Functions ---

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-governance-contracts
    (new-proposal-engine principal)
    (new-proposal-registry principal)
    (new-governance-token principal)
    (new-governance-voting principal)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set proposal-engine new-proposal-engine)
    (var-set proposal-registry new-proposal-registry)
    (var-set governance-token new-governance-token)
    (var-set governance-voting new-governance-voting)
    (ok true)
  )
)

(define-public (set-governance-nft
    (nft-contract principal)
    (token-id uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set governance-nft-contract (some nft-contract))
    (var-set operations-council-token-id (some token-id))
    (ok true)
  )
)

(define-public (set-metrics-registry (registry principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set metrics-registry (some registry))
    (ok true)
  )
)

(define-public (set-emission-controller (controller principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set emission-controller (some controller))
    (ok true)
  )
)

(define-public (set-lending-system (system principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set lending-system (some system))
    (ok true)
  )
)

(define-public (set-mev-system (system principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set mev-system (some system))
    (ok true)
  )
)

(define-public (set-insurance-system (system principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set insurance-system (some system))
    (ok true)
  )
)

(define-public (set-bridge-system (system principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set bridge-system (some system))
    (ok true)
  )
)

(define-public (set-auto-support-proposal (proposal-id uint) (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (if enabled
      (map-set auto-support-proposals proposal-id true)
      (map-delete auto-support-proposals proposal-id)
    )
    (ok true)
  )
)

(define-public (set-auto-abstain-proposal (proposal-id uint) (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (if enabled
      (map-set auto-abstain-proposals proposal-id true)
      (map-delete auto-abstain-proposals proposal-id)
    )
    (ok true)
  )
)

;; ===========================================
;; BEHAVIOR METRICS UPDATE FUNCTIONS
;; ===========================================
;; These functions update behavior metrics based on user actions

;; Update governance behavior after voting
(define-public (record-governance-action
    (user principal)
    (action-type (string-ascii 32))
    (voting-accuracy-delta int)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (let ((current (get-governance-behavior user)))
      (map-set governance-behavior user
        (merge current {
          proposals-voted: (if (is-eq action-type "vote")
            (+ (get proposals-voted current) u1)
            (get proposals-voted current)
          ),
          proposals-created: (if (is-eq action-type "create")
            (+ (get proposals-created current) u1)
            (get proposals-created current)
          ),
          voting-accuracy: (let ((new-accuracy (+ (to-int (get voting-accuracy current)) voting-accuracy-delta)))
            (if (< new-accuracy 0)
              u0
              (to-uint new-accuracy)
            )
          ),
          last-vote-block: block-height,
        })
      )
      (unwrap-panic (update-overall-behavior-metrics user))
      (ok true)
    )
  )
)

;; Update lending behavior
(define-public (record-lending-action
    (user principal)
    (health-factor uint)
    (was-liquidated bool)
    (timely-repayment bool)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (let ((current (get-lending-behavior user)))
      (map-set lending-behavior user
        (merge current {
          average-health-factor: (/ (+ (* (get average-health-factor current) u9) health-factor) u10),
          liquidation-count: (if was-liquidated
            (+ (get liquidation-count current) u1)
            (get liquidation-count current)
          ),
          timely-repayment-count: (if timely-repayment
            (+ (get timely-repayment-count current) u1)
            (get timely-repayment-count current)
          ),
          collateral-management-score: (if was-liquidated
            (/ (* (get collateral-management-score current) u95) u100)
            (let ((new-score (+ (get collateral-management-score current) u50)))
              (if (> new-score u10000)
                u10000
                new-score
              )
            )
          ),
          last-updated: block-height,
        })
      )
      (unwrap-panic (update-overall-behavior-metrics user))
      (ok true)
    )
  )
)

;; Update MEV protection behavior
(define-public (record-mev-action
    (user principal)
    (protection-used bool)
    (attack-prevented bool)
    (volume uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (let ((current (get-mev-behavior user)))
      (map-set mev-behavior user
        (merge current {
          protection-usage-count: (if protection-used
            (+ (get protection-usage-count current) u1)
            (get protection-usage-count current)
          ),
          attacks-prevented: (if attack-prevented
            (+ (get attacks-prevented current) u1)
            (get attacks-prevented current)
          ),
          protected-volume: (+ (get protected-volume current) volume),
          mev-awareness-score: (if protection-used
            (let ((new-score (+ (get mev-awareness-score current) u100)))
              (if (> new-score u10000)
                u10000
                new-score
              )
            )
            (get mev-awareness-score current)
          ),
          last-updated: block-height,
        })
      )
      (unwrap-panic (update-overall-behavior-metrics user))
      (ok true)
    )
  )
)

;; Update insurance behavior
(define-public (record-insurance-action
    (user principal)
    (claim-filed bool)
    (claim-approved bool)
    (premium-paid bool)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (let ((current (get-insurance-behavior user)))
      (map-set insurance-behavior user
        (merge current {
          claims-filed: (if claim-filed
            (+ (get claims-filed current) u1)
            (get claims-filed current)
          ),
          claims-approved: (if claim-approved
            (+ (get claims-approved current) u1)
            (get claims-approved current)
          ),
          premium-payment-reliability: (if premium-paid
            (let ((new-score (+ (get premium-payment-reliability current) u100)))
              (if (> new-score u10000)
                u10000
                new-score
              )
            )
            (/ (* (get premium-payment-reliability current) u95) u100)
          ),
          risk-management-score: (if (and claim-filed (not claim-approved))
            (/ (* (get risk-management-score current) u90) u100)
            (let ((new-score (+ (get risk-management-score current) u50)))
              (if (> new-score u10000)
                u10000
                new-score
              )
            )
          ),
          last-updated: block-height,
        })
      )
      (unwrap-panic (update-overall-behavior-metrics user))
      (ok true)
    )
  )
)

;; Update bridge behavior
(define-public (record-bridge-action
    (user principal)
    (bridge-successful bool)
    (volume uint)
  )
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (let ((current (get-bridge-behavior user)))
      (map-set bridge-behavior user
        (merge current {
          successful-bridges: (if bridge-successful
            (+ (get successful-bridges current) u1)
            (get successful-bridges current)
          ),
          failed-bridges: (if (not bridge-successful)
            (+ (get failed-bridges current) u1)
            (get failed-bridges current)
          ),
          bridge-volume: (+ (get bridge-volume current) volume),
          bridge-reliability: (let (
              (total-bridges (+ (get successful-bridges current) (get failed-bridges current) u1))
              (success-rate (/ (* (get successful-bridges current) u10000) total-bridges))
            )
            success-rate
          ),
          security-awareness-score: (if bridge-successful
            (let ((new-score (+ (get security-awareness-score current) u50)))
              (if (> new-score u10000)
                u10000
                new-score
              )
            )
            (/ (* (get security-awareness-score current) u95) u100)
          ),
          last-updated: block-height,
        })
      )
      (unwrap-panic (update-overall-behavior-metrics user))
      (ok true)
    )
  )
)

;; Update overall behavior metrics and tier
(define-private (update-overall-behavior-metrics (user principal))
  (let (
      (score (calculate-behavior-score user))
      (tier (get-behavior-tier score))
      (multiplier (get-incentive-multiplier tier))
      (current (get-user-behavior-metrics user))
    )
    (map-set user-behavior-metrics user
      (merge current {
        reputation-score: score,
        behavior-tier: tier,
        incentive-multiplier: multiplier,
        last-updated: block-height,
      })
    )
    (ok true)
  )
)