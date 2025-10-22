;; ===== Traits =====
(use-trait analytics-aggregator-trait .all-traits.analytics-aggregator-trait)
(impl-trait analytics-aggregator-trait)

;; analytics-aggregator.clar
;; COMPREHENSIVE FINANCIAL ANALYTICS SYSTEM
;; Traditional Finance Metrics: EBITDA, AUM, ARR, MNAV, ROE, ROA
;; DeFi Metrics: Real Yield, POL, Revenue/TVL, Sticky TVL
;; Risk Metrics: Sharpe Ratio, Sortino Ratio, VaR, Max Drawdown
;; User Metrics: CAC, LTV, Retention, Churn
;; Treasury Metrics: Runway, Burn Rate, Reserve Ratio

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u5001))
(define-constant ERR_INVALID_METRIC (err u5002))
(define-constant ERR_DIVISION_BY_ZERO (err u5003))
(define-constant ERR_INSUFFICIENT_DATA (err u5004))
(define-constant PRECISION u1000000000000000000) ;; 1e18
(define-constant BASIS_POINTS u10000) ;; 100%
(define-constant BLOCKS_PER_DAY u144) ;; ~24 hours
(define-constant BLOCKS_PER_YEAR u52560) ;; ~365 days
(define-constant DAYS_PER_YEAR u365)

;; Metric types
(define-constant METRIC_TVL u1)
(define-constant METRIC_VOLUME_24H u2)
(define-constant METRIC_APY u3)
(define-constant METRIC_USER_COUNT u4)
(define-constant METRIC_TRANSACTION_COUNT u5)
(define-constant METRIC_AUM u6)
(define-constant METRIC_ARR u7)
(define-constant METRIC_EBITDA u8)
(define-constant METRIC_REAL_YIELD u9)
(define-constant METRIC_POL u10)

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var metrics-updater principal tx-sender)
(define-data-var analytics-enabled bool true)

;; Global protocol metrics
(define-data-var total-value-locked uint u0)
(define-data-var total-volume-24h uint u0)
(define-data-var total-users uint u0)
(define-data-var total-transactions uint u0)

;; Financial metrics
(define-data-var protocol-owned-liquidity uint u0)
(define-data-var treasury-balance uint u0)
(define-data-var monthly-burn-rate uint u0)
(define-data-var token-emissions uint u0)

;; ===== Metric Storage =====

;; Traditional Finance Metrics
(define-map financial-metrics 
  uint 
  {
    gross-revenue: uint,
    operating-expenses: uint,
    ebitda: uint,
    net-income: uint,
    aum: uint,
    nav-per-share: uint,
    mnav: uint,
    arr: uint,
    mrr: uint,
    revenue-run-rate: uint,
    operating-margin: uint,
    net-margin: uint,
    roe: uint,
    roa: uint,
    revenue-per-user: uint,
    revenue-per-tvl: uint,
    period: uint
  })

;; DeFi-Specific Metrics
(define-map defi-metrics 
  uint 
  {
    real-yield: uint,
    nominal-yield: uint,
    emission-value: uint,
    protocol-owned-liquidity: uint,
    mercenary-capital: uint,
    sticky-tvl: uint,
    liquidity-depth: uint,
    token-velocity: uint,
    fdv: uint,
    market-cap: uint,
    mcap-to-tvl: uint,
    revenue-to-tvl: uint,
    utilization-rate: uint,
    treasury-to-tvl: uint,
    period: uint
  })

;; Per-asset TVL
(define-map asset-tvl 
  principal 
  {
    amount: uint,
    usd-value: uint,
    last-updated: uint
  })

;; Per-pool metrics
(define-map pool-metrics 
  principal 
  {
    tvl: uint,
    volume-24h: uint,
    fee-revenue-24h: uint,
    apy: uint,
    utilization: uint,
    last-updated: uint
  })

;; Per-vault metrics
(define-map vault-metrics 
  principal 
  {
    total-assets: uint,
    total-shares: uint,
    apy: uint,
    performance-fee: uint,
    last-harvest: uint
  })

;; Historical snapshots (daily)
(define-map daily-snapshots 
  uint 
  {
    date: uint,
    tvl: uint,
    volume: uint,
    users: uint,
    transactions: uint,
    avg-apy: uint
  })

;; User analytics
(define-map user-metrics 
  principal 
  {
    total-deposits: uint,
    total-withdrawals: uint,
    total-fees-paid: uint,
    total-rewards-earned: uint,
    last-active: uint
  })

;; Protocol revenue tracking
(define-map revenue-metrics 
  uint 
  {
    trading-fees: uint,
    performance-fees: uint,
    liquidation-fees: uint,
    flash-loan-fees: uint,
    total-revenue: uint
  })

;; Risk Metrics
(define-map risk-metrics 
  uint 
  {
    volatility: uint,
    downside-volatility: uint,
    max-drawdown: uint,
    current-drawdown: uint,
    sharpe-ratio: uint,
    sortino-ratio: uint,
    calmar-ratio: uint,
    var-95: uint,
    var-99: uint,
    cvar-95: uint,
    herfindahl-index: uint,
    concentration-ratio: uint,
    bid-ask-spread: uint,
    liquidity-score: uint,
    period: uint
  })

;; User Acquisition & Retention Metrics
(define-map user-cohort-metrics 
  uint 
  {
    new-users: uint,
    total-active-users: uint,
    dau: uint,
    wau: uint,
    mau: uint,
    retention-rate-d7: uint,
    retention-rate-d30: uint,
    retention-rate-d90: uint,
    churn-rate: uint,
    cac: uint,
    ltv: uint,
    ltv-to-cac: uint,
    avg-revenue-per-user: uint,
    avg-transactions-per-user: uint,
    power-user-percentage: uint,
    whale-percentage: uint,
    period: uint
  })

;; Treasury & Sustainability Metrics
(define-map treasury-metrics 
  uint 
  {
    treasury-balance: uint,
    protocol-owned-liquidity: uint,
    reserve-assets: uint,
    total-liabilities: uint,
    monthly-revenue: uint,
    monthly-expenses: uint,
    burn-rate: uint,
    runway-months: uint,
    reserve-ratio: uint,
    coverage-ratio: uint,
    solvency-ratio: uint,
    capital-deployed: uint,
    treasury-yield: uint,
    period: uint
  })

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-is-updater)
  (ok (asserts! (or (is-eq tx-sender (var-get contract-owner))
                    (is-eq tx-sender (var-get metrics-updater)))
                ERR_UNAUTHORIZED)))

(define-private (is-analytics-enabled)
  (var-get analytics-enabled))

;; ===== Configuration =====
(define-public (set-analytics-enabled (enabled bool))
  (begin
    (try! (check-is-owner))
    (ok (var-set analytics-enabled enabled))))

(define-public (set-metrics-updater (updater principal))
  (begin
    (try! (check-is-owner))
    (ok (var-set metrics-updater updater))))

;; ===== Update Functions =====
(define-public (update-asset-tvl (asset principal) (amount uint) (usd-value uint))
  (begin
    (try! (check-is-updater))
    (asserts! (is-analytics-enabled) ERR_UNAUTHORIZED)
    (map-set asset-tvl asset {
      amount: amount,
      usd-value: usd-value,
      last-updated: block-height
    })
    (ok true)))

(define-public (update-pool-metrics
  (pool principal)
  (tvl uint)
  (volume-24h uint)
  (fee-revenue-24h uint)
  (apy uint)
  (utilization uint))
  (begin
    (try! (check-is-updater))
    (asserts! (is-analytics-enabled) ERR_UNAUTHORIZED)
    (map-set pool-metrics pool {
      tvl: tvl,
      volume-24h: volume-24h,
      fee-revenue-24h: fee-revenue-24h,
      apy: apy,
      utilization: utilization,
      last-updated: block-height
    })
    (ok true)))

(define-public (update-vault-metrics
  (vault principal)
  (total-assets uint)
  (total-shares uint)
  (apy uint)
  (performance-fee uint))
  (begin
    (try! (check-is-updater))
    (asserts! (is-analytics-enabled) ERR_UNAUTHORIZED)
    (map-set vault-metrics vault {
      total-assets: total-assets,
      total-shares: total-shares,
      apy: apy,
      performance-fee: performance-fee,
      last-harvest: block-height
    })
    (ok true)))

(define-public (record-user-activity
  (user principal)
  (deposit-amount uint)
  (withdrawal-amount uint)
  (fees-paid uint)
  (rewards-earned uint))
  (begin
    (try! (check-is-updater))
    (asserts! (is-analytics-enabled) ERR_UNAUTHORIZED)
    (match (map-get? user-metrics user)
      existing
      (map-set user-metrics user {
        total-deposits: (+ (get total-deposits existing) deposit-amount),
        total-withdrawals: (+ (get total-withdrawals existing) withdrawal-amount),
        total-fees-paid: (+ (get total-fees-paid existing) fees-paid),
        total-rewards-earned: (+ (get total-rewards-earned existing) rewards-earned),
        last-active: block-height
      })
      (map-set user-metrics user {
        total-deposits: deposit-amount,
        total-withdrawals: withdrawal-amount,
        total-fees-paid: fees-paid,
        total-rewards-earned: rewards-earned,
        last-active: block-height
      })
    )
    (ok true)))

;; ===== Read-Only Functions =====
(define-read-only (get-analytics-status)
  {
    enabled: (var-get analytics-enabled),
    owner: (var-get contract-owner),
    updater: (var-get metrics-updater)
  })

(define-read-only (get-asset-tvl (asset principal))
  (map-get? asset-tvl asset))

(define-read-only (get-pool-metrics (pool principal))
  (map-get? pool-metrics pool))

(define-read-only (get-vault-metrics (vault principal))
  (map-get? vault-metrics vault))

(define-read-only (get-user-metrics (user principal))
  (map-get? user-metrics user))

(define-read-only (get-financial-metrics (period uint))
  (map-get? financial-metrics period))

(define-read-only (get-defi-metrics (period uint))
  (map-get? defi-metrics period))

(define-read-only (get-risk-metrics (period uint))
  (map-get? risk-metrics period))

(define-read-only (get-user-cohort-metrics (period uint))
  (map-get? user-cohort-metrics period))

(define-read-only (get-treasury-metrics (period uint))
  (map-get? treasury-metrics period))