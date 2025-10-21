;; ===== Traits =====
(use-trait oracle-adapter-trait .all-traits.oracle-adapter-trait)
(impl-trait oracle-adapter-trait)

;; external-oracle-adapter.clar
;; Adapter for integrating external oracle providers (Chainlink, Pyth, Redstone)
;; Provides multi-source price aggregation with manipulation detection

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u8001))
(define-constant ERR_INVALID_SOURCE (err u8002))
(define-constant ERR_STALE_PRICE (err u8003))
(define-constant ERR_PRICE_DEVIATION (err u8004))
(define-constant ERR_NO_CONSENSUS (err u8005))
(define-constant ERR_INVALID_SIGNATURE (err u8006))

;; Oracle source IDs
(define-constant SOURCE_CHAINLINK u1)
(define-constant SOURCE_PYTH u2)
(define-constant SOURCE_REDSTONE u3)
(define-constant SOURCE_INTERNAL u4)

;; Configuration
(define-constant MAX_PRICE_AGE_BLOCKS u10) ;; ~10 minutes max staleness
(define-constant MAX_DEVIATION_BPS u500) ;; 5% max deviation between sources
(define-constant MIN_SOURCES_REQUIRED u2) ;; Minimum 2 sources for consensus

;; ===== Data Structures =====
(define-data-var contract-owner principal tx-sender)
(define-data-var aggregation-enabled bool true)

;; Oracle source configuration
(define-map oracle-sources uint {
  name: (string-ascii 32),
  enabled: bool,
  weight: uint,
  endpoint: (string-ascii 256),
  last-update: uint,
  reliability-score: uint
})

;; Asset price data from external sources
(define-map external-prices {asset: principal, source: uint} {
  price: uint,
  timestamp: uint,
  decimals: uint,
  confidence: uint,
  signature: (optional (buff 65))
})

;; Aggregated price data
(define-map aggregated-prices principal {
  price: uint,
  timestamp: uint,
  sources-count: uint,
  deviation: uint,
  confidence-level: uint
})

;; Price update history for manipulation detection
(define-map price-history {asset: principal, block: uint} {
  price: uint,
  volume-change: uint,
  was-flagged: bool
})

;; Trusted price feed operators
(define-map trusted-operators principal bool)

;; ===== Authorization =====
(define-private (check-is-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)))

(define-private (check-is-operator)
  (ok (asserts! (or (is-eq tx-sender (var-get contract-owner))
                    (default-to false (map-get? trusted-operators tx-sender)))
                ERR_UNAUTHORIZED)))

;; ===== Admin Functions =====
(define-public (add-oracle-source (source-id uint) (name (string-ascii 32)) (weight uint) (endpoint (string-ascii 256)))
  (begin
    (try! (check-is-owner))
    (map-set oracle-sources source-id {
      name: name,
      enabled: true,
      weight: weight,
      endpoint: endpoint,
      last-update: u0,
      reliability-score: u10000 ;; Start at 100%
    })
    (ok true)))

(define-public (update-source-status (source-id uint) (enabled bool))
  (begin
    (try! (check-is-owner))
    (match (map-get? oracle-sources source-id)
      source
      (begin
        (map-set oracle-sources source-id (merge source {enabled: enabled}))
        (ok true))
      ERR_INVALID_SOURCE)))

(define-public (add-trusted-operator (operator principal))
  (begin
    (try! (check-is-owner))
    (map-set trusted-operators operator true)
    (ok true)))

(define-public (remove-trusted-operator (operator principal))
  (begin
    (try! (check-is-owner))
    (map-set trusted-operators operator false)
    (ok true)))

(define-public (set-aggregation-enabled (enabled bool))
  (begin
    (try! (check-is-owner))
    (var-set aggregation-enabled enabled)
    (ok true)))

;; ===== Price Feed Functions =====

;; Submit price from external oracle
(define-public (submit-external-price
  (asset principal)
  (source-id uint)
  (price uint)
  (decimals uint)
  (confidence uint)
  (signature (optional (buff 65))))
  (begin
    (try! (check-is-operator))
    (asserts! (var-get aggregation-enabled) ERR_UNAUTHORIZED)
    
    ;; Validate source
    (let ((source (unwrap! (map-get? oracle-sources source-id) ERR_INVALID_SOURCE)))
      (asserts! (get enabled source) ERR_INVALID_SOURCE)
      
      ;; Verify signature if required
      (if (is-some signature)
          (try! (verify-oracle-signature asset price (unwrap-panic signature)))
          true)
      
      ;; Store price data
      (map-set external-prices {asset: asset, source: source-id} {
        price: price,
        timestamp: block-height,
        decimals: decimals,
        confidence: confidence,
        signature: signature
      })
      
      ;; Update source last-update
      (map-set oracle-sources source-id (merge source {last-update: block-height}))
      
      ;; Trigger aggregation
      (try! (aggregate-prices asset))
      
      (ok true))))

;; Aggregate prices from multiple sources
(define-private (aggregate-prices (asset principal))
  (let (
    (chainlink-price (get-source-price asset SOURCE_CHAINLINK))
    (pyth-price (get-source-price asset SOURCE_PYTH))
    (redstone-price (get-source-price asset SOURCE_REDSTONE))
    (internal-price (get-source-price asset SOURCE_INTERNAL))
    
    ;; Build list of valid prices with weights
    (prices-list (filter is-valid-price-data (list
      {price: chainlink-price, weight: (get-source-weight SOURCE_CHAINLINK)}
      {price: pyth-price, weight: (get-source-weight SOURCE_PYTH)}
      {price: redstone-price, weight: (get-source-weight SOURCE_REDSTONE)}
      {price: internal-price, weight: (get-source-weight SOURCE_INTERNAL)}
    )))
    
    (sources-count (len prices-list))
  )
    
    ;; Require minimum sources
    (asserts! (>= sources-count MIN_SOURCES_REQUIRED) ERR_NO_CONSENSUS)
    
    ;; Calculate weighted average price
    (let ((aggregated (calculate-weighted-average prices-list))
          (deviation (calculate-price-deviation prices-list)))
      
      ;; Check for excessive deviation (manipulation signal)
      (asserts! (<= deviation MAX_DEVIATION_BPS) ERR_PRICE_DEVIATION)
      
      ;; Store aggregated price
      (map-set aggregated-prices asset {
        price: aggregated,
        timestamp: block-height,
        sources-count: sources-count,
        deviation: deviation,
        confidence-level: (calculate-confidence-level prices-list deviation)
      })
      
      ;; Record price history
      (map-set price-history {asset: asset, block: block-height} {
        price: aggregated,
        volume-change: u0,
        was-flagged: (> deviation MAX_DEVIATION_BPS)
      })
      
      (ok aggregated))))

;; ===== Helper Functions =====
(define-private (get-source-price (asset principal) (source-id uint))
  (match (map-get? external-prices {asset: asset, source: source-id})
    price-data
    (if (<= (- block-height (get timestamp price-data)) MAX_PRICE_AGE_BLOCKS)
        (some (get price price-data))
        none)
    none))

(define-private (get-source-weight (source-id uint))
  (match (map-get? oracle-sources source-id)
    source
    (if (get enabled source) (get weight source) u0)
    u0))

(define-private (is-valid-price-data (data {price: (optional uint), weight: uint}))
  (and (is-some (get price data)) (> (get weight data) u0)))

(define-private (calculate-weighted-average (prices (list 10 {price: (optional uint), weight: uint})))
  (let ((result (fold calculate-weighted-sum prices {total: u0, weight-sum: u0})))
    (if (> (get weight-sum result) u0)
        (/ (get total result) (get weight-sum result))
        u0)))

(define-private (calculate-weighted-sum 
  (item {price: (optional uint), weight: uint})
  (acc {total: uint, weight-sum: uint}))
  (match (get price item)
    price-val
    {
      total: (+ (get total acc) (* price-val (get weight item))),
      weight-sum: (+ (get weight-sum acc) (get weight item))
    }
    acc))

(define-private (calculate-price-deviation (prices (list 10 {price: (optional uint), weight: uint})))
  (let ((avg (calculate-weighted-average prices))
        (valid-prices (filter is-valid-price-data prices)))
    (if (is-eq (len valid-prices) u0)
        u0
        (fold calculate-max-deviation valid-prices {avg: avg, max-dev: u0}))))

(define-private (calculate-max-deviation
  (item {price: (optional uint), weight: uint})
  (acc {avg: uint, max-dev: uint}))
  (match (get price item)
    price-val
    (let ((deviation (if (> price-val (get avg acc))
                         (/ (* (- price-val (get avg acc)) u10000) (get avg acc))
                         (/ (* (- (get avg acc) price-val) u10000) (get avg acc)))))
      {avg: (get avg acc), max-dev: (if (> deviation (get max-dev acc)) deviation (get max-dev acc))})
    acc))

(define-private (calculate-confidence-level (prices (list 10 {price: (optional uint), weight: uint})) (deviation uint))
  (if (< deviation u100)
      u10000 ;; Very high confidence
      (if (< deviation u300)
          u8000 ;; High confidence
          u5000))) ;; Medium confidence

(define-private (verify-oracle-signature (asset principal) (price uint) (signature (buff 65)))
  ;; In production, implement actual signature verification
  (ok true))

;; ===== Read-Only Functions =====
(define-read-only (get-price (asset principal))
  (match (map-get? aggregated-prices asset)
    price-data
    (if (<= (- block-height (get timestamp price-data)) MAX_PRICE_AGE_BLOCKS)
        (ok (get price price-data))
        ERR_STALE_PRICE)
    ERR_STALE_PRICE))

(define-read-only (get-price-with-confidence (asset principal))
  (match (map-get? aggregated-prices asset)
    price-data
    (ok {
      price: (get price price-data),
      confidence: (get confidence-level price-data),
      sources: (get sources-count price-data),
      age: (- block-height (get timestamp price-data))
    })
    ERR_STALE_PRICE))

(define-read-only (get-source-data (asset principal) (source-id uint))
  (map-get? external-prices {asset: asset, source: source-id}))

(define-read-only (get-oracle-source-info (source-id uint))
  (map-get? oracle-sources source-id))

(define-read-only (get-price-history (asset principal) (block uint))
  (map-get? price-history {asset: asset, block: block}))

(define-read-only (is-price-fresh (asset principal))
  (match (map-get? aggregated-prices asset)
    price-data
    (<= (- block-height (get timestamp price-data)) MAX_PRICE_AGE_BLOCKS)
    false))

(define-read-only (get-all-source-prices (asset principal))
  {
    chainlink: (get-source-price asset SOURCE_CHAINLINK),
    pyth: (get-source-price asset SOURCE_PYTH),
    redstone: (get-source-price asset SOURCE_REDSTONE),
    internal: (get-source-price asset SOURCE_INTERNAL),
    aggregated: (match (map-get? aggregated-prices asset)
                  price-data (some (get price price-data))
                  none)
  })

;; Check for price manipulation
(define-read-only (check-manipulation-risk (asset principal))
  (match (map-get? aggregated-prices asset)
    price-data
    {
      deviation-risk: (> (get deviation price-data) u300),
      confidence-low: (< (get confidence-level price-data) u5000),
      sources-insufficient: (< (get sources-count price-data) MIN_SOURCES_REQUIRED),
      overall-risk-score: (calculate-risk-score price-data)
    }
    {
      deviation-risk: true,
      confidence-low: true,
      sources-insufficient: true,
      overall-risk-score: u10000
    }))

(define-private (calculate-risk-score (price-data {price: uint, timestamp: uint, sources-count: uint, deviation: uint, confidence-level: uint}))
  (+ (get deviation price-data)
     (if (< (get sources-count price-data) MIN_SOURCES_REQUIRED) u2000 u0)
     (if (< (get confidence-level price-data) u5000) u1000 u0)))