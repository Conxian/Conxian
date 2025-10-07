(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
;; tokenized-bond-adapter.clar
;; Integration adapter for tokenized bonds to connect with enhanced tokenomics system
;; Routes bond proceeds and coupon payments through revenue distribution system


;; --- Constants ---
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PRECISION u100000000)

;; --- Errors ---
(define-constant ERR_UNAUTHORIZED u850)
(define-constant ERR_INVALID_AMOUNT u851)
(define-constant ERR_BOND_NOT_FOUND u852)
(define-constant ERR_SYSTEM_PAUSED u853)
(define-constant ERR_CONTRACT_NOT_SET u854)

;; --- Storage ---
(define-data-var contract-owner principal CONTRACT_OWNER)
(define-data-var revenue-distributor (optional principal) none)
(define-data-var token-coordinator (optional principal) none)
(define-data-var protocol-monitor (optional principal) none)

;; Bond revenue configuration
(define-data-var bond-revenue-share uint u1500) ;; 15% of bond proceeds to token holders
(define-data-var coupon-revenue-share uint u1000) ;; 10% of coupon payments to token holders

;; Bond tracking
(define-map registered-bonds principal bool)
(define-map bond-revenue-stats 
  principal 
  { 
    total-proceeds: uint, 
    total-coupons: uint, 
    distributed-to-holders: uint,
    last-payment: uint
  })

(define-data-var total-bond-revenue uint u0)
(define-data-var total-distributed-bond-revenue uint u0)

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

(define-public (set-bond-revenue-shares
    (bond-proceeds-share uint)
    (coupon-share uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (asserts! (<= bond-proceeds-share u5000) (err ERR_INVALID_AMOUNT)) ;; Max 50%
    (asserts! (<= coupon-share u5000) (err ERR_INVALID_AMOUNT)) ;; Max 50%
    (var-set bond-revenue-share bond-proceeds-share)
    (var-set coupon-revenue-share coupon-share)
    (ok true)))

(define-public (register-bond (bond-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    (map-set registered-bonds bond-contract true)
    (map-set bond-revenue-stats bond-contract 
      { total-proceeds: u0, total-coupons: u0, distributed-to-holders: u0, last-payment: u0 })
    (ok true)))

;; --- Bond Integration Functions ---

;; Called when bond is issued - distribute portion of proceeds to token holders
(define-public (report-bond-issuance
    (bond-contract principal)
    (face-value uint)
    (proceeds uint)
    (payment-token principal))
  (begin
    (asserts! (default-to false (map-get? registered-bonds bond-contract)) (err ERR_BOND_NOT_FOUND))
    (asserts! (> proceeds u0) (err ERR_INVALID_AMOUNT))
    
    ;; Check system operational status
    (match (var-get protocol-monitor)
      monitor-contract
        (asserts! (unwrap! (contract-call? monitor-contract is-system-operational) (err ERR_SYSTEM_PAUSED)) (err ERR_SYSTEM_PAUSED))
      true)
    
    ;; Calculate token holder portion
    (let ((token-holder-portion (/ (* proceeds (var-get bond-revenue-share)) u10000)))
      
      ;; Update bond stats
      (let ((current-stats (unwrap! (map-get? bond-revenue-stats bond-contract) (err ERR_BOND_NOT_FOUND))))
        (map-set bond-revenue-stats bond-contract
          (merge current-stats {
            total-proceeds: (+ (get total-proceeds current-stats) proceeds),
            distributed-to-holders: (+ (get distributed-to-holders current-stats) token-holder-portion),
            last-payment: block-height
          })))
      
      (var-set total-bond-revenue (+ (var-get total-bond-revenue) proceeds))
      
      ;; Distribute to token holders if portion > 0
      (if (> token-holder-portion u0)
        (match (var-get revenue-distributor)
          distributor-contract
            (begin
              ;; Transfer from bond contract to revenue distributor
              (try! (contract-call? payment-token transfer token-holder-portion bond-contract distributor-contract none))
              ;; Report revenue for distribution
              (try! (contract-call? distributor-contract report-revenue 
                     bond-contract
                     token-holder-portion
                     payment-token))
              (var-set total-distributed-bond-revenue (+ (var-get total-distributed-bond-revenue) token-holder-portion))
              true)
          false)
        true)
      
      ;; Notify token coordinator
      (match (var-get token-coordinator)
        coordinator-contract
          (match (contract-call? coordinator-contract on-bond-issuance
                   bond-contract
                   face-value
                   proceeds
                   token-holder-portion)
            result result
            false)
        true)
      
      (ok {
        proceeds: proceeds,
        token-holder-portion: token-holder-portion,
        remaining-proceeds: (- proceeds token-holder-portion)
      }))))

;; Called when coupon payments are made
(define-public (report-coupon-payment
    (bond-contract principal)
    (coupon-amount uint)
    (payment-token principal)
    (bondholders-count uint))
  (begin
    (asserts! (default-to false (map-get? registered-bonds bond-contract)) (err ERR_BOND_NOT_FOUND))
    (asserts! (> coupon-amount u0) (err ERR_INVALID_AMOUNT))
    
    ;; Check system operational status
    (match (var-get protocol-monitor)
      monitor-contract
        (asserts! (unwrap! (contract-call? monitor-contract is-system-operational) (err ERR_SYSTEM_PAUSED)) (err ERR_SYSTEM_PAUSED))
      true)
    
    ;; Calculate token holder portion
    (let ((token-holder-portion (/ (* coupon-amount (var-get coupon-revenue-share)) u10000)))
      
      ;; Update bond stats
      (let ((current-stats (unwrap! (map-get? bond-revenue-stats bond-contract) (err ERR_BOND_NOT_FOUND))))
        (map-set bond-revenue-stats bond-contract
          (merge current-stats {
            total-coupons: (+ (get total-coupons current-stats) coupon-amount),
            distributed-to-holders: (+ (get distributed-to-holders current-stats) token-holder-portion),
            last-payment: block-height
          })))
      
      ;; Distribute to token holders if portion > 0
      (if (> token-holder-portion u0)
        (match (var-get revenue-distributor)
          distributor-contract
            (begin
              ;; Transfer from bond contract to revenue distributor  
              (try! (contract-call? payment-token transfer token-holder-portion bond-contract distributor-contract none))
              ;; Report revenue for distribution
              (try! (contract-call? distributor-contract report-revenue
                     bond-contract
                     token-holder-portion
                     payment-token))
              (var-set total-distributed-bond-revenue (+ (var-get total-distributed-bond-revenue) token-holder-portion))
              true)
          false)
        true)
      
      ;; Notify token coordinator
      (match (var-get token-coordinator)
        coordinator-contract
          (match (contract-call? coordinator-contract on-coupon-payment
                   bond-contract
                   coupon-amount
                   token-holder-portion
                   bondholders-count)
            result result
            false)
        true)
      
      (ok {
        coupon-amount: coupon-amount,
        token-holder-portion: token-holder-portion,
        bondholders-count: bondholders-count
      }))))

;; Called when bond matures and principal is repaid
(define-public (report-bond-maturity
    (bond-contract principal)
    (principal-amount uint)
    (payment-token <sip-010-ft-trait>))
  (begin
    (asserts! (default-to false (map-get? registered-bonds bond-contract)) (err ERR_BOND_NOT_FOUND))
    (asserts! (> principal-amount u0) (err ERR_INVALID_AMOUNT))
    
    ;; Check system operational status
    (match (var-get protocol-monitor)
      monitor-contract
        (asserts! (unwrap! (contract-call? monitor-contract is-system-operational) (err ERR_SYSTEM_PAUSED)) (err ERR_SYSTEM_PAUSED))
      true)
    
    ;; No direct distribution on maturity, but notify coordinator
    (match (var-get token-coordinator)
      coordinator-contract
        (match (contract-call? coordinator-contract on-bond-maturity
                 bond-contract
                 principal-amount)
          result result
          false)
      true)
    
    ;; Unregister bond as its now complete
    (map-delete registered-bonds bond-contract)
    
    (ok { principal-amount: principal-amount })))

;; --- Bond Analytics ---

;; Calculate bond yield impact on token holders
(define-read-only (calculate-bond-holder-yield
    (bond-contract principal)
    (face-value uint)
    (coupon-rate uint)
    (frequency uint)
    (maturity-blocks uint))
  (let ((annual-coupon (/ (* face-value coupon-rate) u10000))
        (total-coupons (/ maturity-blocks frequency))
        (total-coupon-payments (* annual-coupon total-coupons))
        (token-holder-coupon-share (/ (* total-coupon-payments (var-get coupon-revenue-share)) u10000))
        (token-holder-principal-share (/ (* face-value (var-get bond-revenue-share)) u10000)))
    {
      total-token-holder-revenue: (+ token-holder-coupon-share token-holder-principal-share),
      coupon-share: token-holder-coupon-share,
      principal-share: token-holder-principal-share,
      estimated-blocks: maturity-blocks
    }))

;; --- Read-Only Functions ---

(define-read-only (get-bond-stats (bond-contract principal))
  (map-get? bond-revenue-stats bond-contract))

(define-read-only (is-registered-bond (bond-contract principal))
  (default-to false (map-get? registered-bonds bond-contract)))

(define-read-only (get-bond-revenue-configuration)
  {
    bond-revenue-share: (var-get bond-revenue-share),
    coupon-revenue-share: (var-get coupon-revenue-share),
    total-bond-revenue: (var-get total-bond-revenue),
    total-distributed: (var-get total-distributed-bond-revenue)
  })

(define-read-only (get-system-contracts)
  {
    revenue-distributor: (var-get revenue-distributor),
    token-coordinator: (var-get token-coordinator),
    protocol-monitor: (var-get protocol-monitor)
  })

;; Emergency functions
(define-public (pause-bond-integration)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Implementation would disable bond revenue routing
    (ok true)))

(define-public (emergency-withdraw-bond-funds (bond-contract principal) (amount uint) (token <sip-010-ft-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR_UNAUTHORIZED))
    ;; Emergency withdrawal function
    (try! (as-contract (contract-call? token transfer amount (as-contract tx-sender) tx-sender none)))
    (ok amount)))






