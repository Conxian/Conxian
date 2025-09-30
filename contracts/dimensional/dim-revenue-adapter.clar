;; dim-revenue-adapter.clar
;; Integration adapter connecting dimensional yield system with enhanced tokenomics
;; Routes dimensional rewards through revenue distributor for proper token holder distribution

;; --- Traits ---
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait ownable-trait .all-traits.ownable-trait)

(impl-trait .ownable-trait)

;; --- Constants ---
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u800)
(define-constant ERR_INVALID_AMOUNT u801)
(define-constant ERR_SYSTEM_PAUSED u802)
(define-constant ERR_REVENUE_DISTRIBUTION_FAILED u803)
(define-constant ERR_CONTRACT_NOT_SET u804)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var revenue-distributor (optional principal) none)
(define-data-var token-coordinator (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; Dimensional contract references
(define-data-var dim-yield-contract (optional principal) none)
(define-data-var dim-registry-contract (optional principal) none)
(define-data-var dim-metrics-contract (optional principal) none)

;; Revenue routing configuration
(define-data-var dimensional-revenue-share uint u2000) ;; 20% of dimensional yield goes to token holders
(define-data-var treasury-share uint u3000) ;; 30% to treasury
(define-data-var reserve-share uint u5000) ;; 50% stays in dimensional system

;; Tracking dimensional revenue
(define-data-var total-dimensional-revenue uint u0)
(define-data-var total-distributed-revenue uint u0)

;; Per-dimension revenue tracking
(define-map dimension-revenue { dim-id: uint } { total-collected: uint, last-distribution: uint })

;; --- Admin Functions ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (configure-system-contracts
    (revenue-dist principal)
    (coordinator principal)
    (monitor principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set revenue-distributor (some revenue-dist))
    (var-set token-coordinator (some coordinator))
    (var-set protocol-monitor (some monitor))
    (ok true)))

(define-public (configure-dimensional-contracts
    (yield-contract principal)
    (registry-contract principal)
    (metrics-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (var-set dim-yield-contract (some yield-contract))
    (var-set dim-registry-contract (some registry-contract))
    (var-set dim-metrics-contract (some metrics-contract))
    (ok true)))

(define-public (set-revenue-shares 
    (token-holder-share uint)
    (treasury-share-new uint)
    (reserve-share-new uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (is-eq (+ token-holder-share treasury-share-new reserve-share-new) u10000) (err ERR_INVALID_AMOUNT))
    (var-set dimensional-revenue-share token-holder-share)
    (var-set treasury-share treasury-share-new)
    (var-set reserve-share reserve-share-new)
    (ok true)))

;; --- Integration Functions ---

;; Called by dimensional yield contract when rewards are distributed
(define-public (report-dimensional-yield 
    (dim-id uint)
    (total-yield uint)
    (reward-token <sip-010-ft-trait>))
  (begin
    ;; Only dimensional yield contract can call this
    (asserts! (is-some (var-get dim-yield-contract)) (err ERR_CONTRACT_NOT_SET))
    (asserts! (is-eq tx-sender (unwrap-panic (var-get dim-yield-contract))) (err ERR_UNAUTHORIZED))
    (asserts! (> total-yield u0) (err ERR_INVALID_AMOUNT))
    
    ;; Check system operational status
    (match (var-get protocol-monitor)
      monitor-contract
        (asserts! (unwrap! (contract-call? monitor-contract is-system-operational) (err ERR_SYSTEM_PAUSED)) (err ERR_SYSTEM_PAUSED))
      true)
    
    ;; Calculate revenue splits
    (let ((token-holder-portion (/ (* total-yield (var-get dimensional-revenue-share)) u10000))
          (treasury-portion (/ (* total-yield (var-get treasury-share)) u10000))
          (reserve-portion (- total-yield (+ token-holder-portion treasury-portion))))
      
      ;; Update tracking
      (let ((current-revenue (default-to { total-collected: u0, last-distribution: u0 } 
                                        (map-get? dimension-revenue { dim-id: dim-id }))))
        (map-set dimension-revenue { dim-id: dim-id }
          {
            total-collected: (+ (get total-collected current-revenue) total-yield),
            last-distribution: block-height
          }))
      
      (var-set total-dimensional-revenue (+ (var-get total-dimensional-revenue) total-yield))
      
      ;; Route token holder portion through revenue distributor
      (if (> token-holder-portion u0)
        (match (var-get revenue-distributor)
          distributor-contract
            (begin
              ;; Transfer tokens to revenue distributor
              (try! (contract-call? reward-token transfer token-holder-portion tx-sender distributor-contract none))
              ;; Report revenue for distribution
              (try! (contract-call? distributor-contract report-revenue 
                     (as-contract tx-sender) 
                     token-holder-portion 
                     reward-token))
              (var-set total-distributed-revenue (+ (var-get total-distributed-revenue) token-holder-portion))
              true)
          false)
        true)
      
      ;; Notify token coordinator of dimensional activity
      (match (var-get token-coordinator)
        coordinator-contract
          (match (contract-call? coordinator-contract on-dimensional-yield 
                   dim-id 
                   total-yield 
                   token-holder-portion)
            result result
            false)
        true)
      
      (ok {
        total-yield: total-yield,
        token-holder-portion: token-holder-portion,
        treasury-portion: treasury-portion,
        reserve-portion: reserve-portion
      }))))

;; Get dimensional metrics for revenue calculations
(define-public (get-dimension-metrics (dim-id uint))
  (match (var-get dim-metrics-contract)
    metrics-contract
      (match (contract-call? metrics-contract get-metric dim-id u0) ;; TVL metric
        tvl-metric
          (match (contract-call? metrics-contract get-metric dim-id u1) ;; Utilization metric
            util-metric
              (ok {
                tvl: (get value tvl-metric),
                utilization: (get value util-metric),
                last-updated: (get last-updated tvl-metric)
              })
            (err ERR_CONTRACT_NOT_SET))
        (err ERR_CONTRACT_NOT_SET))
    (err ERR_CONTRACT_NOT_SET)))

;; Calculate optimal dimensional revenue distribution based on metrics
(define-public (calculate-dimensional-allocation (total-budget uint))
  (let ((total-tvl u0) ;; Will be calculated by summing all dimensions
        (allocations (list)))
    ;; This would iterate through all registered dimensions
    ;; For now, simplified implementation
    (ok { total-budget: total-budget, allocations: allocations })))

;; --- Integration with Tokenized Bonds ---

;; Called when bond coupons are paid
(define-public (report-bond-coupon-payment
    (bond-contract principal)
    (coupon-amount uint)
    (payment-token <sip-010-ft-trait>)
    (bond-holders-count uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED)) ;; Only owner can report for now
    (asserts! (> coupon-amount u0) (err ERR_INVALID_AMOUNT))
    
    ;; Route a portion of bond coupons to token holders
    (let ((token-holder-portion (/ (* coupon-amount (var-get dimensional-revenue-share)) u10000)))
      (if (> token-holder-portion u0)
        (match (var-get revenue-distributor)
          distributor-contract
            (begin
              (try! (contract-call? payment-token transfer token-holder-portion tx-sender distributor-contract none))
              (try! (contract-call? distributor-contract report-revenue 
                     (as-contract tx-sender)
                     token-holder-portion
                     payment-token))
              true)
          false)
        true)
      
      (ok { coupon-amount: coupon-amount, token-holder-portion: token-holder-portion }))))

;; --- Read-Only Functions ---

(define-read-only (get-dimension-revenue-info (dim-id uint))
  (default-to { total-collected: u0, last-distribution: u0 }
              (map-get? dimension-revenue { dim-id: dim-id })))

(define-read-only (get-revenue-configuration)
  {
    dimensional-share: (var-get dimensional-revenue-share),
    treasury-share: (var-get treasury-share),
    reserve-share: (var-get reserve-share),
    total-collected: (var-get total-dimensional-revenue),
    total-distributed: (var-get total-distributed-revenue)
  })

(define-read-only (get-system-contracts)
  {
    revenue-distributor: (var-get revenue-distributor),
    token-coordinator: (var-get token-coordinator),
    protocol-monitor: (var-get protocol-monitor),
    dim-yield-contract: (var-get dim-yield-contract),
    dim-registry-contract: (var-get dim-registry-contract),
    dim-metrics-contract: (var-get dim-metrics-contract)
  })

(define-read-only (calculate-expected-dimensional-yield (dim-id uint) (stake-amount uint) (lock-period uint))
  ;; Calculate expected yield based on current metrics
  (match (get-dimension-metrics dim-id)
    metrics
      (let ((base-rate u500) ;; 5% base rate
            (utilization-factor (get utilization metrics))
            (adjusted-rate (+ base-rate (/ (* utilization-factor u200) u10000)))) ;; Up to 2% utilization bonus
        (ok (/ (* stake-amount (* adjusted-rate lock-period)) u525600000))) ;; Annualized
    error (err error)))

;; Emergency pause dimensional integration
(define-public (pause-dimensional-integration)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Implementation would disable revenue routing
    (ok true)))





