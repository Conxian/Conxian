;; Liquidity Manager Contract
;; This contract manages liquidity across different pools and implements rebalancing logic

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait pool-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.pool-trait)
(use-trait oracle-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.oracle-trait)
(use-trait circuit-breaker-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_POOL (err u1001))
(define-constant ERR_INVALID_TOKEN (err u1002))
(define-constant ERR_INSUFFICIENT_LIQUIDITY (err u1003))
(define-constant ERR_REBALANCE_FAILED (err u1004))
(define-constant ERR_CIRCUIT_BREAKER_ACTIVE (err u1005))
(define-constant ERR_BELOW_THRESHOLD (err u1006))
(define-constant ERR_INVALID_PARAMETER (err u1007))
(define-constant ERR_EMERGENCY_MODE_ACTIVE (err u1008))

;; Constants for metrics and thresholds
(define-constant DEFAULT_UTILIZATION_THRESHOLD u8000) ;; 80% scaled by 10000
(define-constant DEFAULT_YIELD_THRESHOLD u500) ;; 5% scaled by 10000
(define-constant DEFAULT_RISK_THRESHOLD u2000) ;; 20% scaled by 10000
(define-constant DEFAULT_PERFORMANCE_THRESHOLD u7500) ;; 75% scaled by 10000
(define-constant EMERGENCY_THRESHOLD u9500) ;; 95% scaled by 10000
(define-constant MAX_POOLS_PER_TOKEN u10)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var oracle-contract (optional principal) none)
(define-data-var circuit-breaker-contract (optional principal) none)
(define-data-var emergency-mode bool false)
(define-data-var last-rebalance-block uint u0)
(define-data-var rebalance-frequency uint u144) ;; Default: once per day (144 blocks)

;; Maps for tracking pools, tokens, and metrics
(define-map registered-pools principal 
  {
    token-x: principal,
    token-y: principal,
    active: bool,
    last-rebalance: uint,
    utilization: uint,
    yield-rate: uint,
    risk-score: uint,
    performance-score: uint
  }
)

(define-map token-pools { token: principal } { pools: (list 10 principal) })

(define-map rebalance-thresholds principal 
  {
    utilization-threshold: uint,
    yield-threshold: uint,
    risk-threshold: uint,
    performance-threshold: uint
  }
)

(define-map liquidity-metrics principal 
  {
    total-liquidity: uint,
    active-liquidity: uint,
    idle-liquidity: uint,
    rebalance-count: uint
  }
)

;; Admin functions

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (set-oracle-contract (new-oracle principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set oracle-contract (some new-oracle)))
  )
)

(define-public (set-circuit-breaker-contract (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set circuit-breaker-contract (some new-circuit-breaker)))
  )
)

(define-public (set-rebalance-frequency (blocks uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> blocks u0) ERR_INVALID_PARAMETER)
    (ok (var-set rebalance-frequency blocks))
  )
)

(define-public (set-emergency-mode (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set emergency-mode active))
  )
)

;; Pool registration and management

(define-public (register-pool (pool-contract <pool-trait>))
  (let ((pool-principal (contract-of pool-contract))
        (token-x (unwrap! (contract-call? pool-contract get-token-x) ERR_INVALID_POOL))
        (token-y (unwrap! (contract-call? pool-contract get-token-y) ERR_INVALID_POOL)))
    
    ;; Check authorization
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    ;; Register the pool
    (map-set registered-pools pool-principal 
      {
        token-x: token-x,
        token-y: token-y,
        active: true,
        last-rebalance: u0,
        utilization: u0,
        yield-rate: u0,
        risk-score: u0,
        performance-score: u0
      }
    )
    
    ;; Add pool to token-pools mapping for token-x
    (add-pool-to-token token-x pool-principal)
    
    ;; Add pool to token-pools mapping for token-y
    (add-pool-to-token token-y pool-principal)
    
    ;; Initialize metrics
    (map-set liquidity-metrics pool-principal
      {
        total-liquidity: u0,
        active-liquidity: u0,
        idle-liquidity: u0,
        rebalance-count: u0
      }
    )
    
    ;; Set default thresholds
    (map-set rebalance-thresholds pool-principal
      {
        utilization-threshold: DEFAULT_UTILIZATION_THRESHOLD,
        yield-threshold: DEFAULT_YIELD_THRESHOLD,
        risk-threshold: DEFAULT_RISK_THRESHOLD,
        performance-threshold: DEFAULT_PERFORMANCE_THRESHOLD
      }
    )
    
    (ok true)
  )
)

(define-private (add-pool-to-token (token principal) (pool principal))
  (let ((current-pools (default-to {pools: (list)} (map-get? token-pools {token: token}))))
    (map-set token-pools 
      {token: token} 
      {pools: (unwrap! (as-max-len? (append (get pools current-pools) pool) MAX_POOLS_PER_TOKEN) ERR_INVALID_PARAMETER)}
    )
  )
)

(define-public (update-pool-status (pool-contract <pool-trait>) (active bool))
  (let ((pool-principal (contract-of pool-contract)))
    ;; Check authorization
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    
    ;; Check if pool exists
    (asserts! (is-some (map-get? registered-pools pool-principal)) ERR_INVALID_POOL)
    
    ;; Update pool status
    (map-set registered-pools pool-principal 
      (merge (unwrap-panic (map-get? registered-pools pool-principal)) {active: active})
    )
    
    (ok true)
  )
)

;; Metrics and rebalancing functions

(define-public (update-pool-metrics (pool-contract <pool-trait>))
  (let ((pool-principal (contract-of pool-contract))
        (oracle (unwrap! (var-get oracle-contract) ERR_INVALID_PARAMETER)))
    
    ;; Check if pool exists and is active
    (asserts! (is-some (map-get? registered-pools pool-principal)) ERR_INVALID_POOL)
    (asserts! (get active (unwrap-panic (map-get? registered-pools pool-principal))) ERR_INVALID_POOL)
    
    ;; Get current metrics from pool
    (let ((utilization (unwrap! (contract-call? pool-contract get-utilization) ERR_INVALID_POOL))
          (yield-rate (unwrap! (contract-call? pool-contract get-yield-rate) ERR_INVALID_POOL))
          (risk-score (unwrap! (contract-call? oracle get-risk-score pool-principal) ERR_INVALID_POOL))
          (performance-score (calculate-performance-score utilization yield-rate risk-score)))
      
      ;; Update pool metrics
      (map-set registered-pools pool-principal 
        (merge (unwrap-panic (map-get? registered-pools pool-principal)) 
          {
            utilization: utilization,
            yield-rate: yield-rate,
            risk-score: risk-score,
            performance-score: performance-score
          }
        )
      )
      
      (ok {
        utilization: utilization,
        yield-rate: yield-rate,
        risk-score: risk-score,
        performance-score: performance-score
      })
    )
  )
)

(define-private (calculate-performance-score (utilization uint) (yield-rate uint) (risk-score uint))
  ;; Performance score formula: (yield-rate * 0.5) + (utilization * 0.3) - (risk-score * 0.2)
  ;; All values are scaled by 10000
  (let ((yield-component (* yield-rate u5000))
        (utilization-component (* utilization u3000))
        (risk-component (* risk-score u2000)))
    
    ;; Calculate weighted score and ensure it's not negative
    (let ((weighted-score (- (+ (/ yield-component u10000) (/ utilization-component u10000)) (/ risk-component u10000))))
      (if (> weighted-score u10000)
          u10000
          weighted-score)
    )
  )
)

(define-public (check-rebalance-needed (pool-contract <pool-trait>))
  (let ((pool-principal (contract-of pool-contract))
        (pool-data (unwrap! (map-get? registered-pools pool-principal) ERR_INVALID_POOL))
        (thresholds (unwrap! (map-get? rebalance-thresholds pool-principal) ERR_INVALID_PARAMETER)))
    
    ;; Check if pool is active
    (asserts! (get active pool-data) ERR_INVALID_POOL)
    
    ;; Check if circuit breaker is active
    (match (var-get circuit-breaker-contract)
      circuit-breaker (asserts! (not (unwrap! (contract-call? circuit-breaker is-circuit-breaker-active pool-principal) ERR_INVALID_PARAMETER)) ERR_CIRCUIT_BREAKER_ACTIVE)
      true
    )
    
    ;; Check if emergency mode is active
    (if (var-get emergency-mode)
        ;; In emergency mode, check against emergency threshold
        (ok (> (get utilization pool-data) EMERGENCY_THRESHOLD))
        
        ;; Normal mode - check against configured thresholds
        (ok (or
          (> (get utilization pool-data) (get utilization-threshold thresholds))
          (< (get yield-rate pool-data) (get yield-threshold thresholds))
          (> (get risk-score pool-data) (get risk-threshold thresholds))
          (< (get performance-score pool-data) (get performance-threshold thresholds))
        ))
    )
  )
)

(define-public (rebalance-pool (pool-contract <pool-trait>))
  (let ((pool-principal (contract-of pool-contract))
        (pool-data (unwrap! (map-get? registered-pools pool-principal) ERR_INVALID_POOL))
        (current-block block-height))
    
    ;; Check if pool is active
    (asserts! (get active pool-data) ERR_INVALID_POOL)
    
    ;; Check if rebalance is needed
    (asserts! (unwrap! (check-rebalance-needed pool-contract) ERR_INVALID_PARAMETER) ERR_BELOW_THRESHOLD)
    
    ;; Check if enough blocks have passed since last rebalance
    (asserts! (>= (- current-block (get last-rebalance pool-data)) (var-get rebalance-frequency)) ERR_BELOW_THRESHOLD)
    
    ;; Perform rebalance operation
    (try! (contract-call? pool-contract rebalance))
    
    ;; Update last rebalance time
    (map-set registered-pools pool-principal 
      (merge pool-data {last-rebalance: current-block})
    )
    
    ;; Update metrics
    (try! (update-pool-metrics pool-contract))
    
    ;; Update rebalance count
    (let ((metrics (unwrap! (map-get? liquidity-metrics pool-principal) ERR_INVALID_POOL)))
      (map-set liquidity-metrics pool-principal
        (merge metrics {rebalance-count: (+ (get rebalance-count metrics) u1)})
      )
    )
    
    ;; Update global last rebalance block
    (var-set last-rebalance-block current-block)
    
    (ok true)
  )
)

;; Read-only functions

(define-read-only (get-pool-metrics (pool principal))
  (match (map-get? registered-pools pool)
    pool-data (ok {
      token-x: (get token-x pool-data),
      token-y: (get token-y pool-data),
      active: (get active pool-data),
      last-rebalance: (get last-rebalance pool-data),
      utilization: (get utilization pool-data),
      yield-rate: (get yield-rate pool-data),
      risk-score: (get risk-score pool-data),
      performance-score: (get performance-score pool-data)
    })
    (err ERR_INVALID_POOL)
  )
)

(define-read-only (get-token-pools (token principal))
  (match (map-get? token-pools {token: token})
    token-data (ok (get pools token-data))
    (err ERR_INVALID_TOKEN)
  )
)

(define-read-only (get-liquidity-metrics (pool principal))
  (match (map-get? liquidity-metrics pool)
    metrics (ok metrics)
    (err ERR_INVALID_POOL)
  )
)

(define-read-only (get-rebalance-thresholds (pool principal))
  (match (map-get? rebalance-thresholds pool)
    thresholds (ok thresholds)
    (err ERR_INVALID_POOL)
  )
)

(define-read-only (get-emergency-mode)
  (ok (var-get emergency-mode))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)