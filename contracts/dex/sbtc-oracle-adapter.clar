;; sbtc-oracle-adapter.clar
;; sBTC Oracle Adapter - Advanced price feeds and circuit breaker integration
;; Handles multiple oracle sources, price validation, and emergency controls

(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u3000))
(define-constant ERR_INVALID_ORACLE (err u3001))
(define-constant ERR_PRICE_STALE (err u3002))
(define-constant ERR_PRICE_DEVIATION_TOO_HIGH (err u3003))
(define-constant ERR_CIRCUIT_BREAKER_TRIGGERED (err u3004))
(define-constant ERR_INSUFFICIENT_ORACLES (err u3005))
(define-constant ERR_ORACLE_ALREADY_EXISTS (err u3006))
(define-constant ERR_ORACLE_NOT_FOUND (err u3007))
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; Price validation constants
(define-constant MAX_PRICE_DEVIATION u100000)    ;; 10% max deviation
(define-constant MAX_STALENESS_BLOCKS u144)      ;; ~24 hours (assuming 10 min blocks)
(define-constant MIN_ORACLES_REQUIRED u2)        ;; Minimum oracles for consensus
(define-constant PRICE_PRECISION u1000000)       ;; 6 decimal places

;; Circuit breaker thresholds
(define-constant CIRCUIT_BREAKER_DEVIATION u200000) ;; 20% price movement
(define-constant CIRCUIT_BREAKER_WINDOW u6)          ;; 6 blocks window

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-map oracle-config
  { oracle: principal }
  {
    is-active: bool,
    weight: uint,              ;; Oracle weight in price calculation
    last-update: uint,         ;; Last price update block
    total-updates: uint,       ;; Total number of price updates
    failed-updates: uint,      ;; Number of failed updates
    deviation-count: uint      ;; Number of high deviation updates
  }
)

(define-map price-feeds
  { oracle: principal, asset: principal }
  {
    price: uint,               ;; Latest price from oracle
    timestamp: uint,           ;; When price was set
    confidence: uint,          ;; Price confidence score
    volume: uint,              ;; Trading volume
    block-height: uint         ;; Block when price was set
  }
)

(define-map aggregated-prices
  { asset: principal }
  {
    price: uint,               ;; Weighted average price
    last-update: uint,         ;; Last aggregation update
    participating-oracles: uint, ;; Number of oracles in aggregation
    confidence-score: uint,    ;; Overall confidence
    deviation: uint,           ;; Price deviation from previous
    circuit-breaker-active: bool ;; Circuit breaker status
  }
)

(define-map circuit-breaker-state
  { asset: principal }
  {
    is-triggered: bool,        ;; Circuit breaker status
    trigger-block: uint,       ;; When circuit breaker was triggered
    trigger-price: uint,       ;; Price that triggered circuit breaker
    recovery-threshold: uint,  ;; Price threshold for recovery
    manual-override: bool      ;; Manual override flag
  }
)

(define-data-var oracle-count uint u0)
(define-data-var emergency-pause bool false)
(define-data-var circuit-breaker principal .circuit-breaker)

;; =============================================================================
;; ORACLE MANAGEMENT
;; =============================================================================

(define-public (add-oracle (oracle principal) (weight uint))
  "Add new oracle with specified weight"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> weight u0) ERR_INVALID_ORACLE)
    (asserts! (is-none (map-get? oracle-config { oracle: oracle })) ERR_ORACLE_ALREADY_EXISTS)
    
    (map-set oracle-config 
      { oracle: oracle }
      {
        is-active: true,
        weight: weight,
        last-update: u0,
        total-updates: u0,
        failed-updates: u0,
        deviation-count: u0
      }
    )
    
    (var-set oracle-count (+ (var-get oracle-count) u1))
    (print { event: "oracle-added", oracle: oracle, weight: weight })
    (ok true)
  )
)

(define-public (update-oracle-weight (oracle principal) (new-weight uint))
  "Update oracle weight"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? oracle-config { oracle: oracle })
      config (begin
        (map-set oracle-config 
          { oracle: oracle }
          (merge config { weight: new-weight })
        )
        (print { event: "oracle-weight-updated", oracle: oracle, weight: new-weight })
        (ok true)
      )
      ERR_ORACLE_NOT_FOUND
    )
  )
)

(define-public (deactivate-oracle (oracle principal))
  "Deactivate oracle"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? oracle-config { oracle: oracle })
      config (begin
        (map-set oracle-config 
          { oracle: oracle }
          (merge config { is-active: false })
        )
        (print { event: "oracle-deactivated", oracle: oracle })
        (ok true)
      )
      ERR_ORACLE_NOT_FOUND
    )
  )
)

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

;; =============================================================================
;; PRICE FEED FUNCTIONS
;; =============================================================================

(define-public (update-price (asset principal) (price uint) (confidence uint) (volume uint))
  "Update price from oracle (called by registered oracles)"
  (let ((oracle tx-sender))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (match (map-get? oracle-config { oracle: oracle })
      config (begin
        (asserts! (get is-active config) ERR_NOT_AUTHORIZED)
        (asserts! (not (var-get emergency-pause)) ERR_CIRCUIT_BREAKER_TRIGGERED)
        
        ;; Validate price parameters
        (asserts! (> price u0) ERR_INVALID_ORACLE)
        (asserts! (<= confidence u1000000) ERR_INVALID_ORACLE)
        
        ;; Check for price deviation if previous price exists
        (match (map-get? price-feeds { oracle: oracle, asset: asset })
          previous-feed (let ((deviation (calculate-price-deviation price (get price previous-feed))))
            (if (> deviation MAX_PRICE_DEVIATION)
              (begin
                ;; Update deviation counter
                (map-set oracle-config 
                  { oracle: oracle }
                  (merge config { 
                    deviation-count: (+ (get deviation-count config) u1),
                    last-update: block-height,
                    total-updates: (+ (get total-updates config) u1)
                  })
                )
                ;; Still update price but flag high deviation
                (update-price-feed oracle asset price confidence volume true)
              )
              (begin
                ;; Normal price update
                (map-set oracle-config 
                  { oracle: oracle }
                  (merge config { 
                    last-update: block-height,
                    total-updates: (+ (get total-updates config) u1)
                  })
                )
                (update-price-feed oracle asset price confidence volume false)
              )
            )
          )
          ;; First price update for this oracle-asset pair
          (begin
            (map-set oracle-config 
              { oracle: oracle }
              (merge config { 
                last-update: block-height,
                total-updates: (+ (get total-updates config) u1)
              })
            )
            (update-price-feed oracle asset price confidence volume false)
          )
        )
        
        ;; Trigger price aggregation
        (try! (aggregate-prices asset))
        (ok true)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-private (update-price-feed (oracle principal) (asset principal) (price uint) (confidence uint) (volume uint) (high-deviation bool))
  "Internal function to update price feed"
  (begin
    (map-set price-feeds 
      { oracle: oracle, asset: asset }
      {
        price: price,
        timestamp: (unwrap-panic (get-block-info? time block-height)),
        confidence: confidence,
        volume: volume,
        block-height: block-height
      }
    )
    
    (print { 
      event: "price-updated", 
      oracle: oracle, 
      asset: asset, 
      price: price,
      confidence: confidence,
      high-deviation: high-deviation
    })
    (ok true)
  )
)

(define-private (calculate-price-deviation (new-price uint) (old-price uint))
  "Calculate percentage deviation between prices"
  (if (is-eq old-price u0)
    u0
    (let ((difference (if (> new-price old-price) 
                        (- new-price old-price) 
                        (- old-price new-price))))
      (/ (* difference PRICE_PRECISION) old-price)
    )
  )
)

;; =============================================================================
;; PRICE AGGREGATION
;; =============================================================================

(define-private (aggregate-prices (asset principal))
  "Aggregate prices from all active oracles"
  (let ((oracle-list (get-active-oracles))
        (valid-prices (get-valid-prices asset oracle-list)))
    (if (>= (len valid-prices) MIN_ORACLES_REQUIRED)
      (let ((weighted-price (calculate-weighted-average valid-prices))
            (confidence-score (calculate-confidence-score valid-prices))
            (price-deviation (calculate-aggregation-deviation asset weighted-price)))
        
        ;; Check circuit breaker conditions
        (if (> price-deviation CIRCUIT_BREAKER_DEVIATION)
          (try! (trigger-circuit-breaker asset weighted-price price-deviation))
          true
        )
        
        ;; Update aggregated price
        (map-set aggregated-prices 
          { asset: asset }
          {
            price: weighted-price,
            last-update: block-height,
            participating-oracles: (len valid-prices),
            confidence-score: confidence-score,
            deviation: price-deviation,
            circuit-breaker-active: (is-circuit-breaker-active asset)
          }
        )
        
        (print { 
          event: "price-aggregated", 
          asset: asset, 
          price: weighted-price,
          oracles: (len valid-prices),
          confidence: confidence-score
        })
        (ok true)
      )
      (err ERR_INSUFFICIENT_ORACLES)
    )
  )
)

(define-private (get-active-oracles)
  "Get list of active oracles (simplified - in full implementation would iterate)"
  ;; In a full implementation, this would iterate through all oracles
  ;; For now, return a placeholder list
  (list .oracle-1 .oracle-2 .oracle-3)
)

(define-private (get-valid-prices (asset principal) (oracles (list 10 principal)))
  "Get valid price feeds from oracles"
  ;; Filter prices that are not stale and from active oracles
  (fold validate-oracle-price oracles (list))
)

(define-private (validate-oracle-price (oracle principal) (valid-prices (list 10 { oracle: principal, price: uint, weight: uint, confidence: uint })))
  "Validate individual oracle price"
  (match (map-get? oracle-config { oracle: oracle })
    config (if (get is-active config)
      (match (map-get? price-feeds { oracle: oracle, asset: .sbtc-integration.SBTC-MAINNET }) ;; Simplified asset reference
        feed (if (< (- block-height (get block-height feed)) MAX_STALENESS_BLOCKS)
          (unwrap-panic (as-max-len? (append valid-prices {
            oracle: oracle,
            price: (get price feed),
            weight: (get weight config),
            confidence: (get confidence feed)
          }) u10))
          valid-prices
        )
        valid-prices
      )
      valid-prices
    )
    valid-prices
  )
)

(define-private (calculate-weighted-average (prices (list 10 { oracle: principal, price: uint, weight: uint, confidence: uint })))
  "Calculate weighted average price"
  (let ((totals (fold sum-weighted-prices prices { sum: u0, weight-sum: u0 })))
    (if (> (get weight-sum totals) u0)
      (/ (get sum totals) (get weight-sum totals))
      u0
    )
  )
)

(define-private (sum-weighted-prices 
  (price-info { oracle: principal, price: uint, weight: uint, confidence: uint })
  (acc { sum: uint, weight-sum: uint }))
  "Sum weighted prices for average calculation"
  {
    sum: (+ (get sum acc) (* (get price price-info) (get weight price-info))),
    weight-sum: (+ (get weight-sum acc) (get weight price-info))
  }
)

(define-private (calculate-confidence-score (prices (list 10 { oracle: principal, price: uint, weight: uint, confidence: uint })))
  "Calculate overall confidence score"
  (let ((confidence-sum (fold sum-confidence prices u0))
        (count (len prices)))
    (if (> count u0)
      (/ confidence-sum count)
      u0
    )
  )
)

(define-private (sum-confidence 
  (price-info { oracle: principal, price: uint, weight: uint, confidence: uint })
  (acc uint))
  "Sum confidence scores"
  (+ acc (get confidence price-info))
)

(define-private (calculate-aggregation-deviation (asset principal) (new-price uint))
  "Calculate deviation from previous aggregated price"
  (match (map-get? aggregated-prices { asset: asset })
    previous (calculate-price-deviation new-price (get price previous))
    u0
  )
)

;; =============================================================================
;; CIRCUIT BREAKER
;; =============================================================================

(define-private (trigger-circuit-breaker (asset principal) (trigger-price uint) (deviation uint))
  "Trigger circuit breaker for asset"
  (begin
    (map-set circuit-breaker-state 
      { asset: asset }
      {
        is-triggered: true,
        trigger-block: block-height,
        trigger-price: trigger-price,
        recovery-threshold: (/ (* trigger-price (- PRICE_PRECISION (/ CIRCUIT_BREAKER_DEVIATION u2))) PRICE_PRECISION),
        manual-override: false
      }
    )
    
    (print { 
      event: "circuit-breaker-triggered", 
      asset: asset, 
      price: trigger-price,
      deviation: deviation
    })
    (ok true)
  )
)

(define-public (reset-circuit-breaker (asset principal))
  "Reset circuit breaker (admin only)"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-delete circuit-breaker-state { asset: asset })
    (print { event: "circuit-breaker-reset", asset: asset })
    (ok true)
  )
)

(define-public (manual-price-override (asset principal) (price uint))
  "Manual price override during circuit breaker"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? circuit-breaker-state { asset: asset })
      cb-state (begin
        (map-set aggregated-prices 
          { asset: asset }
          {
            price: price,
            last-update: block-height,
            participating-oracles: u0,
            confidence-score: u500000, ;; 50% confidence for manual override
            deviation: u0,
            circuit-breaker-active: true
          }
        )
        
        (map-set circuit-breaker-state 
          { asset: asset }
          (merge cb-state { manual-override: true })
        )
        
        (print { event: "manual-price-override", asset: asset, price: price })
        (ok true)
      )
      ERR_CIRCUIT_BREAKER_TRIGGERED
    )
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-price (asset principal))
  "Get latest aggregated price for asset"
  (match (map-get? aggregated-prices { asset: asset })
    price-data (if (get circuit-breaker-active price-data)
      (err ERR_CIRCUIT_BREAKER_TRIGGERED)
      (ok (get price price-data))
    )
    (err ERR_PRICE_STALE)
  )
)

(define-read-only (get-price-with-metadata (asset principal))
  "Get price with full metadata"
  (map-get? aggregated-prices { asset: asset })
)

(define-read-only (get-oracle-config (oracle principal))
  "Get oracle configuration"
  (map-get? oracle-config { oracle: oracle })
)

(define-read-only (is-circuit-breaker-active (asset principal))
  "Check if circuit breaker is active for asset"
  (match (map-get? circuit-breaker-state { asset: asset })
    cb-state (get is-triggered cb-state)
    false
  )
)

(define-read-only (get-oracle-price (oracle principal) (asset principal))
  "Get individual oracle price"
  (map-get? price-feeds { oracle: oracle, asset: asset })
)

(define-read-only (is-price-stale (asset principal))
  "Check if aggregated price is stale"
  (match (map-get? aggregated-prices { asset: asset })
    price-data (> (- block-height (get last-update price-data)) MAX_STALENESS_BLOCKS)
    true
  )
)

;; =============================================================================
;; EMERGENCY CONTROLS
;; =============================================================================

(define-public (emergency-pause)
  "Emergency pause all price updates"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set emergency-pause true)
    (print { event: "emergency-pause" })
    (ok true)
  )
)

(define-public (resume-operations)
  "Resume normal operations"
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set emergency-pause false)
    (print { event: "operations-resumed" })
    (ok true)
  )
)






