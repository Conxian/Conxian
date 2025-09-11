;; enterprise-loan-manager.clar
;; Enterprise-grade loan management system with bond issuance for large loans
;; Supports institutional borrowing, risk-based pricing, and automated bond creation

(use-trait sip10 .sip-010-trait.sip-010-trait)
(use-trait lending-trait .lending-system-trait.lending-system-trait)

;; Import mathematical libraries for enterprise calculations (removed unresolved trait import)
;; (use-trait math-precision .precision-calculator.precision-calculator-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u7001))
(define-constant ERR_LOAN_NOT_FOUND (err u7002))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u7003))
(define-constant ERR_LOAN_EXPIRED (err u7004))
(define-constant ERR_INVALID_AMOUNT (err u7005))
(define-constant ERR_CREDIT_RATING_TOO_LOW (err u7006))
(define-constant ERR_BOND_CREATION_FAILED (err u7007))
(define-constant ERR_LIQUIDITY_SHORTAGE (err u7008))
(define-constant ERR_LOAN_ALREADY_EXISTS (err u7009))
(define-constant ERR_INVALID_TERMS (err u7010))

;; Loan size thresholds for enterprise features
(define-constant ENTERPRISE_LOAN_THRESHOLD u50000000000000000000000) ;; 50,000 tokens
(define-constant BOND_ISSUANCE_THRESHOLD u100000000000000000000000) ;; 100,000 tokens
(define-constant MAX_LOAN_AMOUNT u10000000000000000000000000) ;; 10M tokens

;; Risk and pricing constants
(define-constant MAX_LTV_RATIO u8000) ;; 80% max loan-to-value
(define-constant MIN_CREDIT_SCORE u600) ;; Minimum credit rating
(define-constant BASE_INTEREST_RATE u500) ;; 5% base rate
(define-constant BOND_YIELD_PREMIUM u200) ;; 2% additional yield for bond holders

;; Time constants
(define-constant BLOCKS_PER_YEAR u52560) ;; Approximate blocks per year
(define-constant MAX_LOAN_DURATION (* BLOCKS_PER_YEAR u10)) ;; 10 years max

;; Precision
(define-constant PRECISION u1000000000000000000) ;; 18 decimals
(define-constant BASIS_POINTS u10000)

;; Data structures
(define-map enterprise-loans
  uint ;; loan-id
  {
    borrower: principal,
    principal-amount: uint,
    collateral-amount: uint,
    collateral-asset: principal,
    loan-asset: principal,
    interest-rate: uint, ;; basis points
    creation-block: uint,
    maturity-block: uint,
    status: (string-ascii 20), ;; "active", "repaid", "liquidated", "defaulted"
    credit-score: uint,
    bond-issued: bool,
    bond-token-id: (optional uint),
    total-interest-paid: uint,
    last-payment-block: uint
  })

(define-map borrower-credit-profiles
  principal ;; borrower
  {
    credit-score: uint,
    total-borrowed: uint,
    successful-repayments: uint,
    defaults: uint,
    last-updated: uint
  })

(define-map bond-backing-loans
  uint ;; bond-token-id
  {
    backing-loan-ids: (list 20 uint),
    total-principal: uint,
    yield-rate: uint,
    maturity-block: uint,
    bond-holders-count: uint
  })

;; System state
(define-data-var next-loan-id uint u1)
(define-data-var next-bond-id uint u1)
(define-data-var admin principal tx-sender)
(define-data-var system-paused bool false)
(define-data-var total-active-loans uint u0)
(define-data-var total-loan-volume uint u0)

;; Liquidity pool for enterprise loans
(define-data-var liquidity-pool-balance uint u0)
(define-data-var emergency-reserve uint u0)

;; Risk management
(define-data-var global-utilization-cap uint u8000) ;; 80% of available liquidity
(define-data-var risk-assessment-enabled bool true)

;; Bond system integration
(define-data-var bond-contract (optional principal) none)
(define-data-var yield-distribution-contract (optional principal) none)

;; === ADMIN FUNCTIONS ===
(define-private (is-admin)
  (is-eq tx-sender (var-get admin)))

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-system-pause (pause bool))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set system-paused pause)
    (print (tuple (event "enterprise-system-pause") (paused pause)))
    (ok true)))

(define-public (set-bond-contract (bond-principal principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set bond-contract (some bond-principal))
    (ok true)))

(define-public (set-yield-distribution-contract (yield-principal principal))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set yield-distribution-contract (some yield-principal))
    (ok true)))

;; === CREDIT ASSESSMENT ===
(define-public (update-credit-score (borrower principal) (new-score uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (<= new-score u1000) ERR_INVALID_AMOUNT) ;; Max score 1000
    
    (let ((current-profile (default-to 
                             {credit-score: u700, total-borrowed: u0, successful-repayments: u0, 
                              defaults: u0, last-updated: u0}
                             (map-get? borrower-credit-profiles borrower))))
      (map-set borrower-credit-profiles borrower
        (merge current-profile 
               {credit-score: new-score, last-updated: block-height}))
      (ok new-score))))

(define-private (assess-credit-risk (borrower principal) (amount uint))
  (let ((profile (default-to 
                   {credit-score: u700, total-borrowed: u0, successful-repayments: u0, 
                    defaults: u0, last-updated: u0}
                   (map-get? borrower-credit-profiles borrower)))
        (credit-score (get credit-score profile))
        (default-rate (get defaults profile))
        (total-borrowed (get total-borrowed profile)))
    
    ;; Risk-based interest rate calculation
    (let ((base-rate BASE_INTEREST_RATE)
          (credit-adjustment (if (< credit-score u750) u200 u0))
          (volume-adjustment (if (> amount ENTERPRISE_LOAN_THRESHOLD) u100 u0))
          (default-penalty (* default-rate u50)))
      
      (+ base-rate credit-adjustment volume-adjustment default-penalty))))

;; === ENTERPRISE LOAN CREATION ===
(define-public (create-enterprise-loan 
  (principal-amount uint)
  (collateral-amount uint)
  (collateral-asset principal)
  (loan-asset principal)
  (duration-blocks uint))
  
  (let ((loan-id (var-get next-loan-id))
        (borrower tx-sender)
        (credit-score (get credit-score 
                        (default-to {credit-score: u700, total-borrowed: u0, successful-repayments: u0, 
                                     defaults: u0, last-updated: u0}
                                    (map-get? borrower-credit-profiles borrower))))
        (interest-rate (assess-credit-risk borrower principal-amount))
        (ltv-ratio (/ (* principal-amount BASIS_POINTS) collateral-amount))
        (maturity-block (+ block-height duration-blocks)))
    
    ;; Validations
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
    (asserts! (> principal-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> collateral-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= duration-blocks MAX_LOAN_DURATION) ERR_INVALID_TERMS)
    (asserts! (>= credit-score MIN_CREDIT_SCORE) ERR_CREDIT_RATING_TOO_LOW)
    (asserts! (<= ltv-ratio MAX_LTV_RATIO) ERR_INSUFFICIENT_COLLATERAL)
    (asserts! (<= principal-amount MAX_LOAN_AMOUNT) ERR_INVALID_AMOUNT)
    
    ;; Check liquidity availability
    (asserts! (>= (var-get liquidity-pool-balance) principal-amount) ERR_LIQUIDITY_SHORTAGE)
    
    ;; Create loan record
    (map-set enterprise-loans loan-id
      {
        borrower: borrower,
        principal-amount: principal-amount,
        collateral-amount: collateral-amount,
        collateral-asset: collateral-asset,
        loan-asset: loan-asset,
        interest-rate: interest-rate,
        creation-block: block-height,
        maturity-block: maturity-block,
        status: "active",
        credit-score: credit-score,
        bond-issued: false,
        bond-token-id: none,
        total-interest-paid: u0,
        last-payment-block: block-height
      })
    
    ;; Update system state
    (var-set next-loan-id (+ loan-id u1))
    (var-set total-active-loans (+ (var-get total-active-loans) u1))
    (var-set total-loan-volume (+ (var-get total-loan-volume) principal-amount))
    (var-set liquidity-pool-balance (- (var-get liquidity-pool-balance) principal-amount))
    
    ;; Issue bond if loan qualifies
    (let ((bond-result 
            (if (>= principal-amount BOND_ISSUANCE_THRESHOLD)
              (unwrap-panic (create-backing-bond loan-id principal-amount interest-rate maturity-block))
              none)))
      
      ;; Transfer collateral from borrower
      ;; (try! (contract-call? collateral-asset transfer collateral-amount borrower (as-contract tx-sender) none))
      
      ;; Transfer loan amount to borrower  
      ;; (try! (as-contract (contract-call? loan-asset transfer principal-amount tx-sender borrower none)))
      
      ;; Update borrower credit profile
      (update-borrower-profile borrower principal-amount)
      
      ;; Emit event
      (print (tuple (event "enterprise-loan-created") (loan-id loan-id) (borrower borrower)
                    (amount principal-amount) (interest-rate interest-rate) (bond-issued (is-some bond-result))))
      
      (ok loan-id))))

;; === BOND ISSUANCE FOR LARGE LOANS ===
(define-private (create-backing-bond (loan-id uint) (principal-amount uint) (interest-rate uint) (maturity-block uint))
  (let ((bond-id (var-get next-bond-id))
        (bond-yield (+ interest-rate BOND_YIELD_PREMIUM)))
    
    ;; Create bond backing record
    (map-set bond-backing-loans bond-id
      {
        backing-loan-ids: (list loan-id),
        total-principal: principal-amount,
        yield-rate: bond-yield,
        maturity-block: maturity-block,
        bond-holders-count: u0
      })
    
    ;; Update loan with bond information
    (match (map-get? enterprise-loans loan-id)
      loan-data
        (map-set enterprise-loans loan-id
          (merge loan-data {bond-issued: true, bond-token-id: (some bond-id)}))
      false)
    
    ;; Update bond counter
    (var-set next-bond-id (+ bond-id u1))
    
    ;; Create bond series through the bond issuance system
    ;; TODO: Integrate with existing bond-issuance-system.clar when available
    ;; (match (var-get bond-contract)
    ;;   bond-contract-ref
    ;;     (try! (contract-call? bond-contract-ref create-bond-series
    ;;                         (unwrap-panic (as-max-len? "Enterprise Loan Bond" u50))
    ;;                         principal-amount
    ;;                         (- maturity-block block-height)
    ;;                         bond-yield
    ;;                         (list loan-id)
    ;;                         principal-amount))
    ;;   none)
    
    (print (tuple (event "bond-issued") (bond-id bond-id) (loan-id loan-id) 
                  (principal principal-amount) (yield bond-yield)))
    
    (ok (some bond-id))))

;; === LOAN REPAYMENT ===
(define-public (make-loan-payment (loan-id uint) (payment-amount uint))
  (let ((loan (unwrap! (map-get? enterprise-loans loan-id) ERR_LOAN_NOT_FOUND)))
    
    ;; Validations
    (asserts! (is-eq (get borrower loan) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_FOUND)
    (asserts! (> payment-amount u0) ERR_INVALID_AMOUNT)
    
    ;; Calculate interest due
    (let ((blocks-since-payment (- block-height (get last-payment-block loan)))
          (interest-due (calculate-interest-due (get principal-amount loan) 
                                                (get interest-rate loan) 
                                                blocks-since-payment)))
      (begin
        ;; Update loan with payment
        (map-set enterprise-loans loan-id
          (merge loan 
                 {total-interest-paid: (+ (get total-interest-paid loan) payment-amount),
                  last-payment-block: block-height}))
        
        ;; Distribute yield to bond holders if bond exists  
        (match (get bond-token-id loan)
          bond-id (unwrap-panic (distribute-bond-yield bond-id payment-amount))
          true)
        
        ;; Transfer payment from borrower
        ;; (try! (contract-call? (get loan-asset loan) transfer payment-amount tx-sender (as-contract tx-sender) none))
        
        (print (tuple (event "loan-payment") (loan-id loan-id) (payment payment-amount)))
        (ok true)))))

(define-public (repay-loan-full (loan-id uint))
  (let ((loan (unwrap! (map-get? enterprise-loans loan-id) ERR_LOAN_NOT_FOUND)))
    
    ;; Validations
    (asserts! (is-eq (get borrower loan) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status loan) "active") ERR_LOAN_NOT_FOUND)
    
    ;; Calculate total amount due
    (distribute-bond-yield loan-id u0)
    (let ((principal (get principal-amount loan))
          (blocks-outstanding (- block-height (get creation-block loan)))
          (total-interest (calculate-total-interest principal (get interest-rate loan) blocks-outstanding))
          (total-due (+ principal total-interest))
          (interest-already-paid (get total-interest-paid loan))
          (remaining-due (- total-due interest-already-paid)))
      
      ;; Update loan status
      (map-set enterprise-loans loan-id
        (merge loan {status: "repaid", total-interest-paid: total-interest}))
      
      ;; Release collateral back to borrower
      ;; (try! (as-contract (contract-call? (get collateral-asset loan) 
      ;;                                   transfer (get collateral-amount loan) 
      ;;                                   tx-sender (get borrower loan) none)))
      
      ;; Handle bond maturation if exists
      (match (get bond-token-id loan)
        bond-id (mature-bond bond-id)
        (ok true))
      
      ;; Update system counters
      (var-set total-active-loans (- (var-get total-active-loans) u1))
      (var-set liquidity-pool-balance (+ (var-get liquidity-pool-balance) remaining-due))
      
      ;; Update borrower credit profile positively
      (update-borrower-repayment-history (get borrower loan) true)
      
      (print (tuple (event "loan-repaid") (loan-id loan-id) (total-paid total-due)))
      
      (ok total-due))))

;; === BOND YIELD DISTRIBUTION ===
(define-private (distribute-bond-yield (bond-id uint) (yield-amount uint))
  ;; This would integrate with the yield distribution engine
  ;; For now, just record the distribution
  (match (var-get yield-distribution-contract)
    yield-contract
      ;; This would be the actual call in a real implementation
      ;; (contract-call? yield-contract add-yield-to-pool bond-id yield-amount)
      (ok true)
    (err ERR_BOND_CREATION_FAILED)))

(define-private (mature-bond (bond-id uint))
  ;; Handle bond maturation - return principal to bond holders
  (match (map-get? bond-backing-loans bond-id)
    bond-data
      (begin
        ;; Mark bond as matured
        ;; Bond maturation handled through bond issuance system
        (print (tuple (event "bond-matured") (bond-id bond-id) 
                      (principal (get total-principal bond-data))))
        (ok true))
    (ok false)))

;; === UTILITY FUNCTIONS ===
(define-private (calculate-interest-due (principal uint) (rate uint) (blocks uint))
  (let ((annual-interest (/ (* principal rate) BASIS_POINTS))
        (block-interest (/ annual-interest BLOCKS_PER_YEAR)))
    (* block-interest blocks)))

(define-private (calculate-total-interest (principal uint) (rate uint) (blocks uint))
  ;; Simple interest calculation for now
  (calculate-interest-due principal rate blocks))

(define-private (update-borrower-profile (borrower principal) (loan-amount uint))
  (let ((current-profile (default-to 
                           {credit-score: u700, total-borrowed: u0, successful-repayments: u0, 
                            defaults: u0, last-updated: u0}
                           (map-get? borrower-credit-profiles borrower))))
    (map-set borrower-credit-profiles borrower
      (merge current-profile 
             {total-borrowed: (+ (get total-borrowed current-profile) loan-amount),
              last-updated: block-height}))))

(define-private (update-borrower-repayment-history (borrower principal) (successful bool))
  (let ((current-profile (default-to 
                           {credit-score: u700, total-borrowed: u0, successful-repayments: u0, 
                            defaults: u0, last-updated: u0}
                           (map-get? borrower-credit-profiles borrower))))
    (if successful
      (map-set borrower-credit-profiles borrower
        (merge current-profile 
               {successful-repayments: (+ (get successful-repayments current-profile) u1),
                credit-score: (if (<= (+ (get credit-score current-profile) u10) u1000)
                                 (+ (get credit-score current-profile) u10)
                                 u1000),
                last-updated: block-height}))
      (map-set borrower-credit-profiles borrower
        (merge current-profile 
               {defaults: (+ (get defaults current-profile) u1),
                credit-score: (if (> (get credit-score current-profile) u100) 
                               (- (get credit-score current-profile) u100) 
                               u0),
                last-updated: block-height})))))

;; === LIQUIDITY MANAGEMENT ===
(define-public (add-liquidity (amount uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (var-set liquidity-pool-balance (+ (var-get liquidity-pool-balance) amount))
    (print (tuple (event "liquidity-added") (amount amount)))
    (ok true)))

(define-public (remove-liquidity (amount uint))
  (begin
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    (asserts! (>= (var-get liquidity-pool-balance) amount) ERR_INSUFFICIENT_COLLATERAL)
    (var-set liquidity-pool-balance (- (var-get liquidity-pool-balance) amount))
    (print (tuple (event "liquidity-removed") (amount amount)))
    (ok true)))

;; === READ-ONLY FUNCTIONS ===
(define-read-only (get-loan (loan-id uint))
  (map-get? enterprise-loans loan-id))

(define-read-only (get-borrower-profile (borrower principal))
  (map-get? borrower-credit-profiles borrower))

(define-read-only (get-bond-info (bond-id uint))
  (map-get? bond-backing-loans bond-id))

(define-read-only (get-system-stats)
  (ok (tuple
    (total-active-loans (var-get total-active-loans))
    (total-loan-volume (var-get total-loan-volume))
    (liquidity-available (var-get liquidity-pool-balance))
    (emergency-reserve (var-get emergency-reserve))
    (next-loan-id (var-get next-loan-id))
    (next-bond-id (var-get next-bond-id)))))

(define-read-only (calculate-loan-terms (borrower principal) (amount uint))
  (let ((credit-score (get credit-score 
                        (default-to {credit-score: u700, total-borrowed: u0, successful-repayments: u0, 
                                     defaults: u0, last-updated: u0}
                                    (map-get? borrower-credit-profiles borrower))))
        (interest-rate (assess-credit-risk borrower amount)))
    (ok (tuple
      (eligible (>= credit-score MIN_CREDIT_SCORE))
      (interest-rate interest-rate)
      (max-amount MAX_LOAN_AMOUNT)
      (bond-eligible (>= amount BOND_ISSUANCE_THRESHOLD))))))

(define-read-only (get-loan-payment-due (loan-id uint))
  (match (map-get? enterprise-loans loan-id)
    loan
      (let ((blocks-since-payment (- block-height (get last-payment-block loan)))
            (interest-due (calculate-interest-due (get principal-amount loan) 
                                                  (get interest-rate loan) 
                                                  blocks-since-payment)))
        (ok interest-due))
    ERR_LOAN_NOT_FOUND))

;; === LIQUIDATION SYSTEM ===
(define-public (liquidate-loan (loan-id uint))
  (let ((loan (unwrap! (map-get? enterprise-loans loan-id) ERR_LOAN_NOT_FOUND)))
    
    ;; Only admin or authorized liquidator can liquidate
    (asserts! (is-admin) ERR_UNAUTHORIZED)
    
    ;; Check if loan is past due or under-collateralized
    (asserts! (or (> block-height (get maturity-block loan))
                  ;; Add under-collateralization check here
                  false) ERR_INVALID_TERMS)
    
    ;; Mark loan as liquidated
    (map-set enterprise-loans loan-id
      (merge loan {status: "liquidated"}))
    
    ;; Liquidate collateral
    ;; TODO: Implement automated collateral liquidation
    
    ;; Update borrower credit profile negatively
    (update-borrower-repayment-history (get borrower loan) false)
    
    ;; Update system counters
    (var-set total-active-loans (- (var-get total-active-loans) u1))
    
    (print (tuple (event "loan-liquidated") (loan-id loan-id)))
    
    (ok true)))
