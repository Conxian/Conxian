;; Conxian Yield Optimizer - Automated yield strategies
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait strategy-trait .all-traits.strategy-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait performance-optimizer-trait .all-traits.performance-optimizer-trait)
(use-trait analytics-aggregator-trait .all-traits.analytics-aggregator-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u601))
(define-constant ERR_STRATEGY_NOT_FOUND (err u602))
(define-constant ERR_INVALID_STRATEGY (err u603))
(define-constant ERR_CIRCUIT_OPEN (err u604))

(define-constant ERR_APY_CALCULATION_FAILED (err u103))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var strategy-counter uint u0)
(define-data-var circuit-breaker (optional principal) none)
(define-data-var performance-optimizer-contract (contract-of performance-optimizer-trait) (as-contract tx-sender))
(define-data-var analytics-aggregator-contract (contract-of analytics-aggregator-trait) (as-contract tx-sender))

;; --- Maps ---
;; Maps a strategy ID to its details
(define-map strategies uint {
  name: (string-ascii 64),
  contract: principal,
  risk-level: uint,
  yield-target: uint,
  created-at: uint,
  last-rebalanced: uint,
  total-compounded-rewards: uint,
  total-gas-cost: uint,
  reward-cycle: uint,
  yield-efficiency: uint,
  vault-performance: uint,
  pool-id: uint
})

;; Maps a user, pool ID and strategy ID to their deposit information
(define-map user-deposits { user: principal, pool-id: uint, strategy-id: uint } { amount: uint, deposited-at: uint })

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (cb (let ((is-tripped (try! (contract-call? cb is-circuit-open))))
          (if is-tripped (err ERR_CIRCUIT_OPEN) (ok true))))
    (ok true)
  )
)

(define-private (calculate-gas-cost (operation (string-ascii 64)))
  ;; Placeholder for actual gas cost calculation logic
  ;; In a real scenario, this would involve more complex estimation or oracle integration
  (match operation
    "harvest-rewards" u100
    "rebalance" u200
    u50 ;; Default gas cost
  ))

(define-private (get-highest-apy-strategy (current-pool-id uint))
  (let (
    (highest-apy u0)
    (best-strategy-id (some u0))
    (yield-dist-engine .yield-distribution-engine)
  )
    (map-fold strategies
      (fun (key value accumulator)
        (let ((strategy-pool-id (get pool-id value)))
          (if (and (is-eq strategy-pool-id current-pool-id) (get is-active value))
            (let ((current-apy (unwrap! (contract-call? yield-dist-engine calculate-apy strategy-pool-id) ERR_APY_CALCULATION_FAILED)))
              (if (> current-apy highest-apy)
                (begin
                  (var-set highest-apy current-apy)
                  (var-set best-strategy-id (some key)))
                accumulator
              )
            )
            accumulator
          )
        )
      )
      true
    )
    (ok (var-get best-strategy-id))
  )
)

;; --- Public Functions ---
(define-public (compound-rewards (strategy-id uint))
  (begin
    (try! (check-circuit-breaker))
    (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
      (let ((rewards (try! (contract-call? (get contract strategy) harvest-rewards))))
        (asserts! (> rewards u0) (err u0))
        ;; Assuming the strategy contract handles the token transfer to itself
        ;; and we just update the metrics here.
        (map-set strategies strategy-id (merge strategy {
          total-compounded-rewards: (+ (get total-compounded-rewards strategy) rewards),
          total-gas-cost: (+ (get total-gas-cost strategy) (calculate-gas-cost "harvest-rewards"))
        }))
        (ok rewards)
      )
    )
  )
)

(define-public (rebalance (strategy-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
      (print { notification: "Rebalancing strategy", strategy-id: strategy-id, current-risk: (get risk-level strategy), current-yield: (get yield-target strategy) })
      (try! (as-contract (contract-call? (get contract strategy) rebalance)))
      (map-set strategies strategy-id (merge strategy { last-rebalanced: block-height }))
      (ok true)
    )
  )
)

(define-public (get-strategy-performance (strategy-id uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
    (ok {
      yield: (get yield-target strategy),
      risk: (get risk-level strategy),
      uptime: (- block-height (get created-at strategy)),
      aum: u1000000, ;; Placeholder for actual AUM calculation
      last-rebalanced: (get last-rebalanced strategy),
      total-compounded-rewards: (get total-compounded-rewards strategy),
      total-gas-cost: (get total-gas-cost strategy),
      reward-cycle: (get reward-cycle strategy),
      yield-efficiency: (get yield-efficiency strategy),
      vault-performance: (get vault-performance strategy)
    })
  )
)

(define-public (register-strategy (name (string-ascii 64)) (contract principal) (risk-level uint) (yield-target uint) (reward-cycle uint) (yield-efficiency uint) (vault-performance uint) (pool-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (let ((strategy-id (+ u1 (var-get strategy-counter))))
            (map-set strategies strategy-id {
                name: name,
                contract: contract,
                risk-level: risk-level,
                yield-target: yield-target,
                created-at: block-height,
                last-rebalanced: block-height,
                total-compounded-rewards: u0,
                total-gas-cost: u0,
                reward-cycle: reward-cycle,
                yield-efficiency: yield-efficiency,
                vault-performance: vault-performance,
                pool-id: pool-id
            })
            (var-set strategy-counter strategy-id)
            (ok strategy-id)
        )
    )
)

(define-public (deposit (strategy-id uint) (token principal) (amount uint) (pool-id uint))
    (begin
        (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
            (try! (contract-call? token transfer amount tx-sender (get contract strategy)))
            (let ((deposit (default-to { amount: u0, deposited-at: block-height } (map-get? user-deposits { user: tx-sender, pool-id: pool-id, strategy-id: strategy-id }))))
                (map-set user-deposits { user: tx-sender, pool-id: pool-id, strategy-id: strategy-id } {
                    amount: (+ (get amount deposit) amount),
                    deposited-at: block-height
                })
                (ok true)
            )
        )
    )
)

(define-public (withdraw (strategy-id uint) (token principal) (amount uint) (pool-id uint))
    (begin
        (try! (check-circuit-breaker))
        (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
            (let ((deposit (unwrap! (map-get? user-deposits { user: tx-sender, pool-id: pool-id, strategy-id: strategy-id }) (err u0))))
                (asserts! (>= (get amount deposit) amount) (err u0))
                (try! (as-contract (contract-call? (get contract strategy) withdraw token amount tx-sender)))
                (map-set user-deposits { user: tx-sender, pool-id: pool-id, strategy-id: strategy-id } {
                    amount: (- (get amount deposit) amount),
                    deposited-at: block-height
                })
                (ok true)
            )
        )
    )
)


(define-public (reallocate-capital (pool-id uint) (current-strategy-id uint) (amount uint) (asset principal))
  (begin
    (try! (check-circuit-breaker))
    (let (
      (highest-apy-strategy-id (unwrap! (get-highest-apy-strategy pool-id) ERR_STRATEGY_NOT_FOUND))
    )
      (asserts! (is-some (map-get? user-deposits { user: tx-sender, pool-id: pool-id, strategy-id: current-strategy-id })) ERR_INSUFFICIENT_FUNDS)
      (if (is-eq current-strategy-id highest-apy-strategy-id)
        (ok true) ;; Already in the best strategy
        (begin
          ;; Withdraw from current strategy
          (try! (withdraw current-strategy-id asset amount pool-id))
          ;; Deposit into highest APY strategy
          (try! (deposit highest-apy-strategy-id asset amount pool-id))
          (ok true)
        )
      )
    )
  )
)

;; --- Admin Functions ---
(define-public (set-analytics-aggregator-contract (aggregator (contract-of analytics-aggregator-trait)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set analytics-aggregator-contract aggregator)
    (ok true)))

(define-public (set-circuit-breaker (cb principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

(define-public (set-performance-optimizer-contract (optimizer (contract-of performance-optimizer-trait)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set performance-optimizer-contract optimizer)
    (ok true)))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-strategy-details (strategy-id uint))
  (map-get? strategies strategy-id)
)

(define-read-only (get-user-vault-position (user principal) (pool-id uint) (strategy-id uint))
  (map-get? user-deposits { user: user, pool-id: pool-id, strategy-id: strategy-id }))

(define-read-only (get-strategy-count)
    (ok (var-get strategy-counter))
)

(define-read-only (get-pool-id-for-strategy (strategy-id uint))
  (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
    (ok (get pool-id strategy))
  )
)
