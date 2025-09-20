;; bond-issuance-system.clar
;; Tokenized bond system for backing large enterprise loans
;; Issues ERC-1155 style bonds representing shares in loan portfolios

(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.sip-010-ft-trait)
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u8001))
(define-constant ERR_BOND_NOT_FOUND (err u8002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u8003))
(define-constant ERR_BOND_MATURED (err u8004))
(define-constant ERR_INVALID_AMOUNT (err u8005))
(define-constant ERR_TRANSFER_FAILED (err u8006))
(define-constant ERR_BOND_NOT_MATURED (err u8007))

;; Token constants
(define-fungible-token conxian-bond)
(define-constant TOKEN_NAME "Conxian Enterprise Bonds")
(define-constant TOKEN_SYMBOL "CXB")
(define-constant DECIMALS u8)
(define-constant TOKEN_DECIMALS u6) ;; 6 decimals for bonds

;; Bond series tracking
(define-map bond-series
  uint ;; series-id
  {
    total-supply: uint,
    maturity-block: uint,
    yield-rate: uint, ;; basis points annually
    backing-loans: (list 20 uint),
    total-backing-amount: uint,
    series-name: (string-ascii 50),
    status: (string-ascii 20), ;; "active", "matured", "defaulted"
    creation-block: uint,
    last-yield-payment: uint
  })

(define-map bond-holder-positions
  {holder: principal, series: uint}
  {
    balance: uint,
    total-yield-earned: uint,
    last-claim-block: uint
  })

(define-map series-yield-pool
  uint ;; series-id
  uint ;; accumulated yield available for distribution
)

;; System state
(define-data-var contract-owner principal tx-sender)
(define-data-var next-series-id uint u1)
(define-data-var system-paused bool false)
(define-data-var total-bonds-issued uint u0)
(define-data-var authorized-issuers (list 10 principal) (list tx-sender))

;; Integration contracts
(define-data-var enterprise-loan-manager (optional principal) none)
(define-data-var yield-distribution-engine (optional principal) none)

;; === SIP-010 IMPLEMENTATION ===
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  ;; For now, bonds are non-transferable until secondary market is implemented
  (err u9999))

(define-public (get-name)
  (ok TOKEN_NAME))

(define-public (get-symbol) 
  (ok TOKEN_SYMBOL))

(define-public (get-decimals)
  (ok TOKEN_DECIMALS))

(define-public (get-balance (who principal))
  ;; Return total bond balance across all series
  (ok (fold + (map get-series-balance (get-user-series who)) u0)))

(define-public (get-total-supply)
  (ok (var-get total-bonds-issued)))

(define-public (get-token-uri)
  (ok (some u"https://conxian.finance/bonds/metadata")))

(define-public (set-token-uri (uri (optional (string-utf8 256))))
  (ok true))

;; === ADMIN FUNCTIONS ===
(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner)))

(define-private (is-authorized-issuer)
  (is-some (index-of (var-get authorized-issuers) tx-sender)))

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

(define-public (add-authorized-issuer (issuer principal))
  (let ((current-issuers (var-get authorized-issuers)))
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (asserts! (is-none (index-of current-issuers issuer)) ERR_UNAUTHORIZED)
    (var-set authorized-issuers (unwrap! (as-max-len? (append current-issuers issuer) u10) ERR_UNAUTHORIZED))
    (ok true)))

(define-public (set-enterprise-loan-manager (manager principal))
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set enterprise-loan-manager (some manager))
    (ok true)))

;; === BOND ISSUANCE ===
(define-public (create-bond-series 
  (series-name (string-ascii 50))
  (total-supply uint) 
  (maturity-blocks uint)
  (yield-rate uint)
  (backing-loan-ids (list 20 uint))
  (total-backing-amount uint))
  
  (let ((series-id (var-get next-series-id))
        (maturity-block (+ block-height maturity-blocks)))
    
    ;; Validations
    (asserts! (or (is-contract-owner) (is-authorized-issuer)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
    (asserts! (> total-supply u0) ERR_INVALID_AMOUNT)
    (asserts! (> maturity-blocks u0) ERR_INVALID_AMOUNT)
    (asserts! (> total-backing-amount u0) ERR_INVALID_AMOUNT)
    
    ;; Create bond series
    (map-set bond-series series-id
      {
        total-supply: total-supply,
        maturity-block: maturity-block,
        yield-rate: yield-rate,
        backing-loans: backing-loan-ids,
        total-backing-amount: total-backing-amount,
        series-name: series-name,
        status: "active",
        creation-block: block-height,
        last-yield-payment: block-height
      })
    
    ;; Initialize yield pool
    (map-set series-yield-pool series-id u0)
    
    ;; Update counters
    (var-set next-series-id (+ series-id u1))
    (var-set total-bonds-issued (+ (var-get total-bonds-issued) total-supply))
    
    ;; Mint bonds to contract for distribution
    (try! (ft-mint? conxian-bond total-supply (as-contract tx-sender)))
    
    (print (tuple (event "bond-series-created") (series-id series-id) (name series-name)
                  (supply total-supply) (yield-rate yield-rate) (maturity-block maturity-block)))
    
    (ok series-id)))

;; === BOND PURCHASE ===
(define-public (purchase-bonds (series-id uint) (amount uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND))
        (buyer tx-sender))
    
    ;; Validations
    (asserts! (not (var-get system-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status series) "active") ERR_BOND_MATURED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (<= block-height (get maturity-block series)) ERR_BOND_MATURED)
    
  ;; Check available supply
  (let ((contract-balance (ft-get-balance conxian-bond (as-contract tx-sender))))
      (asserts! (>= contract-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Transfer bonds to buyer
      (try! (as-contract (ft-transfer? conxian-bond amount tx-sender buyer)))
      
      ;; Update holder position
      (let ((current-position (default-to 
                                {balance: u0, total-yield-earned: u0, last-claim-block: block-height}
                                (map-get? bond-holder-positions {holder: buyer, series: series-id}))))
        (map-set bond-holder-positions {holder: buyer, series: series-id}
          (merge current-position {balance: (+ (get balance current-position) amount)})))
      
      ;; TODO: Handle payment from buyer (integrate with payment system)
      ;; (try! (contract-call? payment-token transfer bond-price buyer (as-contract tx-sender) none))
      
      (print (tuple (event "bonds-purchased") (buyer buyer) (series-id series-id) (amount amount)))
      
      (ok amount))))

;; === YIELD DISTRIBUTION ===
(define-public (distribute-yield (series-id uint) (yield-amount uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND)))
    
    ;; Only authorized contracts can distribute yield
    (asserts! (or (is-contract-owner) 
                  (is-some (index-of (var-get authorized-issuers) tx-sender))
                  (is-eq (some tx-sender) (var-get enterprise-loan-manager))) ERR_UNAUTHORIZED)
    
    ;; Add yield to pool
    (let ((current-pool (default-to u0 (map-get? series-yield-pool series-id))))
      (map-set series-yield-pool series-id (+ current-pool yield-amount))
      
      ;; Update series last yield payment
      (map-set bond-series series-id
        (merge series {last-yield-payment: block-height}))
      
      (print (tuple (event "yield-distributed") (series-id series-id) (amount yield-amount)))
      
      (ok true))))

;; === YIELD CLAIMING ===
(define-public (claim-yield (series-id uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND))
        (claimer tx-sender)
        (position (unwrap! (map-get? bond-holder-positions {holder: claimer, series: series-id}) ERR_INSUFFICIENT_BALANCE)))
    
    ;; Calculate yield due
    (let ((holder-balance (get balance position))
          (total-supply (get total-supply series))
          (available-yield (default-to u0 (map-get? series-yield-pool series-id)))
          (holder-share (/ (* available-yield holder-balance) total-supply))
          (blocks-since-claim (- block-height (get last-claim-block position))))
      
      (asserts! (> holder-share u0) ERR_INVALID_AMOUNT)
      
      ;; Update yield pool
      (map-set series-yield-pool series-id (- available-yield holder-share))
      
      ;; Update holder position
      (map-set bond-holder-positions {holder: claimer, series: series-id}
        (merge position 
               {total-yield-earned: (+ (get total-yield-earned position) holder-share),
                last-claim-block: block-height}))
      
      ;; TODO: Transfer yield to holder
      ;; (try! (as-contract (contract-call? yield-token transfer holder-share tx-sender claimer none)))
      
      (print (tuple (event "yield-claimed") (holder claimer) (series-id series-id) (amount holder-share)))
      
      (ok holder-share))))

;; === BOND MATURITY ===
(define-public (mature-bonds (series-id uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND)))
    
    ;; Only after maturity date
    (asserts! (>= block-height (get maturity-block series)) ERR_BOND_NOT_MATURED)
    (asserts! (is-eq (get status series) "active") ERR_BOND_MATURED)
    
    ;; Mark series as matured
    (map-set bond-series series-id
      (merge series {status: "matured"}))
    
    ;; TODO: Handle bond redemption - return principal to holders
    ;; This would involve liquidating backing loans and distributing proceeds
    
    (print (tuple (event "bond-series-matured") (series-id series-id)))
    
    (ok true)))

(define-public (redeem-mature-bonds (series-id uint) (amount uint))
  (let ((series (unwrap! (map-get? bond-series series-id) ERR_BOND_NOT_FOUND))
        (holder tx-sender)
        (position (unwrap! (map-get? bond-holder-positions {holder: holder, series: series-id}) ERR_INSUFFICIENT_BALANCE)))
    
    ;; Validations
    (asserts! (is-eq (get status series) "matured") ERR_BOND_NOT_MATURED)
    (asserts! (>= (get balance position) amount) ERR_INSUFFICIENT_BALANCE)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Calculate redemption value
    (let ((total-backing (get total-backing-amount series))
          (total-supply (get total-supply series))
          (redemption-value (/ (* amount total-backing) total-supply)))
      
      ;; Burn bonds
      (try! (ft-burn? conxian-bond amount holder))
      
      ;; Update position
      (map-set bond-holder-positions {holder: holder, series: series-id}
        (merge position {balance: (- (get balance position) amount)}))
      
      ;; TODO: Transfer redemption value to holder
      ;; (try! (as-contract (contract-call? backing-asset transfer redemption-value tx-sender holder none)))
      
      (print (tuple (event "bonds-redeemed") (holder holder) (series-id series-id) 
                    (amount amount) (value redemption-value)))
      
      (ok redemption-value))))

;; === UTILITY FUNCTIONS ===
(define-private (get-series-balance (series-id uint))
  (match (map-get? bond-holder-positions {holder: tx-sender, series: series-id})
    position (get balance position)
    u0))

(define-private (get-user-series (user principal))
  ;; This is a simplified implementation - in production would need better series tracking
  (list u1 u2 u3 u4 u5)) ;; Return all possible series IDs

;; === READ-ONLY FUNCTIONS ===
(define-read-only (get-bond-series (series-id uint))
  (map-get? bond-series series-id))

(define-read-only (get-holder-position (holder principal) (series-id uint))
  (map-get? bond-holder-positions {holder: holder, series: series-id}))

(define-read-only (get-yield-pool (series-id uint))
  (map-get? series-yield-pool series-id))

(define-read-only (calculate-yield-due (holder principal) (series-id uint))
  (match (map-get? bond-holder-positions {holder: holder, series: series-id})
    position
      (match (map-get? bond-series series-id)
        series
          (let ((holder-balance (get balance position))
                (total-supply (get total-supply series))
                (available-yield (default-to u0 (map-get? series-yield-pool series-id))))
            (ok (/ (* available-yield holder-balance) total-supply)))
        ERR_BOND_NOT_FOUND)
    ERR_INSUFFICIENT_BALANCE))

(define-read-only (get-bond-price (series-id uint))
  ;; Simple pricing model - in production would be more sophisticated
  (match (map-get? bond-series series-id)
    series
      (let ((time-to-maturity (- (get maturity-block series) block-height))
            (yield-rate (get yield-rate series))
            (base-price u1000000)) ;; 1.0 with 6 decimals
        (ok base-price)) ;; Simplified - actual pricing would consider time value
    ERR_BOND_NOT_FOUND))

(define-read-only (get-series-stats (series-id uint))
  (match (map-get? bond-series series-id)
    series
      (ok (tuple
        (series-id series-id)
        (name (get series-name series))
        (total-supply (get total-supply series))
        (status (get status series))
        (yield-rate (get yield-rate series))
        (maturity-block (get maturity-block series))
        (backing-amount (get total-backing-amount series))
        (available-yield (default-to u0 (map-get? series-yield-pool series-id)))))
    ERR_BOND_NOT_FOUND))

(define-read-only (get-system-overview)
  (ok (tuple
    (total-series-issued (- (var-get next-series-id) u1))
    (total-bonds-outstanding (var-get total-bonds-issued))
    (system-paused (var-get system-paused))
    (authorized-issuers-count (len (var-get authorized-issuers))))))

;; === INTEGRATION FUNCTIONS ===
(define-public (notify-loan-payment (loan-id uint) (payment-amount uint))
  ;; Called by enterprise loan manager when loan payments are made
  (let ((caller tx-sender))
    (asserts! (is-eq (some caller) (var-get enterprise-loan-manager)) ERR_UNAUTHORIZED)
    
    ;; Find bond series backed by this loan and distribute yield
    ;; This is simplified - would need better loan-to-series mapping
    (print (tuple (event "loan-payment-notification") (loan-id loan-id) (amount payment-amount)))
    
    (ok true)))

;; Emergency functions
(define-public (emergency-pause)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set system-paused true)
    (print (tuple (event "emergency-pause") (block block-height)))
    (ok true)))

(define-public (emergency-unpause)
  (begin
    (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
    (var-set system-paused false)
    (print (tuple (event "emergency-unpause") (block block-height)))
    (ok true)))





