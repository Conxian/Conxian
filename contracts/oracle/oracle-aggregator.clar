;; oracle-aggregator.clar
;; Aggregates price feeds from multiple oracles and provides TWAP calculations
;; Enhanced with statistical manipulation detection and multi-source aggregation

;; Traits
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait oracle-trait .all-traits.oracle-trait)
(use-trait access-control-trait .all-traits.access-control-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)
(use-trait oracle-aggregator-trait .all-traits.oracle-aggregator-trait)

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.oracle-aggregator-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_ORACLE (err u101))
(define-constant ERR_NO_PRICE_DATA (err u102))
(define-constant ERR_PRICE_MANIPULATION_DETECTED (err u103))
(define-constant ERR_OBSERVATION_PERIOD_TOO_SHORT (err u104))
(define-constant ERR_INSUFFICIENT_SOURCES (err u105))
(define-constant ERR_CONFIDENCE_TOO_LOW (err u106))
(define-constant ERR_VOLATILITY_TOO_HIGH (err u107))
(define-constant ERR_OUTLIER_DETECTED (err u108))
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE (err u109))

(define-constant MAX_OBSERVATIONS_PER_ASSET u100)
(define-constant MANIPULATION_THRESHOLD_PERCENTAGE u500) ;; 5% deviation
(define-constant MIN_CONFIDENCE_SCORE u7000) ;; 70% minimum confidence
(define-constant MIN_SOURCES_REQUIRED u2) ;; At least 2 sources needed
(define-constant MAX_VOLATILITY_THRESHOLD u1000) ;; 10% max volatility
(define-constant OUTLIER_THRESHOLD u2000) ;; 20% deviation from median

;; Data Maps
(define-map registered-oracles {
  oracle-id: principal
} {
  weight: uint,
  reliability-score: uint,
  last-update: uint
})

;; asset-prices: {asset: principal, block-height: uint} {price: uint}
(define-map asset-prices {
  asset: principal,
  block-height: uint
} {
  price: uint,
  confidence-score: uint,
  source-count: uint
})

;; last-observation-block: {asset: principal} {block-height: uint}
(define-map last-observation-block {
  asset: principal
} {
  block-height: uint
})

(define-map price-observations {
  asset: principal,
  block: uint
} {
  price: uint,
  volume: uint,
  confidence-score: uint
})

;; Price history for volatility calculation
(define-map price-history {
  asset: principal
} {
  prices: (list 20 uint),
  timestamps: (list 20 uint),
  volumes: (list 20 uint)
})

(define-map manipulation-thresholds
  {asset-id: (string-ascii 32)}
  {
    price-deviation-threshold: uint, ;; Basis points (e.g., 1000 = 10%)
    volume-deviation-threshold: uint, ;; Basis points (e.g., 1000 = 10%)
    time-window: uint, ;; Number of blocks to consider for deviation
    volatility-threshold: uint, ;; Maximum allowed volatility
    min-confidence-required: uint ;; Minimum confidence score required
  }
)

;; Breaker status tracking
(define-map circuit-breaker-status {
  asset: principal
} {
  is-active: bool,
  activation-block: uint,
  reason: (string-ascii 64)
})

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var observation-period-blocks uint u10)
(define-data-var circuit-breaker-contract (optional principal) none)
(define-data-var default-manipulation-threshold uint u500) ;; 5% default
(define-data-var default-confidence-threshold uint u7000) ;; 70% default

;; Public Functions
(define-public (register-oracle (oracle-id principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set registered-oracles 
      { oracle-id: oracle-id } 
      { 
        weight: weight,
        reliability-score: u10000, ;; Start at 100%
        last-update: block-height
      }
    )
    (ok true)
  )
)

(define-public (deregister-oracle (oracle-id principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete registered-oracles { oracle-id: oracle-id })
    (ok true)
  )
)

(define-public (update-oracle-reliability (oracle-id principal) (reliability-score uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? registered-oracles {oracle-id: oracle-id})) ERR_INVALID_ORACLE)
    (asserts! (<= reliability-score u10000) ERR_INVALID_ORACLE)
    
    (match (map-get? registered-oracles {oracle-id: oracle-id})
      oracle-data (map-set registered-oracles 
                    {oracle-id: oracle-id} 
                    (merge oracle-data {reliability-score: reliability-score}))
      (err ERR_INVALID_ORACLE)
    )
    (ok true)
  )
)

(define-public (set-circuit-breaker-contract (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set circuit-breaker-contract (some new-circuit-breaker)))
  )
)

(define-public (submit-price (asset principal) (price uint))
  (begin
    (asserts! (is-some (map-get? registered-oracles {oracle-id: tx-sender})) ERR_INVALID_ORACLE)
    
    ;; Get oracle weight and reliability
    (let ((oracle-data (unwrap-panic (map-get? registered-oracles {oracle-id: tx-sender})))
          (weight (get weight oracle-data))
          (reliability (get reliability-score oracle-data))
          (current-block block-height))
      
      ;; Check for circuit breaker status
      (match (map-get? circuit-breaker-status {asset: asset})
        breaker-data (if (get is-active breaker-data)
                        (err ERR_CIRCUIT_BREAKER_ACTIVE)
                        true)
        true
      )
      
      ;; Check for price manipulation before storing
      (let ((manipulation-result (detect-price-manipulation asset price)))
        (asserts! (is-ok manipulation-result) (unwrap-err manipulation-result))
        (if (unwrap-panic manipulation-result)
            (begin
              ;; Price manipulation detected, open the circuit breaker for this asset
              (try! (contract-call? (var-get circuit-breaker-contract) set-circuit-breaker-status asset true))
              (map-set circuit-breaker-status 
                {asset: asset} 
                {
                  is-active: true,
                  activation-block: current-block,
                  reason: "Price manipulation detected"
                }
              )
              (err ERR_PRICE_MANIPULATION_DETECTED))
          true)
      )
      
      ;; Calculate confidence score based on oracle reliability and recency
      (let ((confidence-score (/ (* reliability weight) u100)))
        
        ;; Store price observation for TWAP with volume and confidence
        (map-set price-observations 
          {asset: asset, block: current-block} 
          {
            price: price, 
            volume: u0, ;; Volume data would come from DEX integration
            confidence-score: confidence-score
          }
        )
        
        ;; Update last observation block
        (map-set last-observation-block {asset: asset} {block-height: current-block})
        
        ;; Store in asset prices
        (map-set asset-prices 
          {asset: asset, block-height: current-block} 
          {
            price: price,
            confidence-score: confidence-score,
            source-count: u1
          }
        )
        
        ;; Update price history for volatility calculation
        (match (map-get? price-history {asset: asset})
          history-data 
            (let ((prices (get prices history-data))
                  (timestamps (get timestamps history-data))
                  (volumes (get volumes history-data)))
              
              ;; Add new data to the front, remove oldest if at capacity
              (let ((new-prices (as-max-len? (append (list price) prices) u20))
                    (new-timestamps (as-max-len? (append (list current-block) timestamps) u20))
                    (new-volumes (as-max-len? (append (list u0) volumes) u20)))
                
                (if (and (is-some new-prices) (is-some new-timestamps) (is-some new-volumes))
                    (map-set price-history 
                      {asset: asset} 
                      {
                        prices: (unwrap-panic new-prices),
                        timestamps: (unwrap-panic new-timestamps),
                        volumes: (unwrap-panic new-volumes)
                      }
                    )
                    true
                )
              )
            )
          ;; No history yet, create new entry
          (map-set price-history 
            {asset: asset} 
            {
              prices: (list price),
              timestamps: (list current-block),
              volumes: (list u0)
            }
          )
        )
        
        ;; Clean up old observations if MAX_OBSERVATIONS_PER_ASSET is exceeded
        (let ((oldest-block (- current-block MAX_OBSERVATIONS_PER_ASSET)))
          (map-delete price-observations {asset: asset, block: oldest-block})
        )
        
        ;; Update oracle's last update time
        (map-set registered-oracles 
          {oracle-id: tx-sender} 
          (merge oracle-data {last-update: current-block})
        )
        
        (ok true)
      )
    )
  )
)

;; Simplified aggregated price: return last submitted price
(define-read-only (get-aggregated-price (asset principal))
  (let ((result (get-price-with-confidence asset)))
    (match result
      price-data (ok (get price price-data))
      error (err error)
    )
  )
)

(define-read-only (get-price-with-confidence (asset principal))
  (let ((current-block block-height))
    ;; Check if circuit breaker is active
    (match (map-get? circuit-breaker-status {asset: asset})
      breaker-data (if (get is-active breaker-data)
                      (err ERR_CIRCUIT_BREAKER_ACTIVE)
                      true)
      true
    )
    
    ;; Get latest price data
    (match (map-get? asset-prices {asset: asset, block-height: current-block})
      price-data 
        (let ((confidence (get confidence-score price-data))
              (source-count (get source-count price-data)))
          
          ;; Check if we have enough sources
          (if (< source-count MIN_SOURCES_REQUIRED)
              (err ERR_INSUFFICIENT_SOURCES)
              
              ;; Check if confidence is high enough
              (if (< confidence MIN_CONFIDENCE_SCORE)
                  (err ERR_CONFIDENCE_TOO_LOW)
                  
                  ;; Return price with confidence
                  (ok {
                    price: (get price price-data),
                    confidence: confidence,
                    sources: source-count
                  })
              )
          )
        )
      ;; No price data for current block, try TWAP
      (let ((twap-result (get-twap-price asset)))
        (match twap-result
          twap-price (ok {
                        price: twap-price,
                        confidence: MIN_CONFIDENCE_SCORE,
                        sources: MIN_SOURCES_REQUIRED
                      })
          error (err error)
        )
      )
    )
  )
)

(define-read-only (get-twap-price (asset principal))
  (get-twap-with-period asset MAX_OBSERVATIONS_PER_ASSET)
)

(define-read-only (get-twap-with-period (asset principal) (period uint))
  (let ((current-block block-height)
        (last-block (get block-height (default-to {block-height: u0} (map-get? last-observation-block {asset: asset}))))
        (actual-period (min period MAX_OBSERVATIONS_PER_ASSET)))
    
    ;; Check if we have any price data
    (if (is-eq last-block u0)
        (err ERR_NO_PRICE_DATA)
        
        ;; Check if circuit breaker is active
        (match (map-get? circuit-breaker-status {asset: asset})
          breaker-data (if (get is-active breaker-data)
                          (err ERR_CIRCUIT_BREAKER_ACTIVE)
                          true)
          true
        )
        
        ;; Calculate start block based on period
        (let ((start-block (max (- current-block actual-period) u0))
              (sum-price u0)
              (sum-confidence u0)
              (count u0))
          
          ;; Use fold to calculate weighted TWAP
          (let ((result (fold calculate-weighted-twap-iter
                        (get-block-range start-block last-block)
                        {asset: asset, sum-price: sum-price, sum-confidence: sum-confidence, count: count})))
            
            ;; Check if we have enough data points
            (if (< (get count result) MIN_SOURCES_REQUIRED)
                (err ERR_INSUFFICIENT_SOURCES)
                
                ;; Calculate average confidence score
                (let ((avg-confidence (if (> (get count result) u0)
                                        (/ (get sum-confidence result) (get count result))
                                        u0)))
                  
                  ;; Check if confidence score is sufficient
                  (if (< avg-confidence MIN_CONFIDENCE_SCORE)
                      (err ERR_CONFIDENCE_TOO_LOW)
                      
                      ;; Return weighted average price
                      (ok (/ (get sum-price result) (get count result)))
                  )
                )
            )
          )
        )
    )
  )
)

;; Helper function for weighted TWAP calculation
(define-private (calculate-weighted-twap-iter (block uint) (result {asset: principal, sum-price: uint, sum-confidence: uint, count: uint}))
  (let ((asset (get asset result))
        (sum-price (get sum-price result))
        (sum-confidence (get sum-confidence result))
        (count (get count result)))
    
    (match (map-get? price-observations {asset: asset, block: block})
      observation 
        (let ((price (get price observation))
              (confidence (default-to u80 (get confidence-score observation))))
          
          ;; Weight price by confidence score
          {
            asset: asset,
            sum-price: (+ sum-price (* price confidence)),
            sum-confidence: (+ sum-confidence confidence),
            count: (+ count u1)
          }
        )
      ;; No observation for this block
      result
    )
  )
)

(define-read-only (detect-price-manipulation (asset principal) (current-price uint))
  (let ((twap-result (get-twap-price asset))
        (asset-id-str (unwrap-panic (contract-of asset)))) ;; Assuming asset principal can be converted to string-ascii 32
    (if (is-err twap-result)
        (err ERR_NO_PRICE_DATA) ;; Or a more specific error for TWAP failure
      (let ((twap-price (unwrap-panic twap-result))
            (thresholds (map-get? manipulation-thresholds {asset-id: asset-id-str})))
        (if (is-none thresholds)
            (ok false) ;; No manipulation thresholds set, so no manipulation detected
          (let ((price-deviation-threshold (get price-deviation-threshold (unwrap-panic thresholds))))
            (if (is-eq twap-price u0)
                (ok false) ;; Avoid division by zero, consider as no manipulation
              (let ((deviation (abs (- current-price twap-price)))
                    (deviation-percentage (/ (* deviation u10000) twap-price)))
                (if (> deviation-percentage price-deviation-threshold)
                    (ok true) ;; Price manipulation detected
                    ;; If TWAP deviation is acceptable, check statistical outlier
                    (detect-statistical-outlier asset current-price)
                )
              )
            )
          )
        )
      )
    )
  )
)

(define-read-only (detect-statistical-outlier (asset principal) (price uint))
  (match (map-get? price-history {asset: asset})
    history-data 
      (let ((prices (get prices history-data))
            (volatility (calculate-price-volatility prices))
            (median-price (calculate-median prices)))
        
        ;; Check if volatility is too high
        (if (> volatility MAX_VOLATILITY_THRESHOLD)
            (err ERR_VOLATILITY_TOO_HIGH)
            
            ;; Calculate deviation from median
            (let ((price-diff (if (> price median-price)
                                (- price median-price)
                                (- median-price price)))
                  (percentage-diff (/ (* price-diff u10000) median-price)))
              
              ;; Check if price is an outlier
              (ok (> percentage-diff OUTLIER_THRESHOLD))
            )
        )
      )
    ;; Not enough history for statistical analysis
    (ok false)
  )
)

(define-private (calculate-price-volatility (prices (list 20 uint)))
  (let ((count (len prices))
        (avg (calculate-average prices)))
    
    ;; Need at least 2 prices to calculate volatility
    (if (< count u2)
        u0
        ;; Calculate sum of squared differences
        (let ((sum-squared-diff (fold calculate-squared-diff-iter prices {avg: avg, sum: u0})))
          ;; Return standard deviation as percentage of average (scaled by 10000)
          (/ (* (sqrti (/ (get sum sum-squared-diff) count)) u10000) avg)
        )
    )
  )
)

(define-private (calculate-squared-diff-iter (price uint) (result {avg: uint, sum: uint}))
  (let ((avg (get avg result))
        (sum (get sum result))
        (diff (if (> price avg)
                (- price avg)
                (- avg price))))
    {avg: avg, sum: (+ sum (* diff diff))}
  )
)

(define-private (calculate-median (prices (list 20 uint)))
  (let ((sorted-prices (sort prices))
        (count (len prices)))
    
    (if (is-eq count u0)
        u0
        (if (is-eq (mod count u2) u0)
            ;; Even number of elements, average the middle two
            (let ((mid (/ count u2))
                  (val1 (unwrap-panic (element-at sorted-prices (- mid u1))))
                  (val2 (unwrap-panic (element-at sorted-prices mid))))
              (/ (+ val1 val2) u2)
            )
            ;; Odd number of elements, return the middle one
            (unwrap-panic (element-at sorted-prices (/ count u2)))
        )
    )
  )
)

(define-private (calculate-average (prices (list 20 uint)))
  (let ((count (len prices))
        (sum (fold + prices u0)))
    (if (is-eq count u0)
        u0
        (/ sum count)
    )
  )
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-read-only (get-observation-period-blocks)
  (ok (var-get observation-period-blocks))
)

(define-public (set-observation-period-blocks (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> new-period u0) ERR_OBSERVATION_PERIOD_TOO_SHORT)
    (var-set observation-period-blocks new-period)
    (ok true)
  )
)

(define-public (set-manipulation-thresholds
  (asset-id (string-ascii 32))
  (price-deviation-threshold uint)
  (volume-deviation-threshold uint)
  (time-window uint)
)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set manipulation-thresholds
      {asset-id: asset-id}
      {
        price-deviation-threshold: price-deviation-threshold,
        volume-deviation-threshold: volume-deviation-threshold,
        time-window: time-window
      }
    )
    (ok true)
  )
)

(define-read-only (get-manipulation-thresholds (asset-id (string-ascii 32)))
  (ok (map-get? manipulation-thresholds {asset-id: asset-id}))
)
