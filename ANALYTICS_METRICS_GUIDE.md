# Conxian Analytics Aggregator - Comprehensive Metrics Guide
## Enterprise-Grade Financial Analytics System

**Contract:** `analytics-aggregator.clar`  
**Version:** Enhanced v2.0  
**Last Updated:** 2025-10-02

---

## 📊 Overview

The enhanced Analytics Aggregator implements **60+ financial metrics** following institutional finance best practices, combining traditional finance (TradFi) metrics with DeFi-specific KPIs.

### Metric Categories

1. **Traditional Finance Metrics** (EBITDA, AUM, ARR, MNAV, ROE, ROA)
2. **DeFi-Specific Metrics** (Real Yield, POL, Revenue/TVL, Sticky TVL)
3. **Risk Metrics** (Sharpe, Sortino, VaR, Max Drawdown)
4. **User Acquisition & Retention** (CAC, LTV, Cohort Analysis)
5. **Treasury & Sustainability** (Runway, Burn Rate, Reserve Ratios)

---

## 💼 TRADITIONAL FINANCE METRICS

### Revenue & Profitability

#### 1. EBITDA (Earnings Before Interest, Taxes, Depreciation, Amortization)
**Formula:** `Gross Revenue - Operating Expenses`

```clarity
(calculate-ebitda period)
```

**Purpose:** Measures operating profitability before non-cash expenses  
**Benchmark:** >30% margin is excellent for SaaS/DeFi  
**Usage:** Investor presentations, valuation multiples

#### 2. ARR (Annual Recurring Revenue)
**Formula:** `Current Daily Revenue × 365`

```clarity
(calculate-arr)
```

**Purpose:** Annualized revenue run rate  
**Benchmark:** YoY growth >100% for early-stage, >40% for mature protocols  
**Usage:** Fundraising, growth tracking

#### 3. MRR (Monthly Recurring Revenue)
**Formula:** `Current Daily Revenue × 30`

**Purpose:** Monthly revenue tracking  
**Usage:** Monthly board reports, trend analysis

#### 4. Operating Margin
**Formula:** `(EBITDA / Gross Revenue) × 10,000` (in basis points)

**Purpose:** Efficiency of operations  
**Benchmark:** >50% (5,000 bps) is healthy for DeFi protocols  
**Usage:** Profitability analysis

#### 5. Net Margin
**Formula:** `(Net Income / Gross Revenue) × 10,000`

**Purpose:** Bottom-line profitability  
**Benchmark:** >30% for sustainable protocols  
**Usage:** Long-term sustainability assessment

### Asset Metrics

#### 6. AUM (Assets Under Management)
**Definition:** Total Value Locked (TVL) in the protocol

```clarity
total-value-locked
```

**Purpose:** Scale and market presence  
**Benchmark:** Top DeFi protocols: $100M - $10B+  
**Usage:** Market positioning, competitive analysis

#### 7. MNAV (Modified Net Asset Value per Share)
**Formula:** `(Total Assets × PRECISION) / Total Shares`

```clarity
(calculate-mnav vault-address)
```

**Purpose:** Fair value per vault share  
**Usage:** Vault performance tracking, investor reporting

#### 8. NAV per Share
**Formula:** `Total Assets / Total Shares`

**Purpose:** Standard net asset value  
**Usage:** Daily fund valuation

### Profitability Ratios

#### 9. ROE (Return on Equity)
**Formula:** `(Net Income / Shareholder Equity) × 10,000`

**Purpose:** Return generated on equity capital  
**Benchmark:** >20% (2,000 bps) is strong  
**Usage:** Investor returns analysis

#### 10. ROA (Return on Assets)
**Formula:** `(Net Income / Total Assets) × 10,000`

**Purpose:** Efficiency of asset utilization  
**Benchmark:** >10% (1,000 bps) is good  
**Usage:** Asset management efficiency

### Efficiency Metrics

#### 11. Revenue per User
**Formula:** `Total Revenue / Active Users`

**Purpose:** User monetization efficiency  
**Benchmark:** $100-$1,000 for DeFi  
**Usage:** Business model validation

#### 12. Revenue per TVL
**Formula:** `(Revenue / TVL) × 10,000`

```clarity
(calculate-revenue-per-tvl period)
```

**Purpose:** Capital efficiency  
**Benchmark:** >300 bps (3%) annually is healthy  
**Usage:** Competitive benchmarking

---

## 🏦 DeFi-SPECIFIC METRICS

### Yield Metrics

#### 13. Real Yield
**Formula:** `(Fee Revenue / TVL × 365) × 10,000` (excluding emissions)

```clarity
(calculate-real-yield)
```

**Purpose:** Sustainable yield without token incentives  
**Benchmark:** >5% (500 bps) is strong  
**Importance:** ⭐⭐⭐⭐⭐ Critical for long-term sustainability

#### 14. Nominal Yield
**Formula:** `(Fee Revenue + Emission Value) / TVL × 365`

**Purpose:** Total yield including incentives  
**Usage:** Marketing, user acquisition

#### 15. Emissions to Revenue Ratio
**Formula:** `Emission Value / Fee Revenue`

**Purpose:** Token dilution vs. organic revenue  
**Benchmark:** <2x (emissions should be <2x fee revenue)  
**Importance:** ⭐⭐⭐⭐⭐ Sustainability indicator

### Liquidity Metrics

#### 16. Protocol-Owned Liquidity (POL)
**Definition:** Liquidity owned by the protocol treasury

**Purpose:** Reduces mercenary capital risk  
**Benchmark:** >30% of total liquidity  
**Importance:** ⭐⭐⭐⭐⭐ Key for sustainability

#### 17. Sticky TVL
**Definition:** TVL from users holding >30 days

**Purpose:** Measure loyal vs. mercenary capital  
**Benchmark:** >50% sticky TVL is healthy  
**Importance:** ⭐⭐⭐⭐ Retention indicator

#### 18. Mercenary Capital
**Formula:** `TVL - Sticky TVL`

**Purpose:** Capital at risk of leaving  
**Usage:** Risk assessment, incentive planning

#### 19. Liquidity Depth
**Definition:** Average liquidity available within 2% price impact

**Purpose:** Trading quality assessment  
**Usage:** Market maker evaluation

### Token Metrics

#### 20. Token Velocity
**Formula:** `24h Volume / Market Cap`

**Purpose:** How quickly tokens change hands  
**Benchmark:** 0.1-0.3 for stable protocols  
**Usage:** Token economics analysis

#### 21. FDV (Fully Diluted Valuation)
**Formula:** `Token Price × Max Supply`

**Purpose:** Maximum potential market cap  
**Usage:** Valuation analysis

#### 22. Market Cap to TVL Ratio
**Formula:** `(Market Cap / TVL) × 10,000`

**Purpose:** Valuation relative to protocol size  
**Benchmark:** 0.5-2.0 is typical  
**Usage:** Relative valuation

### Protocol Health

#### 23. Revenue to TVL Ratio
**Formula:** `(Annual Revenue / TVL) × 10,000`

**Purpose:** Capital efficiency  
**Benchmark:** >300 bps (3%) is strong  
**Importance:** ⭐⭐⭐⭐⭐ Key performance indicator

#### 24. Utilization Rate
**Formula:** `(Borrowed / Supplied) × 10,000`

**Purpose:** Capital efficiency in lending  
**Benchmark:** 70-85% is optimal  
**Usage:** Interest rate model tuning

#### 25. Treasury to TVL Ratio
**Formula:** `(Treasury Balance / TVL) × 10,000`

**Purpose:** Protocol security buffer  
**Benchmark:** >5% (500 bps)  
**Usage:** Risk management

---

## 📉 RISK METRICS

### Volatility Metrics

#### 26. Volatility (Standard Deviation)
**Formula:** `√(Σ(Return - Mean)² / N)` (in basis points)

**Purpose:** Price/TVL variability  
**Benchmark:** <2,000 bps for stable protocols  
**Usage:** Risk assessment

#### 27. Downside Volatility
**Formula:** Standard deviation of negative returns only

**Purpose:** Downside risk measurement  
**Usage:** Sortino ratio calculation

#### 28. Max Drawdown
**Formula:** `(Peak Value - Trough Value) / Peak Value × 10,000`

**Purpose:** Worst decline from peak  
**Benchmark:** <30% (3,000 bps) for conservative protocols  
**Importance:** ⭐⭐⭐⭐⭐ Critical risk metric

### Risk-Adjusted Returns

#### 29. Sharpe Ratio
**Formula:** `(Return - Risk-Free Rate) / Volatility`

```clarity
(calculate-sharpe-ratio period risk-free-rate)
```

**Purpose:** Returns per unit of risk  
**Benchmark:** >1.0 is good, >2.0 is excellent  
**Importance:** ⭐⭐⭐⭐⭐ Institutional standard

#### 30. Sortino Ratio
**Formula:** `(Return - Risk-Free Rate) / Downside Volatility`

**Purpose:** Returns per unit of downside risk  
**Benchmark:** >1.5 is good  
**Usage:** Preferred by risk-averse investors

#### 31. Calmar Ratio
**Formula:** `Annual Return / Max Drawdown`

**Purpose:** Return vs. worst-case scenario  
**Benchmark:** >1.0 is acceptable  
**Usage:** Hedge fund-style analysis

### Value at Risk (VaR)

#### 32. VaR 95%
**Definition:** Maximum expected loss at 95% confidence

**Purpose:** Downside risk quantification  
**Usage:** Risk limits, regulatory reporting

#### 33. VaR 99%
**Definition:** Maximum expected loss at 99% confidence

**Purpose:** Extreme risk scenarios  
**Usage:** Stress testing

#### 34. CVaR (Conditional VaR)
**Definition:** Expected loss beyond VaR threshold

**Purpose:** Tail risk measurement  
**Importance:** ⭐⭐⭐⭐ Critical for risk management

### Concentration Risk

#### 35. Herfindahl Index
**Formula:** `Σ(Market Share²)`

**Purpose:** Market concentration measurement  
**Benchmark:** <2,500 for diversified exposure  
**Usage:** Portfolio risk analysis

#### 36. Concentration Ratio
**Formula:** `(Top 3 Assets / Total Assets) × 10,000`

**Purpose:** Top-heavy risk  
**Benchmark:** <50% (5,000 bps)  
**Usage:** Diversification tracking

### Liquidity Risk

#### 37. Bid-Ask Spread
**Definition:** Average spread across pools (basis points)

**Purpose:** Trading cost measurement  
**Benchmark:** <50 bps for major pairs  
**Usage:** Liquidity provider evaluation

#### 38. Liquidity Score
**Scale:** 0-10,000 (0-100%)

**Purpose:** Overall liquidity health  
**Components:** Depth, spread, volume  
**Usage:** Market quality assessment

---

## 👥 USER METRICS

### Acquisition Metrics

#### 39. DAU (Daily Active Users)
**Definition:** Unique users with transactions in last 24h

**Purpose:** Daily engagement tracking  
**Usage:** Growth monitoring

#### 40. MAU (Monthly Active Users)
**Definition:** Unique users with transactions in last 30 days

**Purpose:** Monthly engagement  
**Benchmark:** DAU/MAU ratio >20% is strong  
**Usage:** Retention assessment

#### 41. New Users
**Definition:** First-time users in period

**Purpose:** Growth rate tracking  
**Usage:** Marketing ROI

#### 42. CAC (Customer Acquisition Cost)
**Formula:** `Marketing Spend / New Users`

**Purpose:** Acquisition efficiency  
**Benchmark:** <$100 for DeFi  
**Importance:** ⭐⭐⭐⭐⭐ Critical for unit economics

### Retention Metrics

#### 43. Retention Rate (D7, D30, D90)
**Formula:** `(Retained Users / Initial Cohort) × 10,000`

**Purpose:** User stickiness  
**Benchmark:** >40% D30 retention is good  
**Importance:** ⭐⭐⭐⭐⭐ Key to product-market fit

#### 44. Churn Rate
**Formula:** `(Users Lost / Total Users) × 10,000` (monthly)

**Purpose:** User attrition rate  
**Benchmark:** <10% (1,000 bps) monthly  
**Usage:** Retention program effectiveness

### Economics Metrics

#### 45. LTV (Lifetime Value)
**Formula:** `ARPU × Avg Customer Lifetime`

**Purpose:** Total value per user  
**Benchmark:** >$1,000 for DeFi power users  
**Importance:** ⭐⭐⭐⭐⭐ Unit economics

#### 46. LTV/CAC Ratio
**Formula:** `LTV / CAC`

```clarity
(calculate-ltv-cac-ratio period)
```

**Purpose:** Profitability of user acquisition  
**Benchmark:** >3.0 is healthy, >5.0 is excellent  
**Importance:** ⭐⭐⭐⭐⭐ Business sustainability

#### 47. ARPU (Average Revenue Per User)
**Formula:** `Total Revenue / Active Users`

**Purpose:** User monetization  
**Benchmark:** >$50/month for DeFi  
**Usage:** Revenue forecasting

### Engagement Metrics

#### 48. Avg Transactions Per User
**Formula:** `Total Transactions / Active Users`

**Purpose:** User activity level  
**Benchmark:** >5 transactions/month  
**Usage:** Product engagement

#### 49. Power User Percentage
**Definition:** % of users in top 10% by activity

**Purpose:** User distribution analysis  
**Benchmark:** 10-20% power users  
**Usage:** Feature development prioritization

#### 50. Whale Percentage
**Definition:** % of users with >$100k TVL

**Purpose:** Capital concentration  
**Benchmark:** 5-15%  
**Usage:** Risk and retention focus

---

## 🏛️ TREASURY & SUSTAINABILITY METRICS

### Balance Sheet

#### 51. Treasury Balance
**Definition:** Total protocol-controlled assets

**Purpose:** Financial strength  
**Benchmark:** >6 months runway  
**Importance:** ⭐⭐⭐⭐⭐ Survival metric

#### 52. Reserve Assets
**Definition:** Liquid, low-risk treasury holdings

**Purpose:** Emergency fund  
**Benchmark:** >3 months expenses  
**Usage:** Risk management

### Sustainability

#### 53. Monthly Burn Rate
**Formula:** `Monthly Expenses - Monthly Revenue`

**Purpose:** Cash consumption rate  
**Benchmark:** Negative (profitable) is ideal  
**Importance:** ⭐⭐⭐⭐⭐ Survival metric

#### 54. Runway (Months)
**Formula:** `Treasury Balance / Monthly Burn Rate`

```clarity
(calculate-runway)
```

**Purpose:** Time until treasury depletion  
**Benchmark:** >12 months minimum, >24 months ideal  
**Importance:** ⭐⭐⭐⭐⭐ Critical for planning

### Reserve Ratios

#### 55. Reserve Ratio
**Formula:** `(Reserves / Liabilities) × 10,000`

**Purpose:** Solvency measurement  
**Benchmark:** >100% (10,000 bps)  
**Usage:** Risk assessment

#### 56. Coverage Ratio
**Formula:** `(Total Assets / Total Liabilities) × 10,000`

**Purpose:** Ability to cover obligations  
**Benchmark:** >150% (15,000 bps)  
**Usage:** Credit analysis

#### 57. Solvency Ratio
**Formula:** `(Net Assets / Total Assets) × 10,000`

**Purpose:** Equity position strength  
**Benchmark:** >30% (3,000 bps)  
**Usage:** Long-term sustainability

### Capital Efficiency

#### 58. Capital Deployed %
**Formula:** `(Earning Assets / Treasury) × 10,000`

**Purpose:** Treasury utilization  
**Benchmark:** >50% (5,000 bps)  
**Usage:** Treasury optimization

#### 59. Treasury Yield
**Formula:** `(Treasury Returns / Treasury Assets) × 10,000`

**Purpose:** Return on treasury  
**Benchmark:** >5% (500 bps) annually  
**Usage:** Treasury performance

---

## 🎯 COMPREHENSIVE DASHBOARDS

### 1. Financial Dashboard
```clarity
(get-financial-dashboard)
```

**Returns:**
- TVL
- 24h Volume
- Total Users
- ARR
- EBITDA
- Real Yield
- Revenue/TVL
- Treasury
- POL
- Runway

**Use Case:** Executive summary, board meetings

### 2. Investor Report
```clarity
(get-investor-report period)
```

**Returns:**
- Financial metrics (EBITDA, ARR, margins)
- DeFi metrics (Real Yield, POL, token metrics)
- Risk metrics (Sharpe, VaR, drawdown)
- User metrics (CAC, LTV, retention)
- Treasury metrics (runway, ratios)
- Revenue breakdown

**Use Case:** Quarterly investor updates, fundraising

### 3. Risk Assessment
```clarity
(get-risk-assessment period)
```

**Returns:**
- Volatility
- Max Drawdown
- Sharpe Ratio
- VaR 95%
- Concentration Risk
- Liquidity Score
- Overall Risk Score

**Use Case:** Risk management, regulatory compliance

### 4. User Growth Report
```clarity
(get-user-growth-report period)
```

**Returns:**
- New Users
- Total Active
- DAU/MAU
- Retention Rates
- Churn Rate
- LTV/CAC
- ARPU

**Use Case:** Product team, growth strategy

### 5. Protocol Health Score
```clarity
(get-protocol-health-score)
```

**Returns:** 0-100 score across:
- Revenue Health (20%)
- TVL Health (20%)
- User Health (20%)
- Treasury Health (20%)
- Risk Health (20%)

**Use Case:** At-a-glance protocol assessment

---

## 📊 BENCHMARK TARGETS

### Tier 1 DeFi Protocol (Top 10)
- **TVL:** >$1B
- **ARR:** >$100M
- **Real Yield:** >5%
- **Users:** >100k MAU
- **LTV/CAC:** >5.0
- **Runway:** >24 months
- **Sharpe Ratio:** >2.0

### Tier 2 DeFi Protocol (Top 50)
- **TVL:** >$100M
- **ARR:** >$10M
- **Real Yield:** >3%
- **Users:** >10k MAU
- **LTV/CAC:** >3.0
- **Runway:** >12 months
- **Sharpe Ratio:** >1.0

### Early Stage (Growth)
- **TVL:** $10M-$100M
- **ARR:** $1M-$10M
- **Real Yield:** >2%
- **Users:** 1k-10k MAU
- **LTV/CAC:** >2.0
- **Runway:** >6 months
- **Growth:** >100% YoY

---

## 🔄 UPDATE FREQUENCY

| Metric Category | Update Frequency | Auto-Update | Manual Review |
|----------------|------------------|-------------|---------------|
| TVL & Volume | Real-time | ✅ | Weekly |
| Revenue Metrics | Daily | ✅ | Monthly |
| User Metrics | Daily | ✅ | Weekly |
| Risk Metrics | Daily | ✅ | Monthly |
| Treasury Metrics | Weekly | ⚠️ | Monthly |
| Investor Reports | Monthly | ⚠️ | Quarterly |

---

## 🚀 IMPLEMENTATION CHECKLIST

### Phase 1: Core Metrics (Week 1)
- [x] TVL tracking
- [x] Revenue metrics (EBITDA, ARR)
- [x] Basic user metrics
- [ ] Real-time updates via keeper

### Phase 2: DeFi Metrics (Week 2)
- [ ] Real Yield calculation
- [ ] POL tracking
- [ ] Sticky TVL measurement
- [ ] Token velocity

### Phase 3: Risk Metrics (Week 3)
- [ ] Volatility calculation
- [ ] Sharpe/Sortino ratios
- [ ] VaR implementation
- [ ] Max drawdown tracking

### Phase 4: User Analytics (Week 4)
- [ ] Cohort analysis
- [ ] Retention tracking
- [ ] LTV/CAC calculation
- [ ] Engagement metrics

### Phase 5: Reporting (Week 5)
- [ ] Dashboard APIs
- [ ] Automated reports
- [ ] Alert system
- [ ] Export functionality

---

## 📖 REFERENCES

### Financial Standards
- **GAAP:** Generally Accepted Accounting Principles
- **IFRS:** International Financial Reporting Standards
- **CFA:** Chartered Financial Analyst standards

### DeFi Analytics
- **DefiLlama:** Industry benchmarks
- **Token Terminal:** Revenue multiples
- **Messari:** Protocol metrics standards

### Risk Management
- **Basel III:** Banking risk standards
- **VaR:** JP Morgan RiskMetrics
- **Sharpe Ratio:** William F. Sharpe (Nobel Prize 1990)

---

**Prepared By:** Conxian Analytics Team  
**Review Cadence:** Quarterly  
**Next Review:** Q1 2026
