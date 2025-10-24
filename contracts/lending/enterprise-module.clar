;; enterprise-module.clar
;; Institutional lending with custom terms and compliance

(use-trait enterprise .all-traits.enterprise-trait)
(use-trait dimensional-core .all-traits.dimensional-core-trait)
(use-trait risk-oracle .all-traits.risk-oracle-trait)
(impl-trait enterprise)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u9500))
(define-constant ERR_INVALID_TERMS (err u9501))
(define-constant ERR_KYC_REQUIRED (err u9502))
(define-constant ERR_LIMIT_EXCEEDED (err u9503))
(define-constant ERR_TERMS_NOT_MET (err u9504))

;; ===== Data Variables =====
(define-data-var owner principal tx-sender)
(define-data-var kyc-provider principal)
(define-data-var legal-registry principal)

;; Enterprise accounts
(define-map enterprises {id: uint} {
  admin: principal,
  legal-entity: (string-utf8 256),
  risk-tier: uint,
  kyc-verified: bool,
  risk-limit: uint,
  current-exposure: uint,
  terms-hash: (buff 32),
  created-at: uint
})

;; Custom term sheets
(define-map term-sheets {enterprise-id: uint, version: uint} {
  terms: (string-utf8 2048),
  hash: (buff 32),
  effective-from: uint,
  effective-until: (optional uint),
  signed-by: (optional principal)
})

;; Credit facilities
(define-map credit-facilities {enterprise-id: uint} {
  total-limit: uint,
  drawn-amount: uint,
  currency: principal,
  interest-rate: uint,
  last-drawn: uint,
  next-payment: uint,
  status: (string-ascii 20)
})

;; ===== Core Functions =====
(define-public (register-enterprise 
    (admin principal)
    (legal-entity (string-utf8 256))
    (risk-tier uint)
    (kyc-proof (buff 1024))
  )
  (let (
    (enterprise-id (+ (map-len enterprises) u1))
    (current-block block-height)
  )
    ;; Verify KYC
    (asserts! 
      (contract-call? kyc-provider verify-kyc tx-sender kyc-proof) 
      ERR_KYC_REQUIRED
    )
    
    ;; Create enterprise record
    (map-set enterprises {id: enterprise-id} {
      admin: admin,
      legal-entity: legal-entity,
      risk-tier: risk-tier,
      kyc-verified: true,
      risk-limit: (calculate-risk-limit risk-tier),
      current-exposure: u0,
      terms-hash: (sha256 ""),
      created-at: current-block
    })
    
    (ok enterprise-id)
  )
)

(define-public (propose-terms 
    (enterprise-id uint)
    (terms (string-utf8 2048))
    (effective-from uint)
    (effective-until (optional uint))
  )
  (let (
    (enterprise (unwrap! (map-get? enterprises {id: enterprise-id}) (err u0)))
    (current-version (get-term-version enterprise-id))
    (new-version (+ current-version u1))
    (terms-hash (sha256 terms))
  )
    (asserts! (is-eq tx-sender (get enterprise 'admin)) ERR_UNAUTHORIZED)
    (asserts! (> (len terms) u0) ERR_INVALID_TERMS)
    
    ;; Store new term sheet version
    (map-set term-sheets {enterprise-id: enterprise-id, version: new-version} {
      terms: terms,
      hash: terms-hash,
      effective-from: effective-from,
      effective-until: effective-until,
      signed-by: none
    })
    
    (ok {
      'enterprise-id: enterprise-id,
      'version: new-version,
      'terms-hash: terms-hash
    })
  )
)

(define-public (sign-terms 
    (enterprise-id uint)
    (version uint)
    (signature (buff 65))
  )
  (let (
    (enterprise (unwrap! (map-get? enterprises {id: enterprise-id}) (err u0)))
    (terms (unwrap! (map-get? term-sheets {enterprise-id: enterprise-id, version: version}) (err u0)))
  )
    (asserts! (is-eq tx-sender (get enterprise 'admin)) ERR_UNAUTHORIZED)
    
    ;; Verify signature
    (asserts! 
      (contract-call? legal-registry verify-signature 
        (get enterprise 'admin)
        (get terms 'hash)
        signature
      )
      ERR_INVALID_TERMS
    )
    
    ;; Update terms with signature
    (map-set term-sheets {enterprise-id: enterprise-id, version: version} 
      (merge terms {
        'signed-by: (some tx-sender)
      })
    )
    
    ;; Update active terms hash
    (map-set enterprises {id: enterprise-id} 
      (merge enterprise {
        'terms-hash: (get terms 'hash)
      })
    )
    
    (ok true)
  )
)

(define-public (draw-credit 
    (enterprise-id uint)
    (amount uint)
    (collateral (list 10 {asset: principal, amount: uint}))
  )
  (let (
    (enterprise (unwrap! (map-get? enterprises {id: enterprise-id}) (err u0)))
    (facility (unwrap! (map-get? credit-facilities {enterprise-id: enterprise-id}) (err u0)))
    (available-credit (- (get facility 'total-limit) (get facility 'drawn-amount)))
  )
    (asserts! (is-eq tx-sender (get enterprise 'admin)) ERR_UNAUTHORIZED
    (asserts! (>= available-credit amount) ERR_LIMIT_EXCEEDED)
    
    ;; Verify collateral and calculate adjusted amount
    (let (
      (collateral-value (calculate-collateral-value collateral))
      (collateral-ratio (get-enterprise-collateral-ratio enterprise-id))
      (min-collateral (/ (* amount u100) collateral-ratio))
    )
      (asserts! (>= collateral-value min-collateral) ERR_TERMS_NOT_MET)
      
      ;; Update facility state
      (map-set credit-facilities {enterprise-id: enterprise-id}
        (merge facility {
          'drawn-amount: (+ (get facility 'drawn-amount) amount),
          'last-drawn: block-height,
          'next-payment: (+ block-height u20160)  ;; ~7 days at 30s/block
        })
      )
      
      ;; Transfer funds
      (contract-call? (get facility 'currency) transfer amount tx-sender)
      
      (ok true)
    )
  )
)

;; ===== Internal Functions =====
(define-private (calculate-risk-limit (risk-tier uint))
  (match risk-tier
    1 (* u1000000 u1000000)   ;; 1M
    2 (* u5000000 u1000000)   ;; 5M
    3 (* u25000000 u1000000)  ;; 25M
    4 (* u100000000 u1000000) ;; 100M
    (* u10000000 u1000000)    ;; 10M default
  )
)

(define-private (get-term-version (enterprise-id uint))
  (fold-while 
    (map-get-keys term-sheets {enterprise-id: enterprise-id})
    0
    (lambda (key max-version)
      (if (> (get key 'version) max-version)
        (ok (get key 'version))
        (ok max-version)
      )
    )
  )
)

(define-private (calculate-collateral-value (assets (list 10 {asset: principal, amount: uint})))
  (fold 
    assets
    u0
    (lambda (asset sum)
      (let (
        (price (unwrap! (contract-call? oracle get-price (get asset 'asset)) (err u0)))
        (value (/ (* (get asset 'amount) price) (pow u10 u8)))  ;; Adjust for decimals
      )
        (+ sum value)
      )
    )
  )
)

(define-read-only (get-enterprise-collateral-ratio (enterprise-id uint))
  (let (
    (enterprise (unwrap! (map-get? enterprises {id: enterprise-id}) (err u0)))
    (risk-tier (get enterprise 'risk-tier))
  )
    (match risk-tier
      1 u150  ;; 150% for tier 1
      2 u135  ;; 135% for tier 2
      3 u120  ;; 120% for tier 3
      4 u110  ;; 110% for tier 4
      u200    ;; 200% default
    )
  )
)
