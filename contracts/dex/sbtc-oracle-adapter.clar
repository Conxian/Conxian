;; sbtc-oracle-adapter.clar
;; sBTC Oracle Adapter - Advanced price feeds and circuit breaker integration
;; Handles multiple oracle sources, price validation, and emergency controls

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================
(define-constant ONE_DAY u17280) ;; u144 * 120
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
(define-constant MAX_PRICE_DEVIATION u100000) ;; 10% max deviation
(define-constant MAX_STALENESS_BLOCKS u2073600) ;; ~24 hours (assuming 10 min blocks)
(define-constant MIN_ORACLES_REQUIRED u2) ;; Minimum oracles for consensus
(define-constant PRICE_PRECISION u1000000) ;; 6 decimal places

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================
(define-map oracle-config
  { oracle: principal }
  {
    is-active: bool,
    weight: uint,
    last-update: uint,
    total-updates: uint,
    failed-updates: uint,
    deviation-count: uint
  }
)

(define-map price-feeds
  { oracle: principal, asset: principal }
  {
    price: uint,
    timestamp: uint,
    confidence: uint,
    volume: uint,
    block-height: uint
  }
)

(define-map aggregated-prices
  { asset: principal }
  {
    price: uint,
    last-update: uint,
    participating-oracles: uint,
    confidence-score: uint,
    deviation: uint
  }
)

(define-data-var oracle-count uint u0)
(define-data-var circuit-breaker-contract principal .circuit-breaker)

;; =============================================================================
;; ORACLE MANAGEMENT
;; =============================================================================
(define-public (add-oracle (oracle principal) (weight uint))
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
    (var-set circuit-breaker-contract new-circuit-breaker)
    (ok true)
  )
)

;; =============================================================================
;; PRICE FEED FUNCTIONS
;; =============================================================================
(define-public (update-price (asset principal) (price uint) (confidence uint) (volume uint))
  (let ((oracle tx-sender))
    (asserts! (not (check-circuit-breaker-status)) ERR_CIRCUIT_OPEN)
    (match (map-get? oracle-config { oracle: oracle })
      config (begin
        (asserts! (get is-active config) ERR_NOT_AUTHORIZED)
        
        ;; Validate price parameters
        (asserts! (> price u0) ERR_INVALID_ORACLE)
        (asserts! (<= confidence u1000000) ERR_INVALID_ORACLE)
        
        ;; Check for price deviation if previous price exists
        (match (map-get? price-feeds { oracle: oracle, asset: asset })
          previous-feed (let ((deviation (calculate-price-deviation price (get price previous-feed))))
            (if (> deviation MAX_PRICE_DEVIATION)
              (begin
                (map-set oracle-config
                  { oracle: oracle }
                  (merge config {
                    deviation-count: (+ (get deviation-count config) u1),
                    last-update: block-height,
                    total-updates: (+ (get total-updates config) u1)
                  })
                )
                (try! (update-price-feed oracle asset price confidence volume true))
              )
              (begin
                (map-set oracle-config
                  { oracle: oracle }
                  (merge config {
                    last-update: block-height,
                    total-updates: (+ (get total-updates config) u1)
                  })
                )
                (try! (update-price-feed oracle asset price confidence volume false))
              )
            )
          )
          (begin
            (map-set oracle-config
              { oracle: oracle }
              (merge config {
                last-update: block-height,
                total-updates: (+ (get total-updates config) u1)
              })
            )
            (try! (update-price-feed oracle asset price confidence volume false))
          )
        )
        
        (try! (aggregate-prices asset))
        (ok true)
      )
      ERR_NOT_AUTHORIZED
    )
  )
)

(define-private (update-price-feed (oracle principal) (asset principal) (price uint) (confidence uint) (volume uint) (high-deviation bool))
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
  (let (
    (oracle-list (get-active-oracles))
    (valid-prices (get-valid-prices asset oracle-list))
  )
    (if (>= (len valid-prices) MIN_ORACLES_REQUIRED)
      (let (
        (weighted-price (calculate-weighted-average valid-prices))
        (confidence-score (calculate-confidence-score valid-prices))
        (price-deviation (calculate-aggregation-deviation asset weighted-price))
      )
        (if (> price-deviation (get-deviation-threshold (var-get circuit-breaker-contract)))
          (try! (contract-call? (var-get circuit-breaker-contract) trip-circuit "sbtc-oracle-adapter" asset weighted-price price-deviation))
          true
        )
        
        (map-set aggregated-prices
          { asset: asset }
          {
            price: weighted-price,
            last-update: block-height,
            participating-oracles: (len valid-prices),
            confidence-score: confidence-score,
            deviation: price-deviation
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
  (list)
)

(define-private (get-valid-prices (asset principal) (oracles (list 10 principal)))
  (fold (validate-oracle-price asset) oracles (list))
)

(define-private (validate-oracle-price (asset principal) (oracle principal) (valid-prices (list 10 { oracle: principal, price: uint, weight: uint, confidence: uint })))
  (match (map-get? oracle-config { oracle: oracle })
    config (if (get is-active config)
      (match (map-get? price-feeds { oracle: oracle, asset: asset })
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
  {
    sum: (+ (get sum acc) (* (get price price-info) (get weight price-info))),
    weight-sum: (+ (get weight-sum acc) (get weight price-info))
  }
)

(define-private (calculate-confidence-score (prices (list 10 { oracle: principal, price: uint, weight: uint, confidence: uint })))
  (let (
    (confidence-sum (fold sum-confidence prices u0))
    (count (len prices))
  )
    (if (> count u0)
      (/ confidence-sum count)
      u0
    )
  )
)

(define-private (sum-confidence
  (price-info { oracle: principal, price: uint, weight: uint, confidence: uint })
  (acc uint))
  (+ acc (get confidence price-info))
)

(define-private (calculate-aggregation-deviation (asset principal) (new-price uint))
  (match (map-get? aggregated-prices { asset: asset })
    previous (calculate-price-deviation new-price (get price previous))
    u0
  )
)

;; =============================================================================
;; CIRCUIT BREAKER
;; =============================================================================
(define-private (check-circuit-breaker-status)
  (contract-call? (var-get circuit-breaker-contract) is-circuit-open "sbtc-oracle-adapter")
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
(define-read-only (get-price (asset principal))
  (match (map-get? aggregated-prices { asset: asset })
    price-data (if (contract-call? (var-get circuit-breaker-contract) is-circuit-open "sbtc-oracle-adapter" asset)
      (err ERR_CIRCUIT_BREAKER_TRIGGERED)
      (ok (get price price-data)))
    none (err ERR_PRICE_NOT_AVAILABLE)
  )
)






