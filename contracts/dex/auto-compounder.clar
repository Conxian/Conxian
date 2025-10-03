;; auto-compounder.clar
;; This contract automatically compounds rewards for users.

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait yield-optimizer-trait .all-traits.yield-optimizer-trait)
(use-trait strategy-trait .all-traits.strategy-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait metrics-trait .all-traits.metrics-trait)
(use-trait performance-optimizer-trait .all-traits.performance-optimizer-trait)
(use-trait analytics-aggregator-trait .all-traits.analytics-aggregator-trait)
(use-trait sbtc-vault-trait .all-traits.sbtc-vault-trait)
(use-trait yield-distribution-engine-trait .all-traits.yield-distribution-engine-trait)

(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_NOTHING_TO_COMPOUND (err u8001))
(define-constant ERR_STRATEGY_ALREADY_EXISTS (err u8002))
(define-constant ERR_STRATEGY_NOT_FOUND (err u8003))
(define-constant ERR_CIRCUIT_OPEN (err u8004))
(define-constant ERR_INVALID_COMPOUND_INTERVAL (err u8005))
(define-constant ERR_COMPOUND_NOT_DUE (err u8006))
(define-constant ERR_NO_REWARDS_TO_HARVEST (err u8007))
(define-constant ERR_NOTHING_TO_WITHDRAW (err u8008))
(define-constant ERR_INSUFFICIENT_FUNDS (err u8009))

(define-data-var contract-owner principal tx-sender)
(define-data-var yield-optimizer (contract-of yield-optimizer-trait) (as-contract tx-sender))
(define-data-var metrics-contract (contract-of metrics-trait) (as-contract tx-sender))
(define-data-var performance-optimizer-contract (contract-of performance-optimizer-trait) (as-contract tx-sender))
(define-data-var compounding-fee-bps uint u10) ;; 0.1% fee
(define-data-var circuit-breaker (optional principal) none)
(define-data-var total-deposited uint u0)
;; missing error constants referenced later
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE (err u8005))
(define-constant ERR_NO_STRATEGY_FOR_PAIR (err u8006))

(define-map user-positions { user: principal, strategy-id: uint, token: principal } { amount: uint, last-compounded: uint })
(define-map strategies { strategy-id: uint } { contract: principal, last-compound-block: uint, reward-token: principal })

;; Data map to store metrics for each strategy
;; { strategy-id: uint } => { reward-cycle: uint, gas-cost: uint, yield-efficiency: uint }
(define-map strategy-metrics { strategy-id: uint } { reward-cycle: uint, gas-cost: uint, yield-efficiency: uint, vault-performance: uint })

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb
    (asserts! (not (unwrap-panic (contract-call? cb is-circuit-open))) ERR_CIRCUIT_OPEN)
    (ok true)
  )
)

(define-public (set-strategy-metrics (strategy-id uint) (reward-cycle uint) (gas-cost uint) (yield-efficiency uint) (vault-performance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? strategies { strategy-id: strategy-id })) ERR_STRATEGY_NOT_FOUND)
    (map-set strategy-metrics { strategy-id: strategy-id } {
      reward-cycle: reward-cycle,
      gas-cost: gas-cost,
      yield-efficiency: yield-efficiency,
      vault-performance: vault-performance
    })
    (ok true)
  )
)

(define-public (add-strategy (strategy-id uint) (strategy-contract principal) (reward-token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? strategies { strategy-id: strategy-id })) ERR_STRATEGY_ALREADY_EXISTS)
    (map-set strategies { strategy-id: strategy-id } {
      contract: strategy-contract,
      last-compound-block: block-height,
      reward-token: reward-token
    })
    (ok true)
  )
)

(define-public (remove-strategy (strategy-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? strategies { strategy-id: strategy-id })) ERR_STRATEGY_NOT_FOUND)
    (map-delete strategies { strategy-id: strategy-id })
    (ok true)
  )
)

(define-public (set-circuit-breaker (cb principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

(define-public (deposit (strategy-id uint) (token principal) (amount uint))
  (begin
    (try! (check-circuit-breaker))
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)))
    (let ((position (default-to { amount: u0, last-compounded: block-height } (map-get? user-positions { user: tx-sender, strategy-id: strategy-id, token: token }))))
      (map-set user-positions { user: tx-sender, strategy-id: strategy-id, token: token } (merge position { amount: (+ (get amount position) amount) }))
      (var-set total-deposited (+ (var-get total-deposited) amount))
      (ok true)
    )
  )
)

(define-public (withdraw (strategy-id uint) (token principal) (amount uint))
  (begin
    (try! (check-circuit-breaker))
    (let ((position (unwrap! (map-get? user-positions { user: tx-sender, strategy-id: strategy-id, token: token }) (err ERR_NOTHING_TO_WITHDRAW))))
      (asserts! (>= (get amount position) amount) (err ERR_INSUFFICIENT_FUNDS))
      (try! (as-contract (contract-call? token transfer amount (as-contract tx-sender) tx-sender)))
      (map-set user-positions { user: tx-sender, strategy-id: strategy-id, token: token } (merge position { amount: (- (get amount position) amount) }))
      (var-set total-deposited (- (var-get total-deposited) amount))
      (ok true)
    )
  )
)

(define-public (auto-compound (strategy-id uint) (vault-contract <sbtc-vault-trait>))
  (begin
    (try! (check-circuit-breaker))
    (let (
        (strategy-info (unwrap! (map-get? strategies { strategy-id: strategy-id }) ERR_STRATEGY_NOT_FOUND))
        (metrics (unwrap! (map-get? strategy-metrics { strategy-id: strategy-id }) ERR_STRATEGY_NOT_FOUND))
        (yield-optimizer-principal (var-get yield-optimizer))
        (analytics-aggregator-principal (var-get analytics-aggregator-contract))
        (vault-stats (unwrap! (contract-call? vault-contract get-vault-stats) (err u100)))
        (total-assets (get total-sbtc vault-stats))
        (total-shares (get total-shares vault-stats))
        (performance-fee-bps (get performance-fee-bps vault-stats))
        (pool-id (unwrap! (contract-call? yield-optimizer-principal get-pool-id-for-strategy strategy-id) (err u101)))
        (apy (unwrap! (contract-call? .yield-distribution-engine calculate-apy pool-id) (err u102)))
        (performance-fee (/ (* total-assets performance-fee-bps) u10000))
      )
      (asserts! (>= block-height (+ (get last-compound-block strategy-info) (get reward-cycle metrics))) ERR_COMPOUND_NOT_DUE)

      ;; Call performance optimizer for gas efficiency
      (try! (contract-call? (var-get performance-optimizer-contract) optimize-gas-usage "auto-compound" "default"))

      ;; Call yield-optimizer to compound rewards for this strategy
      (let ((compounded-amount (try! (contract-call? (var-get yield-optimizer) compound-rewards strategy-id))))
        ;; Update last-compound-block in strategy-info
        (map-set strategies { strategy-id: strategy-id } (merge strategy-info { last-compound-block: block-height }))
        ;; Log metrics
        (print { event: "rewards-compounded", strategy-id: strategy-id, amount: compounded-amount, gas-cost: (get gas-cost metrics), yield-efficiency: (get yield-efficiency metrics), vault-performance: (get vault-performance metrics) })
        (try! (contract-call? analytics-aggregator-principal update-vault-metrics
          vault-contract
          total-assets
          total-shares
          apy
          performance-fee
        ))
        (ok true)
      )
    )
  )
)

;; Aggregate compounding for a set of users
(define-public (compound-all (strategy-id uint) (users (list 100 principal)))
  (let ((strategy-info (unwrap! (map-get? strategies { strategy-id: strategy-id }) (err ERR_STRATEGY_NOT_FOUND))))
    (let ((total-rewards (try! (contract-call? (get contract strategy-info) harvest-rewards))))
      (asserts! (> total-rewards u0) ERR_NO_REWARDS_TO_HARVEST)
      (let ((fee (/ (* total-rewards (var-get compounding-fee-bps)) u10000)))
        (try! (as-contract (contract-call? (get reward-token strategy-info) transfer fee tx-sender)))
        (let ((net-rewards (- total-rewards fee)))
          (fold (lambda (user-principal (current-net-rewards uint))
                  (let ((position (unwrap! (map-get? user-positions { user: user-principal, strategy-id: strategy-id, token: (get reward-token strategy-info) }) (err ERR_NOTHING_TO_COMPOUND))))
                    (let ((user-share (/ (* (get amount position) current-net-rewards) (unwrap-panic (get-total-deployed strategy-id (get reward-token strategy-info))))))
                      (map-set user-positions { user: user-principal, strategy-id: strategy-id, token: (get reward-token strategy-info) } (merge position { amount: (+ (get amount position) user-share) }))
                      (- current-net-rewards user-share))))
                users
                net-rewards)
          (ok true))))))

(define-public (compound (user principal) (strategy-id uint))
  (begin
    (try! (check-circuit-breaker))
    (let (
      (strategy-info (unwrap! (map-get? strategies { strategy-id: strategy-id }) ERR_STRATEGY_NOT_FOUND))
      (metrics (unwrap! (map-get? strategy-metrics { strategy-id: strategy-id }) ERR_STRATEGY_NOT_FOUND))
    )
      ;; Delegate compounding logic to yield-optimizer
      (let ((compounded-amount (try! (contract-call? (var-get yield-optimizer) compound-user-rewards user (get reward-token strategy-info)))))
        ;; Log metrics
        (print { event: "user-rewards-compounded", user: user, strategy-id: strategy-id, amount: compounded-amount, gas-cost: (get gas-cost metrics), yield-efficiency: (get yield-efficiency metrics), vault-performance: (get vault-performance metrics) })
        (ok compounded-amount))
    )
  )
)

;; Remove duplicate conflicting definition of compound-all with traited token

(define-read-only (get-position (user principal) (strategy-id uint) (token principal))
  (map-get? user-positions { user: user, strategy-id: strategy-id, token: token }))

(define-public (set-yield-optimizer-contract (optimizer (contract-of yield-optimizer-trait)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set yield-optimizer optimizer)
    (ok true)))

(define-public (set-metrics-contract (metrics (contract-of metrics-trait)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set metrics-contract metrics)
    (ok true)))

(define-public (set-performance-optimizer-contract (optimizer (contract-of performance-optimizer-trait)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set performance-optimizer-contract optimizer)
    (ok true)))

(define-data-var analytics-aggregator-contract principal .analytics-aggregator.analytics-aggregator)

(define-public (set-analytics-aggregator-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set analytics-aggregator-contract contract)
    (ok true)))

(define-read-only (get-total-deployed (strategy-id uint) (token principal)))
  (fold (lambda (key-value sum)
          (if (and (is-eq (get strategy-id key-value) strategy-id) (is-eq (get token key-value) token))
              (+ sum (get amount (map-get? user-positions key-value)))
              sum))
        (map-keys user-positions)
        u0))

