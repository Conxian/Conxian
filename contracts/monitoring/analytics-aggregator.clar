;; analytics-aggregator.clar
;; COMPREHENSIVE FINANCIAL ANALYTICS SYSTEM
;; Traditional Finance Metrics: EBITDA, AUM, ARR, MNAV, ROE, ROA
;; DeFi Metrics: Real Yield, POL, Revenue/TVL, Sticky TVL
;; Risk Metrics: Sharpe Ratio, Sortino Ratio, VaR, Max Drawdown
;; User Metrics: CAC, LTV, Retention, Churn
;; Treasury Metrics: Runway, Burn Rate, Reserve Ratio

(use-trait  ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.)

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

;; Traditional Finance Metrics (EBITDA, AUM, ARR, etc.)
(define-map financial-metrics uint {
  ;; Revenue metrics
  gross-revenue: uint,
  operating-expenses: uint,
  ebitda: uint,  ;; Earnings Before Interest, Taxes, Depreciation, Amortization
  net-income: uint,
  
  ;; Asset metrics
  aum: uint,  ;; Assets Under Management (TVL)
  nav-per-share: uint,  ;; Net Asset Value per share
  mnav: uint,  ;; Modified Net Asset Value
  
  ;; Revenue multiples
  arr: uint,  ;; Annual Recurring Revenue
  mrr: uint,  ;; Monthly Recurring Revenue
  revenue-run-rate: uint,
  
  ;; Profitability ratios
  operating-margin: uint,  ;; EBITDA / Revenue (bps)
  net-margin: uint,  ;; Net Income / Revenue (bps)
  roe: uint,  ;; Return on Equity (bps)
  roa: uint,  ;; Return on Assets (bps)
  
  ;; Efficiency ratios
  revenue-per-user: uint,
  revenue-per-tvl: uint,  ;; Revenue / TVL ratio (bps)
  
  period: uint
})

;; DeFi-Specific Metrics
(define-map defi-metrics uint {
  ;; Yield metrics
  real-yield: uint,  ;; Excluding token emissions
  nominal-yield: uint,  ;; Including emissions
  emission-value: uint,
  
  ;; Liquidity metrics
  protocol-owned-liquidity: uint,
  mercenary-capital: uint,  ;; TVL - sticky TVL
  sticky-tvl: uint,  ;; TVL held >30 days
  liquidity-depth: uint,
  
  ;; Token metrics
  token-velocity: uint,  ;; Volume / Market Cap
  fdv: uint,  ;; Fully Diluted Valuation
  market-cap: uint,
  mcap-to-tvl: uint,  ;; Market Cap / TVL (bps)
  
  ;; Protocol health
  revenue-to-tvl: uint,  ;; Fee Revenue / TVL (bps)
  utilization-rate: uint,  ;; Borrowed / Supplied (bps)
  treasury-to-tvl: uint,  ;; Treasury / TVL (bps)
  
  period: uint
})

;; Per-asset TVL
(define-map asset-tvl principal {
  amount: uint,
  usd-value: uint,
  last-updated: uint
})

;; Per-pool metrics
(define-map pool-metrics principal {
  tvl: uint,
  volume-24h: uint,
  fee-revenue-24h: uint,
  apy: uint,
  utilization: uint,
  last-updated: uint
})

;; Per-vault metrics
(define-map vault-metrics principal {
  total-assets: uint,
  total-shares: uint,
  apy: uint,
  performance-fee: uint,
  last-harvest: uint
})

;; Historical snapshots (daily)
(define-map daily-snapshots uint {
  date: uint,
  tvl: uint,
  volume: uint,
  users: uint,
  transactions: uint,
  avg-apy: uint
})

;; User analytics
(define-map user-metrics principal {
  total-deposits: uint,
  total-withdrawals: uint,
  total-fees-paid: uint,
  total-rewards-earned: uint,
  last-active: uint
})

;; Protocol revenue tracking
(define-map revenue-metrics uint {
  trading-fees: uint,
  performance-fees: uint,
  liquidation-fees: uint,
  flash-loan-fees: uint,
  total-revenue: uint
})

;; Risk Metrics (Sharpe, Sortino, VaR, Max Drawdown)
(define-map risk-metrics uint {
  ;; Volatility metrics
  volatility: uint,  ;; Standard deviation (bps)
  downside-volatility: uint,  ;; Downside deviation (bps)
  max-drawdown: uint,  ;; Maximum peak-to-trough decline (bps)
  current-drawdown: uint,
  
  ;; Risk-adjusted returns
  sharpe-ratio: uint,  ;; (Return - Risk-free) / Volatility
  sortino-ratio: uint,  ;; (Return - Risk-free) / Downside Vol
  calmar-ratio: uint,  ;; Return / Max Drawdown
  
  ;; Value at Risk
  var-95: uint,  ;; 95% confidence VaR (bps)
  var-99: uint,  ;; 99% confidence VaR (bps)
  cvar-95: uint,  ;; Conditional VaR (Expected Shortfall)
  
  ;; Concentration risk
  herfindahl-index: uint,  ;; Sum of squared market shares
  concentration-ratio: uint,  ;; % in top 3 assets (bps)
  
  ;; Liquidity risk
  bid-ask-spread: uint,  ;; Average spread (bps)
  liquidity-score: uint,  ;; 0-10000
  
  period: uint
})

;; User Acquisition & Retention Metrics
(define-map user-cohort-metrics uint {
  ;; Acquisition
  new-users: uint,
  total-active-users: uint,
  dau: uint,  ;; Daily Active Users
  wau: uint,  ;; Weekly Active Users
  mau: uint,  ;; Monthly Active Users
  
  ;; Retention
  retention-rate-d7: uint,  ;; 7-day retention (bps)
  retention-rate-d30: uint,  ;; 30-day retention (bps)
  retention-rate-d90: uint,  ;; 90-day retention (bps)
  churn-rate: uint,  ;; Monthly churn (bps)
  
  ;; Economics
  cac: uint,  ;; Customer Acquisition Cost
  ltv: uint,  ;; Lifetime Value
  ltv-to-cac: uint,  ;; LTV / CAC ratio
  avg-revenue-per-user: uint,
  
  ;; Engagement
  avg-transactions-per-user: uint,
  power-user-percentage: uint,  ;; Top 10% users (bps)
  whale-percentage: uint,  ;; >$100k users (bps)
  
  period: uint
})

;; Treasury & Sustainability Metrics
(define-map treasury-metrics uint {
  ;; Balance sheet
  treasury-balance: uint,
  protocol-owned-liquidity: uint,
  reserve-assets: uint,
  total-liabilities: uint,
  
  ;; Sustainability
  monthly-revenue: uint,
  monthly-expenses: uint,
  burn-rate: uint,  ;; Expenses - Revenue (if negative)
  runway-months: uint,  ;; Treasury / Burn Rate
  
  ;; Reserve ratios
  reserve-ratio: uint,  ;; Reserves / Liabilities (bps)
  coverage-ratio: uint,  ;; Assets / Liabilities (bps)
  solvency-ratio: uint,
  
  ;; Capital efficiency
  capital-deployed: uint,  ;; % of treasury earning yield
  treasury-yield: uint,  ;; Yield on treasury assets (bps)
  
  period: uint
})

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-is-updater)
  (ok (asserts! (or (is-eq tx-sender (var-get contract-owner))
                    (is-eq tx-sender (var-get metrics-updater)))
                ERR_UNAUTHORIZED)))

;; ===== Update Functions =====

(define-public (update-asset-tvl (asset principal) (amount uint) (usd-value uint))
  (begin
    (try! (check-is-updater))
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
      }))
    (ok true)))

(define-public (update-global-metrics
  (tvl uint)
  (volume-24h uint)
  (users uint)
  (transactions uint))
  (begin
    (try! (check-is-updater))
    (var-set total-value-locked tvl)
    (var-set total-volume-24h volume-24h)
    (var-set total-users users)
    (var-set total-transactions transactions)
    (ok true)))

(define-public (take-daily-snapshot)
  (begin
    (try! (check-is-updater))
    (let ((snapshot-id (/ block-height u144))) ;; Daily snapshots (~24 hours)
      (map-set daily-snapshots snapshot-id {
        date: block-height,
        tvl: (var-get total-value-locked),
        volume: (var-get total-volume-24h),
        users: (var-get total-users),
        transactions: (var-get total-transactions),
        avg-apy: (calculate-average-apy)
      })
      (ok snapshot-id))))

(define-public (record-revenue
  (trading-fees uint)
  (performance-fees uint)
  (liquidation-fees uint)
  (flash-loan-fees uint))
  (begin
    (try! (check-is-updater))
    (let ((period-id (/ block-height u144)))
      (map-set revenue-metrics period-id {
        trading-fees: trading-fees,
        performance-fees: performance-fees,
        liquidation-fees: liquidation-fees,
        flash-loan-fees: flash-loan-fees,
        total-revenue: (+ trading-fees performance-fees liquidation-fees flash-loan-fees)
      })
      (ok true))))

;; ===== Read-Only Functions =====

(define-read-only (get-protocol-overview)
  {
    tvl: (var-get total-value-locked),
    volume-24h: (var-get total-volume-24h),
    total-users: (var-get total-users),
    total-transactions: (var-get total-transactions),
    current-block: block-height
  })

(define-read-only (get-asset-tvl (asset principal))
  (map-get? asset-tvl asset))

(define-read-only (get-pool-metrics (pool principal))
  (map-get? pool-metrics pool))

(define-read-only (get-vault-metrics (vault principal))
  (map-get? vault-metrics vault))

(define-read-only (get-user-metrics (user principal))
  (map-get? user-metrics user))

(define-read-only (get-daily-snapshot (day uint))
  (map-get? daily-snapshots day))

(define-read-only (get-revenue-metrics (period uint))
  (map-get? revenue-metrics period))

(define-read-only (get-current-period-revenue)
  (let ((current-period (/ block-height u144)))
    (map-get? revenue-metrics current-period)))

;; Calculate total protocol TVL across all assets
(define-read-only (get-total-protocol-tvl)
  (var-get total-value-locked))

;; Calculate average APY across all pools
(define-private (calculate-average-apy)
  ;; Simplified - in production, aggregate all pool APYs
  u500) ;; 5% placeholder

;; Get growth metrics (compare to previous period)
(define-read-only (get-growth-metrics)
  (let ((current-period (/ block-height u144))
        (previous-period (- current-period u1)))
    (match (map-get? daily-snapshots current-period)
      current
      (match (map-get? daily-snapshots previous-period)
        previous
        {
          tvl-growth: (calculate-growth (get tvl previous) (get tvl current)),
          volume-growth: (calculate-growth (get volume previous) (get volume current)),
          user-growth: (calculate-growth (get users previous) (get users current))
        }
        {
          tvl-growth: u0,
          volume-growth: u0,
          user-growth: u0
        })
      {
        tvl-growth: u0,
        volume-growth: u0,
        user-growth: u0
      })))

(define-private (calculate-growth (old-value uint) (new-value uint))
  (if (> old-value u0)
      (/ (* (- new-value old-value) u10000) old-value) ;; Return basis points
      u0))

;; Get top performers
(define-read-only (get-top-pools-by-apy)
  ;; In production, query and sort all pools by APY
  (list))

(define-read-only (get-top-pools-by-volume)
  ;; In production, query and sort all pools by volume
  (list))

;; User portfolio value
(define-read-only (get-user-portfolio-value (user principal))
  (match (map-get? user-metrics user)
    metrics
    {
      total-deposited: (get total-deposits metrics),
      total-withdrawn: (get total-withdrawals metrics),
      net-position: (- (get total-deposits metrics) (get total-withdrawals metrics)),
      lifetime-fees: (get total-fees-paid metrics),
      lifetime-rewards: (get total-rewards-earned metrics),
      net-pnl: (- (get total-rewards-earned metrics) (get total-fees-paid metrics))
    }
    {
      total-deposited: u0,
      total-withdrawn: u0,
      net-position: u0,
      lifetime-fees: u0,
      lifetime-rewards: u0,
      net-pnl: u0
    }))

;; ===== COMPREHENSIVE CALCULATION FUNCTIONS =====

;; Calculate EBITDA (Protocol Revenue - Operating Expenses)
(define-public (calculate-ebitda (period uint))
  (let ((revenue (unwrap! (map-get? revenue-metrics period) ERR_INSUFFICIENT_DATA)))
    (let ((gross-revenue (get total-revenue revenue))
          (operating-expenses u0)) ;; To be set from actual data
      (ok (if (> gross-revenue operating-expenses)
              (- gross-revenue operating-expenses)
              u0)))))

;; Calculate ARR (Annual Recurring Revenue)
(define-public (calculate-arr)
  (let ((current-period (/ block-height BLOCKS_PER_DAY)))
    (match (map-get? revenue-metrics current-period)
      revenue
      (ok (* (get total-revenue revenue) DAYS_PER_YEAR))
      ERR_INSUFFICIENT_DATA)))

;; Calculate MNAV (Modified Net Asset Value per Share)
(define-read-only (calculate-mnav (vault principal))
  (match (map-get? vault-metrics vault)
    metrics
    (if (> (get total-shares metrics) u0)
        (ok (/ (* (get total-assets metrics) PRECISION) (get total-shares metrics)))
        ERR_DIVISION_BY_ZERO)
    ERR_INSUFFICIENT_DATA))

;; Calculate Real Yield (excluding token emissions)
(define-read-only (calculate-real-yield)
  (let ((current-period (/ block-height BLOCKS_PER_DAY)))
    (match (map-get? revenue-metrics current-period)
      revenue
      (let ((total-revenue (get total-revenue revenue))
            (tvl (var-get total-value-locked)))
        (if (> tvl u0)
            (ok (/ (* total-revenue BASIS_POINTS DAYS_PER_YEAR) tvl))
            ERR_DIVISION_BY_ZERO))
      ERR_INSUFFICIENT_DATA)))

;; Calculate Sharpe Ratio ((Return - Risk-free Rate) / Volatility)
(define-read-only (calculate-sharpe-ratio (period uint) (risk-free-rate uint))
  (match (map-get? risk-metrics period)
    metrics
    (let ((returns (calculate-period-return period))
          (vol (get volatility metrics)))
      (if (> vol u0)
          (ok (/ (* (- returns risk-free-rate) BASIS_POINTS) vol))
          ERR_DIVISION_BY_ZERO))
    ERR_INSUFFICIENT_DATA))

;; Calculate LTV/CAC Ratio
(define-read-only (calculate-ltv-cac-ratio (period uint))
  (match (map-get? user-cohort-metrics period)
    metrics
    (let ((ltv (get ltv metrics))
          (cac (get cac metrics)))
      (if (> cac u0)
          (ok (/ (* ltv BASIS_POINTS) cac))
          ERR_DIVISION_BY_ZERO))
    ERR_INSUFFICIENT_DATA))

;; Calculate Runway (Treasury / Monthly Burn Rate)
(define-read-only (calculate-runway)
  (let ((treasury (var-get treasury-balance))
        (burn (var-get monthly-burn-rate)))
    (if (> burn u0)
        (ok (/ treasury burn))
        (ok u999)))) ;; Infinite runway if profitable

;; Calculate Revenue per TVL (bps)
(define-read-only (calculate-revenue-per-tvl (period uint))
  (match (map-get? revenue-metrics period)
    revenue
    (let ((rev (get total-revenue revenue))
          (tvl (var-get total-value-locked)))
      (if (> tvl u0)
          (ok (/ (* rev BASIS_POINTS) tvl))
          ERR_DIVISION_BY_ZERO))
    ERR_INSUFFICIENT_DATA))

;; ===== COMPREHENSIVE READ-ONLY FUNCTIONS =====

;; Get complete financial dashboard
(define-read-only (get-financial-dashboard)
  (let ((current-period (/ block-height BLOCKS_PER_DAY)))
    {
      ;; Core metrics
      tvl: (var-get total-value-locked),
      volume-24h: (var-get total-volume-24h),
      total-users: (var-get total-users),
      
      ;; Financial metrics
      arr: (unwrap-panic (calculate-arr)),
      ebitda: (unwrap-panic (calculate-ebitda current-period)),
      real-yield: (unwrap-panic (calculate-real-yield)),
      revenue-per-tvl: (unwrap-panic (calculate-revenue-per-tvl current-period)),
      
      ;; Treasury metrics
      treasury: (var-get treasury-balance),
      pol: (var-get protocol-owned-liquidity),
      runway: (unwrap-panic (calculate-runway)),
      
      ;; Risk metrics
      current-period: current-period,
      block-height: block-height
    }))

;; Get investor-grade metrics report
(define-read-only (get-investor-report (period uint))
  {
    financial-metrics: (map-get? financial-metrics period),
    defi-metrics: (map-get? defi-metrics period),
    risk-metrics: (map-get? risk-metrics period),
    user-metrics: (map-get? user-cohort-metrics period),
    treasury-metrics: (map-get? treasury-metrics period),
    revenue-metrics: (map-get? revenue-metrics period)
  })

;; Get risk assessment
(define-read-only (get-risk-assessment (period uint))
  (match (map-get? risk-metrics period)
    metrics
    {
      volatility: (get volatility metrics),
      max-drawdown: (get max-drawdown metrics),
      sharpe-ratio: (get sharpe-ratio metrics),
      var-95: (get var-95 metrics),
      concentration-risk: (get concentration-ratio metrics),
      liquidity-score: (get liquidity-score metrics),
      overall-risk-score: (calculate-overall-risk-score metrics)
    }
    {
      volatility: u0,
      max-drawdown: u0,
      sharpe-ratio: u0,
      var-95: u0,
      concentration-risk: u0,
      liquidity-score: u0,
      overall-risk-score: u0
    }))

;; Get user growth metrics
(define-read-only (get-user-growth-report (period uint))
  (match (map-get? user-cohort-metrics period)
    metrics
    {
      new-users: (get new-users metrics),
      total-active: (get total-active-users metrics),
      dau: (get dau metrics),
      mau: (get mau metrics),
      retention-d30: (get retention-rate-d30 metrics),
      churn-rate: (get churn-rate metrics),
      ltv-cac: (get ltv-to-cac metrics),
      arpu: (get avg-revenue-per-user metrics)
    }
    {
      new-users: u0,
      total-active: u0,
      dau: u0,
      mau: u0,
      retention-d30: u0,
      churn-rate: u0,
      ltv-cac: u0,
      arpu: u0
    }))

;; Get protocol health score (0-100)
(define-read-only (get-protocol-health-score)
  (let ((current-period (/ block-height BLOCKS_PER_DAY)))
    (let (
      (revenue-health (calculate-revenue-health current-period))
      (tvl-health (calculate-tvl-health))
      (user-health (calculate-user-health current-period))
      (treasury-health (calculate-treasury-health))
      (risk-health (calculate-risk-health current-period))
    )
      {
        overall-score: (/ (+ revenue-health tvl-health user-health treasury-health risk-health) u5),
        revenue-score: revenue-health,
        tvl-score: tvl-health,
        user-score: user-health,
        treasury-score: treasury-health,
        risk-score: risk-health
      })))

;; ===== HELPER CALCULATION FUNCTIONS =====

(define-private (calculate-period-return (period uint))
  ;; Calculate period returns from TVL change
  u500) ;; Placeholder

(define-private (calculate-overall-risk-score (metrics {
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
}))
  ;; Weighted risk score (lower is better)
  (+ (/ (get volatility metrics) u100)
     (/ (get max-drawdown metrics) u50)
     (/ (- u10000 (get liquidity-score metrics)) u100)))

(define-private (calculate-revenue-health (period uint))
  ;; Score 0-100 based on revenue growth and sustainability
  u80) ;; Placeholder

(define-private (calculate-tvl-health)
  ;; Score 0-100 based on TVL growth and stability
  u75) ;; Placeholder

(define-private (calculate-user-health (period uint))
  ;; Score 0-100 based on user growth and retention
  u85) ;; Placeholder

(define-private (calculate-treasury-health)
  ;; Score 0-100 based on runway and reserves
  u90) ;; Placeholder

(define-private (calculate-risk-health (period uint))
  ;; Score 0-100 based on risk metrics (inverted)
  u70) ;; Placeholder

;; === Admin Functions ===
(define-public (set-metrics-updater (updater principal))
  (begin
    (try! (check-is-owner))
    (var-set metrics-updater updater)
    (ok true)))
