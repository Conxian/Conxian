;; insurance-protection-nft.clar
;; Comprehensive insurance protection NFT system for the Conxian ecosystem
;; Provides coverage for smart contract failures, liquidation events, and systemic risks

(use-trait sip-009-nft-trait .01-sip-standards.sip-009-nft-trait)
(use-trait sip-010-ft-trait .01-sip-standards.sip-010-ft-trait)

(impl-trait .01-sip-standards.sip-009-nft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u12000))
(define-constant ERR_INVALID_POLICY (err u12001))
(define-constant ERR_POLICY_NOT_FOUND (err u12002))
(define-constant ERR_INSUFFICIENT_COVERAGE (err u12003))
(define-constant ERR_CLAIM_NOT_ELIGIBLE (err u12004))
(define-constant ERR_POLICY_EXPIRED (err u12005))
(define-constant ERR_PREMIUM_NOT_PAID (err u12006))

;; Insurance Constants
(define-constant BASE_PREMIUM_RATE u200)           ;; 2% base premium rate
(define-constant MIN_COVERAGE_AMOUNT u1000000       ;; 1 STX minimum coverage
(define-constant MAX_COVERAGE_AMOUNT u100000000     ;; 1000 STX maximum coverage
(define-constant MIN_POLICY_DURATION u1000         ;; 1000 blocks minimum
(define-constant MAX_POLICY_DURATION u100000       ;; 100000 blocks maximum
(define-constant CLAIM_WAITING_PERIOD u100          ;; 100 blocks waiting period
(define-constant DEDUCTIBLE_PERCENTAGE u1000        ;; 10% deductible

;; Insurance NFT Types
(define-constant NFT_TYPE_INSURANCE_POLICY u1)      ;; Active insurance policy
(define-constant NFT_TYPE_CLAIM_HISTORY u2)         ;; Claim history record
(define-constant NFT_TYPE_RISK_ASSESSMENT u3)       ;; Risk assessment certificate
(define-constant NFT_TYPE_PROOF_OF_INSURANCE u4)    ;; Proof of insurance certificate
(define-constant NFT_TYPE_PREMIUM_DISCOUNT u5)       ;; Premium discount certificate

;; Coverage Types
(define-constant COVERAGE_SMART_CONTRACT u1)         ;; Smart contract failure coverage
(define-constant COVERAGE_LIQUIDATION u2)            ;; Liquidation protection
(define-constant COVERAGE_SYSTEMIC_RISK u3)          ;; Systemic risk coverage
(define-constant COVERAGE_ORACLE_FAILURE u4)         ;; Oracle failure coverage
(define-constant COVERAGE_BRIDGE_FAILURE u5)         ;; Bridge failure coverage

;; Risk Tiers
(define-constant RISK_TIER_LOW u1)                   ;; Low risk - 1% premium
(define-constant RISK_TIER_MEDIUM u2)                ;; Medium risk - 2% premium
(define-constant RISK_TIER_HIGH u3)                  ;; High risk - 5% premium
(define-constant RISK_TIER_EXTREME u4)               ;; Extreme risk - 10% premium

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var next-token-id uint u1
(define-data-var next-policy-id uint u1
(define-data-var next-claim-id uint u1
(define-data-var base-token-uri (optional (string-utf8 256)) none)
(define-data-var insurance-treasury principal tx-sender
(define-data-var risk-assessment-contract principal tx-sender

;; ===== NFT Definition =====
(define-non-fungible-token insurance-nft uint)

;; ===== Insurance Data Structures =====

;; Insurance policies
(define-map insurance-policies
  { policy-id: uint }
  {
    policyholder: principal,
    coverage-type: uint,                          ;; Type of coverage
    coverage-amount: uint,                         ;; Maximum coverage amount
    premium-amount: uint,                         ;; Annual premium
    premium-paid: bool,                           ;; Whether premium is paid
    start-block: uint,                            ;; Policy start block
    end-block: uint,                              ;; Policy end block
    risk-tier: uint,                              ;; Risk assessment tier
    deductible: uint,                             ;; Deductible amount
    coverage-details: (list 10 (string-ascii 100)), ;; Specific coverage details
    exclusions: (list 10 (string-ascii 100)),     ;; Policy exclusions
    claim-history: (list 20 uint),                ;; List of claim IDs
    status: uint,                                 ;; 1=active, 2=expired, 3=cancelled, 4=suspended
    last-claim-block: uint,                       ;; Last claim block
    total-claims-paid: uint,                       ;; Total claims paid
    nft-token-id: uint,                           ;; Associated NFT
    created-at: uint
  })

;; Insurance claims
(define-map insurance-claims
  { claim-id: uint }
  {
    policy-id: uint,                             ;; Associated policy
    claimant: principal,                          ;; Who is claiming
    claim-type: uint,                             ;; Type of claim
    claim-amount: uint,                           ;; Amount being claimed
    description: (string-utf8 1000),             ;; Claim description
    evidence: (list 10 (string-ascii 256)),      ;; Evidence provided
    claim-status: uint,                           ;; 1=pending, 2=under-review, 3=approved, 4=rejected, 5=paid
    submitted-block: uint,                       ;; When claim was submitted
    reviewed-block: (optional uint),             ;; When claim was reviewed
    approved-amount: uint,                        ;; Amount approved for payment
    deductible-applied: uint,                     ;; Deductible amount applied
    payment-block: (optional uint),               ;; When payment was made
    reviewer: (optional principal),              ;; Who reviewed the claim
    rejection-reason: (optional (string-ascii 500)), ;; Reason for rejection
    nft-token-id: uint,                           ;; Associated claim NFT
    created-at: uint
  })

;; Risk assessment certificates
(define-map risk-assessments
  { assessment-id: uint }
  {
    assessed-entity: principal,                   ;; Entity being assessed
    risk-score: uint,                             ;; Risk score (0-10000)
    risk-tier: uint,                              ;; Risk tier classification
    assessment-factors: (list 10 { factor: (string-ascii 50), weight: uint, score: uint }), ;; Assessment factors
    coverage-recommendations: (list 5 { type: uint, max-coverage: uint, premium-rate: uint }), ;; Coverage recommendations
    assessment-date: uint,                       ;; When assessment was performed
    valid-until: uint,                            ;; Assessment validity period
    assessor: principal,                          ;; Who performed assessment
    special-conditions: (list 10 (string-ascii 100)), ;; Special conditions
    nft-token-id: uint,                           ;; Associated NFT
    created-at: uint
  })

;; Proof of insurance certificates
(define-map proof-of-insurance
  { certificate-id: uint }
  {
    policyholder: principal,
    policy-id: uint,                             ;; Associated policy
    coverage-type: uint,                         ;; Type of coverage
    coverage-amount: uint,                       ;; Coverage amount
    valid-from: uint,                            ;; Certificate validity start
    valid-until: uint,                           ;; Certificate validity end
    certificate-purpose: (string-ascii 100),     ;; Purpose of certificate
    verification-code: (string-ascii 32),       ;; Verification code
    issuer: principal,                           ;; Certificate issuer
    nft-token-id: uint,                           ;; Associated NFT
    created-at: uint
  })

;; Premium discount certificates
(define-map premium-discounts
  { discount-id: uint }
  {
    holder: principal,
    discount-type: uint,                         ;; Type of discount
    discount-percentage: uint,                   ;; Discount percentage
    applicable-coverage: (list 5 uint),         ;; Coverage types this applies to
    usage-count: uint,                           ;; Times used
    max-uses: uint,                             ;; Maximum uses allowed
    valid-from: uint,                            ;; Discount validity start
    valid-until: uint,                           ;; Discount validity end
    discount-reason: (string-ascii 100),         ;; Reason for discount
    nft-token-id: uint,                           ;; Associated NFT
    created-at: uint
  })

;; Insurance pool funds
(define-map insurance-pools
  { pool-id: uint }
  {
    coverage-type: uint,                         ;; Type of coverage this pool handles
    total-capital: uint,                         ;; Total capital in pool
    available-capital: uint,                      ;; Available capital for claims
    total-premiums: uint,                        ;; Total premiums collected
    total-claims-paid: uint,                     ;; Total claims paid
    pool-status: uint,                            ;; 1=active, 2=suspended, 3=closed
    risk-adjustment-factor: uint,                 ;; Risk adjustment factor
    last-rebalance-block: uint,                   ;; Last pool rebalancing
    contributors: (list 50 principal),           ;; Pool contributors
    contribution-amounts: (list 50 uint),        ;; Contribution amounts
    created-at: uint,
    last-update-block: uint
  })

;; User insurance profiles
(define-map user-insurance-profiles
  { user: principal }
  {
    total-policies: uint,                       ;; Total active policies
    total-coverage: uint,                        ;; Total coverage amount
    total-premiums-paid: uint,                   ;; Total premiums paid
    total-claims-filed: uint,                     ;; Total claims filed
    total-claims-paid: uint,                      ;; Total claims received
    risk-score: uint,                             ;; User's risk score
    insurance-tier: uint,                         ;; Insurance tier (1-5)
    active-policies: (list 10 uint),             ;; Active policy IDs
    claim-history: (list 20 uint),               ;; Claim history
    premium-discounts: (list 10 uint),          ;; Available discounts
    special-privileges: (list 10 (string-ascii 50)), ;; Special privileges
    last-activity-block: uint
  })

;; Industry insurance offerings
(define-map industry-offerings
  { offering-id: uint }
  {
    offering-name: (string-ascii 100),           ;; Offering name
    target-industry: (string-ascii 50),         ;; Target industry
    coverage-types: (list 5 uint),              ;; Coverage types offered
    pricing-model: uint,                         ;; 1=fixed, 2=usage-based, 3=risk-based
    base-premium-rate: uint,                     ;; Base premium rate
    minimum-coverage: uint,                      ;; Minimum coverage amount
    maximum-coverage: uint,                      ;; Maximum coverage amount
    special-features: (list 10 (string-ascii 50)), ;; Special features
    eligibility-criteria: (list 10 (string-ascii 100)), ;; Eligibility criteria
    offering-status: uint,                        ;; 1=active, 2=pending, 3=retired
    total-policies-sold: uint,                   ;; Total policies sold
    total-premiums-collected: uint,              ;; Total premiums collected
    total-claims-paid: uint,                     ;; Total claims paid
    risk-pool-capital: uint,                      ;; Risk pool capital
    created-at: uint,
    last-update-block: uint
  })

;; ===== Public Functions =====

;; @desc Creates a new insurance policy NFT
;; @param coverage-type The type of coverage
;; @param coverage-amount The coverage amount
;; @param policy-duration The policy duration in blocks
;; @param custom-details Custom coverage details
;; @returns Response with policy ID and NFT token ID or error
(define-public (create-insurance-policy-nft
  (coverage-type uint)
  (coverage-amount uint)
  (policy-duration uint)
  (custom-details (list 10 (string-ascii 100))))
  (begin
    (asserts! (is-valid-coverage-type coverage-type) ERR_INVALID_POLICY)
    (asserts! (and (>= coverage-amount MIN_COVERAGE_AMOUNT) (<= coverage-amount MAX_COVERAGE_AMOUNT)) ERR_INVALID_POLICY)
    (asserts! (and (>= policy-duration MIN_POLICY_DURATION) (<= policy-duration MAX_POLICY_DURATION)) ERR_INVALID_POLICY)
    
    (let ((policy-id (var-get next-policy-id))
          (token-id (var-get next-token-id))
          (risk-tier (assess-user-risk-tier tx-sender coverage-type))
          (premium-rate (calculate-premium-rate coverage-type risk-tier))
          (premium-amount (/ (* coverage-amount premium-rate) u10000))
          (deductible (/ (* coverage-amount DEDUCTIBLE_PERCENTAGE) u10000))
          (end-block (+ block-height policy-duration)))
      
      ;; Create insurance policy
      (map-set insurance-policies
        { policy-id: policy-id }
        {
          policyholder: tx-sender,
          coverage-type: coverage-type,
          coverage-amount: coverage-amount,
          premium-amount: premium-amount,
          premium-paid: false,
          start-block: block-height,
          end-block: end-block,
          risk-tier: risk-tier,
          deductible: deductible,
          coverage-details: custom-details,
          exclusions: (get-policy-exclusions coverage-type),
          claim-history: (list),
          status: u1, ;; Active (pending premium payment)
          last-claim-block: u0,
          total-claims-paid: u0,
          nft-token-id: token-id,
          created-at: block-height
        })
      
      ;; Create associated NFT
      (map-set insurance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_INSURANCE_POLICY,
          policy-id: (some policy_id),
          claim-id: none,
          assessment-id: none,
          certificate-id: none,
          discount-id: none,
          coverage-amount: coverage-amount,
          risk-tier: risk-tier,
          visual-tier: (calculate-insurance-visual-tier coverage-amount risk-tier),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update user insurance profile
      (update-user-insurance-profile-on-policy tx-sender policy_id coverage-amount premium-amount)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-policy-id (+ policy_id u1))
      (var-set next-token-id (+ token_id u1))
      
      (print {
        event: "insurance-policy-nft-created",
        policy-id: policy_id,
        token-id: token-id,
        policyholder: tx-sender,
        coverage-type: coverage-type,
        coverage-amount: coverage-amount,
        premium-amount: premium-amount,
        risk-tier: risk-tier,
        end-block: end-block
      })
      
      (ok { policy-id: policy_id, token-id: token-id })
    )
  )
)

;; @desc Files an insurance claim
;; @param policy-id The policy ID
;; @param claim-type The claim type
;; @param claim-amount The claim amount
;; @param description Claim description
;; @param evidence Evidence provided
;; @returns Response with claim ID or error
(define-public (file-insurance-claim
  (policy-id uint)
  (claim-type uint)
  (claim-amount uint)
  (description (string-utf8 1000))
  (evidence (list 10 (string-ascii 256))))
  (let ((policy (unwrap! (map-get? insurance-policies { policy-id: policy_id }) ERR_POLICY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get policyholder policy)) ERR_UNAUTHORIZED)
    (asserts! (= (get status policy) u1) ERR_POLICY_NOT_FOUND) ;; Must be active
    (asserts! (< block-height (get end-block policy)) ERR_POLICY_EXPIRED) ;; Must not be expired
    (asserts! (get premium-paid policy) ERR_PREMIUM_NOT_PAID) ;; Premium must be paid
    (asserts! (<= claim-amount (get coverage-amount policy)) ERR_INSUFFICIENT_COVERAGE)
    (asserts! (> (- block-height (get last-claim-block policy)) CLAIM_WAITING_PERIOD) ERR_CLAIM_NOT_ELIGIBLE) ;; Must respect waiting period
    
    (let ((claim-id (var-get next-claim-id))
          (token-id (var-get next-token-id)))
      
      ;; Create insurance claim
      (map-set insurance-claims
        { claim-id: claim_id }
        {
          policy-id: policy_id,
          claimant: tx-sender,
          claim-type: claim_type,
          claim-amount: claim-amount,
          description: description,
          evidence: evidence,
          claim-status: u1, ;; Pending
          submitted-block: block-height,
          reviewed-block: none,
          approved-amount: u0,
          deductible-applied: u0,
          payment-block: none,
          reviewer: none,
          rejection-reason: none,
          nft-token-id: token-id,
          created-at: block-height
        })
      
      ;; Update policy claim history
      (map-set insurance-policies
        { policy-id: policy_id }
        (merge policy {
          claim-history: (append (get claim-history policy) (list claim_id)),
          last-claim-block: block-height
        }))
      
      ;; Create claim history NFT
      (map-set insurance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_CLAIM_HISTORY,
          policy-id: (some policy_id),
          claim-id: (some claim_id),
          assessment-id: none,
          certificate-id: none,
          discount-id: none,
          coverage-amount: claim-amount,
          risk-tier: (get risk-tier policy),
          visual-tier: (calculate-claim-visual-tier claim-amount),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Update user insurance profile
      (update-user-insurance-profile-on_claim tx-sender claim_id claim-amount)
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-claim-id (+ claim_id u1))
      (var-set next-token-id (+ token_id u1))
      
      (print {
        event: "insurance-claim-filed",
        claim-id: claim_id,
        token-id: token-id,
        policy-id: policy_id,
        claimant: tx-sender,
        claim-type: claim_type,
        claim-amount: claim-amount,
        submitted-block: block-height
      })
      
      (ok claim_id)
    )
  )
)

;; @desc Creates a risk assessment certificate NFT
;; @param assessed-entity The entity being assessed
;; @param assessment-factors Assessment factors and scores
;; @param coverage-recommendations Coverage recommendations
;; @returns Response with assessment ID and NFT token ID or error
(define-public (create-risk-assessment-nft
  (assessed-entity principal)
  (assessment-factors (list 10 { factor: (string-ascii 50), weight: uint, score: uint }))
  (coverage-recommendations (list 5 { type: uint, max-coverage: uint, premium-rate: uint })))
  (begin
    (asserts! (is-authorized-assessor tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-assessment-factors assessment-factors) ERR_INVALID_POLICY)
    
    (let ((assessment-id (+ (var-get next-policy-id) u10000)) ;; Use offset to avoid conflicts
          (token-id (var-get next-token-id))
          (risk-score (calculate-risk-score assessment-factors))
          (risk-tier (calculate-risk-tier-from-score risk-score))
          (validity-period u50000)) ;; 50000 blocks validity
      
      ;; Create risk assessment
      (map-set risk-assessments
        { assessment-id: assessment_id }
        {
          assessed-entity: assessed-entity,
          risk-score: risk-score,
          risk-tier: risk-tier,
          assessment-factors: assessment-factors,
          coverage-recommendations: coverage-recommendations,
          assessment-date: block-height,
          valid-until: (+ block-height validity-period),
          assessor: tx-sender,
          special-conditions: (get-assessment-special-conditions risk-tier),
          nft-token-id: token-id,
          created-at: block-height
        })
      
      ;; Create associated NFT
      (map-set insurance-nft-metadata
        { token-id: token-id }
        {
          owner: assessed-entity,
          nft-type: NFT_TYPE_RISK_ASSESSMENT,
          policy-id: none,
          claim-id: none,
          assessment-id: (some assessment_id),
          certificate-id: none,
          discount-id: none,
          coverage-amount: u0,
          risk-tier: risk-tier,
          visual-tier: (calculate-assessment-visual-tier risk-score),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Mint NFT
      (mint-nft token-id assessed-entity)
      
      (var-set next-token-id (+ token_id u1))
      
      (print {
        event: "risk-assessment-nft-created",
        assessment-id: assessment_id,
        token-id: token-id,
        assessed-entity: assessed_entity,
        risk-score: risk_score,
        risk-tier: risk-tier,
        assessor: tx-sender,
        valid-until: (+ block-height validity_period)
      })
      
      (ok { assessment-id: assessment_id, token-id: token-id })
    )
  )
)

;; @desc Creates a proof of insurance certificate NFT
;; @param policy-id The policy ID
;; @param certificate-purpose The purpose of the certificate
;; @returns Response with certificate ID and NFT token ID or error
(define-public (create-proof-of-insurance-nft
  (policy-id uint)
  (certificate-purpose (string-ascii 100)))
  (let ((policy (unwrap! (map-get? insurance-policies { policy-id: policy_id }) ERR_POLICY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get policyholder policy)) ERR_UNAUTHORIZED)
    (asserts! (= (get status policy) u1) ERR_POLICY_NOT_FOUND) ;; Must be active
    (asserts! (get premium-paid policy) ERR_PREMIUM_NOT_PAID) ;; Premium must be paid
    
    (let ((certificate-id (+ (var-get next-policy-id) u20000)) ;; Use offset to avoid conflicts
          (token-id (var-get next-token-id))
          (validity-period u10000) ;; 10000 blocks validity
          (verification-code (generate-verification-code policy_id)))
      
      ;; Create proof of insurance
      (map-set proof-of-insurance
        { certificate-id: certificate_id }
        {
          policyholder: tx-sender,
          policy-id: policy_id,
          coverage-type: (get coverage-type policy),
          coverage-amount: (get coverage-amount policy),
          valid-from: block-height,
          valid-until: (+ block-height validity_period),
          certificate-purpose: certificate-purpose,
          verification-code: verification-code,
          issuer: (var-get contract-owner),
          nft-token-id: token-id,
          created-at: block-height
        })
      
      ;; Create associated NFT
      (map-set insurance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_PROOF_OF_INSURANCE,
          policy-id: (some policy_id),
          claim-id: none,
          assessment-id: none,
          certificate-id: (some certificate_id),
          discount-id: none,
          coverage-amount: (get coverage-amount policy),
          risk-tier: (get risk-tier policy),
          visual-tier: (calculate-certificate-visual-tier (get coverage-amount policy)),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token_id u1))
      
      (print {
        event: "proof-of-insurance-nft-created",
        certificate-id: certificate_id,
        token-id: token-id,
        policy-id: policy_id,
        policyholder: tx-sender,
        certificate-purpose: certificate-purpose,
        verification-code: verification-code,
        valid-until: (+ block-height validity_period)
      })
      
      (ok { certificate-id: certificate_id, token-id: token-id })
    )
  )
)

;; @desc Creates a premium discount certificate NFT
;; @param discount-type The discount type
;; @param discount-percentage The discount percentage
;; @param max-uses Maximum uses allowed
;; @param discount-reason Reason for discount
;; @returns Response with discount ID and NFT token ID or error
(define-public (create-premium-discount-nft
  (discount-type uint)
  (discount-percentage uint)
  (max-uses uint)
  (discount-reason (string-ascii 100)))
  (begin
    (asserts! (is-authorized-for-discounts tx-sender) ERR_UNAUTHORIZED)
    (asserts! (and (>= discount-percentage u100) (<= discount-percentage u5000)) ERR_INVALID_POLICY) ;; 1% to 50%
    (asserts! (> max-uses u0) ERR_INVALID_POLICY)
    
    (let ((discount-id (+ (var-get next-policy-id) u30000)) ;; Use offset to avoid conflicts
          (token-id (var-get next-token-id))
          (validity-period u50000) ;; 50000 blocks validity
          (applicable-coverage (get-applicable-coverage-for-discount discount-type)))
      
      ;; Create premium discount
      (map-set premium-discounts
        { discount-id: discount_id }
        {
          holder: tx-sender,
          discount-type: discount_type,
          discount-percentage: discount-percentage,
          applicable-coverage: applicable-coverage,
          usage-count: u0,
          max-uses: max-uses,
          valid-from: block-height,
          valid-until: (+ block-height validity_period),
          discount-reason: discount-reason,
          nft-token-id: token-id,
          created-at: block-height
        })
      
      ;; Create associated NFT
      (map-set insurance-nft-metadata
        { token-id: token-id }
        {
          owner: tx-sender,
          nft-type: NFT_TYPE_PREMIUM_DISCOUNT,
          policy-id: none,
          claim-id: none,
          assessment-id: none,
          certificate-id: none,
          discount-id: (some discount_id),
          coverage-amount: u0,
          risk-tier: u1, ;; Low risk for discount holders
          visual-tier: (calculate-discount-visual-tier discount-percentage),
          creation-block: block-height,
          last-activity-block: block-height
        })
      
      ;; Mint NFT
      (mint-nft token-id tx-sender)
      
      (var-set next-token-id (+ token_id u1))
      
      (print {
        event: "premium-discount-nft-created",
        discount-id: discount_id,
        token-id: token-id,
        holder: tx-sender,
        discount-type: discount_type,
        discount-percentage: discount-percentage,
        max-uses: max-uses,
        discount-reason: discount-reason,
        valid-until: (+ block-height validity_period)
      })
      
      (ok { discount-id: discount_id, token-id: token-id })
    )
  )
)

;; @desc Pays premium for an insurance policy
;; @param policy-id The policy ID
;; @param payment-amount The amount being paid
;; @returns Response with success status
(define-public (pay-insurance-premium (policy-id uint) (payment-amount uint))
  (let ((policy (unwrap! (map-get? insurance-policies { policy-id: policy_id }) ERR_POLICY_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get policyholder policy)) ERR_UNAUTHORIZED)
    (asserts! (not (get premium-paid policy)) ERR_PREMIUM_NOT_PAID) ;; Must not be already paid
    (asserts! (= payment-amount (get premium-amount policy)) ERR_INVALID_AMOUNT) ;; Must match premium amount
    
    ;; Transfer premium payment (in real implementation)
    ;; (try! (contract-call? premium-token transfer-from tx-sender (var-get insurance-treasury) payment-amount))
    
    ;; Update policy status
    (map-set insurance-policies
      { policy-id: policy_id }
      (merge policy { premium-paid: true, status: u1 })) ;; Active
    
    ;; Update user profile
    (update-user-insurance-profile-on_premium tx-sender payment-amount)
    
    (print {
      event: "insurance-premium-paid",
      policy-id: policy_id,
      policyholder: tx-sender,
      premium-amount: payment-amount,
      payment-block: block-height
    })
    
    (ok true)
  )
)

;; @desc Approves and pays an insurance claim
;; @param claim-id The claim ID
;; @param approved-amount The approved amount
;; @param reviewer-notes Reviewer notes
;; @returns Response with success status
(define-public (approve-and-pay-claim
  (claim-id uint)
  (approved-amount uint)
  (reviewer-notes (string-ascii 500)))
  (begin
    (asserts! (is-authorized-claim-reviewer tx-sender) ERR_UNAUTHORIZED)
    
    (let ((claim (unwrap! (map-get? insurance-claims { claim-id: claim_id }) ERR_CLAIM_NOT_FOUND))
          (policy (unwrap! (map-get? insurance-policies { policy-id: (get policy-id claim) }) ERR_POLICY_NOT_FOUND)))
      
      ;; Update claim status
      (let ((deductible-applied (min approved-amount (get deductible policy)))
            (payment-amount (- approved-amount deductible-applied)))
        
        (map-set insurance-claims
          { claim-id: claim_id }
          (merge claim {
            claim-status: u3, ;; Approved
            reviewed-block: (some block-height),
            approved-amount: approved-amount,
            deductible-applied: deductible-applied,
            payment-block: (some block-height),
            reviewer: (some tx-sender)
          }))
        
        ;; Update policy
        (map-set insurance-policies
          { policy-id: (get policy-id claim) }
          (merge policy {
            total-claims-paid: (+ (get total-claims-paid policy) payment-amount)
          }))
        
        ;; Transfer claim payment (in real implementation)
        ;; (try! (contract-call? claim-token transfer (var-get insurance-treasury) (get claimant claim) payment-amount))
        
        (print {
          event: "insurance-claim-approved-and-paid",
          claim-id: claim_id,
          policy-id: (get policy-id claim),
          claimant: (get claimant claim),
          approved-amount: approved-amount,
          deductible-applied: deductible-applied,
          payment-amount: payment-amount,
          reviewer: tx-sender,
          payment-block: block-height
        })
        
        (ok true)
      )
    )
  )
)

;; @desc Creates an industry insurance offering
;; @param offering-name The offering name
;; @param target-industry Target industry
;; @param coverage-types Coverage types offered
;; @param pricing-model Pricing model
;; @returns Response with offering ID or error
(define-public (create-industry-offering
  (offering-name (string-ascii 100))
  (target-industry (string-ascii 50))
  (coverage-types (list 5 uint))
  (pricing-model uint))
  (begin
    (asserts! (is-authorized-for-offering-creation tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-valid-pricing-model pricing-model) ERR_INVALID_POLICY)
    
    (let ((offering-id (+ (var-get next-policy-id) u40000)) ;; Use offset to avoid conflicts
          (base-premium-rate (calculate-industry-premium-rate target-industry pricing-model)))
      
      ;; Create industry offering
      (map-set industry-offerings
        { offering-id: offering_id }
        {
          offering-name: offering-name,
          target-industry: target-industry,
          coverage-types: coverage-types,
          pricing-model: pricing-model,
          base-premium-rate: base-premium-rate,
          minimum-coverage: u10000000, ;; 10 STX minimum for industry
          maximum-coverage: u1000000000, ;; 10000 STX maximum for industry
          special-features: (get-industry-special-features target-industry),
          eligibility-criteria: (get-industry-eligibility-criteria target-industry),
          offering-status: u1, ;; Active
          total-policies-sold: u0,
          total-premiums-collected: u0,
          total-claims-paid: u0,
          risk-pool-capital: u0,
          created-at: block-height,
          last-update-block: block-height
        })
      
      (print {
        event: "industry-offering-created",
        offering-id: offering_id,
        offering-name: offering-name,
        target-industry: target-industry,
        coverage-types: coverage-types,
        pricing-model: pricing-model,
        base-premium-rate: base-premium-rate
      })
      
      (ok offering_id)
    )
  )
)

;; ===== SIP-009 Implementation =====

(define-read-only (get-last-token-id)
  (ok (- (var-get next-token-id) u1)))

(define-read-only (get-token-uri (token-id uint))
  (ok (var-get base-token-uri)))

(define-read-only (get-owner (token-id uint))
  (ok (map-get? insurance-nft-metadata { token-id: token-id })))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((nft-data (unwrap! (map-get? insurance-nft-metadata { token-id: token-id }) ERR_POSITION_NOT_FOUND)))
    (asserts! (is-eq sender (get owner nft-data)) ERR_UNAUTHORIZED)
    
    ;; Transfer NFT ownership
    (nft-transfer? insurance-nft token-id sender recipient)
    
    ;; Update metadata
    (map-set insurance-nft-metadata
      { token-id: token-id }
      (merge nft-data { owner: recipient, last-activity-block: block-height }))
    
    ;; Handle specific NFT type transfers
    (match (get nft-type nft-data)
      nft-type
        (handle-insurance-nft-transfer token-id nft-type sender recipient)
      error-response
        (ok true))
    
    (print {
      event: "insurance-nft-transferred",
      token-id: token-id,
      from: sender,
      to: recipient,
      nft-type: (get nft-type nft-data)
    })
    
    (ok true)
  )
)

;; ===== Insurance NFT Metadata =====

(define-map insurance-nft-metadata
  { token-id: uint }
  {
    owner: principal,
    nft-type: uint,
    policy-id: (optional uint),
    claim-id: (optional uint),
    assessment-id: (optional uint),
    certificate-id: (optional uint),
    discount-id: (optional uint),
    coverage-amount: uint,
    risk-tier: uint,
    visual-tier: uint,
    creation-block: uint,
    last-activity-block: uint
  })

;; ===== Private Helper Functions =====

(define-private (mint-nft (token-id uint) (recipient principal))
  (nft-mint? insurance-nft token-id recipient))

(define-private (is-valid-coverage-type (coverage-type uint))
  (and (>= coverage-type COVERAGE_SMART_CONTRACT) (<= coverage_type COVERAGE_BRIDGE_FAILURE)))

(define-private (assess-user-risk-tier (user principal) (coverage-type uint))
  ;; Simplified risk assessment - would integrate with risk assessment contract
  (match coverage-type
    COVERAGE_SMART_CONTRACT RISK_TIER_MEDIUM
    COVERAGE_LIQUIDATION RISK_TIER_HIGH
    COVERAGE_SYSTEMIC_RISK RISK_TIER_EXTREME
    COVERAGE_ORACLE_FAILURE RISK_TIER_MEDIUM
    COVERAGE_BRIDGE_FAILURE RISK_TIER_HIGH
    _ RISK_TIER_LOW))

(define-private (calculate-premium-rate (coverage-type uint) (risk-tier uint))
  (let ((base-rate BASE_PREMIUM_RATE)
        (risk-multiplier (match risk-tier
                           RISK_TIER_LOW u500      ;; 0.5x for low risk
                           RISK_TIER_MEDIUM u1000   ;; 1x for medium risk
                           RISK_TIER_HIGH u2500     ;; 2.5x for high risk
                           RISK_TIER_EXTREME u5000)) ;; 5x for extreme risk
        (coverage-multiplier (match coverage-type
                              COVERAGE_SMART_CONTRACT u1000  ;; 1x for smart contracts
                              COVERAGE_LIQUIDATION u1500     ;; 1.5x for liquidation
                              COVERAGE_SYSTEMIC_RISK u3000   ;; 3x for systemic risk
                              COVERAGE_ORACLE_FAILURE u1200  ;; 1.2x for oracle failure
                              COVERAGE_BRIDGE_FAILURE u2000  ;; 2x for bridge failure
                              _ u1000)))
    (/ (* base-rate risk-multiplier coverage-multiplier) u10000)))

(define-private (get-policy-exclusions (coverage-type uint))
  (match coverage-type
    COVERAGE_SMART_CONTRACT (list "user-error" "known-vulnerabilities" "upgrade-failures")
    COVERAGE_LIQUIDATION (list "market-volatility" "user-liquidation" "forced-liquidation")
    COVERAGE_SYSTEMIC_RISK (list "market-crashes" "black-swan-events" "external-failures")
    COVERAGE_ORACLE_FAILURE (list "price-manipulation" "delayed-feeds" "temporary-outages")
    COVERAGE_BRIDGE_FAILURE (list "network-congestion" "user-error" "temporary-suspensions")
    _ (list "standard-exclusions")))

(define-private (calculate-insurance-visual-tier (coverage-amount uint) (risk-tier uint))
  (cond
    ((and (>= coverage-amount u100000000) (= risk-tier RISK_TIER_LOW)) u5) ;; Legendary - low risk, high coverage
    ((and (>= coverage-amount u50000000) (<= risk-tier RISK_TIER_MEDIUM)) u4) ;; Epic
    ((and (>= coverage-amount u10000000) (<= risk-tier RISK_TIER_HIGH)) u3) ;; Rare
    (true u2))) ;; Common

(define-private (calculate-claim-visual-tier (claim-amount uint))
  (cond
    ((>= claim-amount u50000000) u4) ;; Epic - large claims
    ((>= claim-amount u10000000) u3) ;; Rare - medium claims
    ((>= claim-amount u1000000) u2)  ;; Common - small claims
    (true u1))) ;; Basic

(define-private (calculate-assessment-visual-tier (risk-score uint))
  (cond
    ((<= risk-score u2000) u5) ;; Legendary - very low risk
    ((<= risk-score u4000) u4) ;; Epic - low risk
    ((<= risk-score u6000) u3) ;; Rare - medium risk
    ((<= risk-score u8000) u2) ;; Common - high risk
    (true u1))) ;; Basic - very high risk

(define-private (calculate-certificate-visual-tier (coverage-amount uint))
  (cond
    ((>= coverage-amount u100000000) u5) ;; Legendary
    ((>= coverage-amount u50000000) u4) ;; Epic
    ((>= coverage-amount u10000000) u3) ;; Rare
    ((>= coverage-amount u1000000) u2)  ;; Common
    (true u1))) ;; Basic

(define-private (calculate-discount-visual-tier (discount-percentage uint))
  (cond
    ((>= discount-percentage u3000) u5) ;; Legendary - 30%+ discount
    ((>= discount-percentage u2000) u4) ;; Epic - 20%+ discount
    ((>= discount-percentage u1000) u3) ;; Rare - 10%+ discount
    ((>= discount-percentage u500) u2)  ;; Common - 5%+ discount
    (true u1))) ;; Basic - <5% discount

(define-private (is-authorized-assessor (user principal))
  ;; Check if user is authorized to perform risk assessments
  (or (is-eq user (var-get contract-owner)) (has-assessor-privileges user)))

(define-private (is-authorized-claim-reviewer (user principal))
  ;; Check if user is authorized to review claims
  (or (is-eq user (var-get contract-owner)) (has-reviewer-privileges user)))

(define-private (is-authorized-for-discounts (user principal))
  ;; Check if user is authorized to create discounts
  (or (is-eq user (var-get contract-owner)) (has-discount-privileges user)))

(define-private (is-authorized-for-offering-creation (user principal))
  ;; Check if user is authorized to create industry offerings
  (is-eq user (var-get contract-owner)))

(define-private (has-assessor-privileges (user principal))
  ;; Check if user has assessor privileges
  false) ;; Simplified for now

(define-private (has-reviewer-privileges (user principal))
  ;; Check if user has reviewer privileges
  false) ;; Simplified for now

(define-private (has-discount-privileges (user principal))
  ;; Check if user has discount privileges
  false) ;; Simplified for now

(define-private (is-valid-assessment-factors (factors (list 10 { factor: (string-ascii 50), weight: uint, score: uint })))
  ;; Validate assessment factors
  (fold (lambda (factor acc) (and acc (and (>= (get weight factor) u0) (<= (get weight factor) u10000) (>= (get score factor) u0) (<= (get score factor) u10000)))) factors true))

(define-private (calculate-risk-score (factors (list 10 { factor: (string-ascii 50), weight: uint, score: uint })))
  ;; Calculate weighted risk score
  (let ((total-weight (fold (lambda (factor acc) (+ acc (get weight factor))) factors u0)))
    (if (> total-weight u0)
      (/ (fold (lambda (factor acc) (+ acc (* (get weight factor) (get score factor)))) factors u0) total-weight)
      u5000))) ;; Default to medium risk

(define-private (calculate-risk-tier-from-score (score uint))
  (cond
    ((<= score u2000) RISK_TIER_LOW)
    ((<= score u4000) RISK_TIER_MEDIUM)
    ((<= score u7000) RISK_TIER_HIGH)
    (true RISK_TIER_EXTREME)))

(define-private (get-assessment-special-conditions (risk-tier uint))
  (match risk-tier
    RISK_TIER_LOW (list "premium-discounts" "fast-claims" "enhanced-coverage")
    RISK_TIER_MEDIUM (list "standard-coverage" "normal-processing")
    RISK_TIER_HIGH (list "limited-coverage" "additional-monitoring")
    RISK_TIER_EXTREME (list "high-deductibles" "strict-conditions" "limited-claims")))

(define-private (generate-verification-code (policy-id uint))
  ;; Generate a unique verification code for the policy
  "CONX-INS-VERIFY") ;; Simplified for now

(define-private (get-applicable-coverage-for-discount (discount-type uint))
  ;; Get coverage types applicable for discount
  (match discount-type
    u1 (list COVERAGE_SMART_CONTRACT COVERAGE_ORACLE_FAILURE) ;; Tech discount
    u2 (list COVERAGE_LIQUIDATION COVERAGE_SYSTEMIC_RISK)     ;; DeFi discount
    u3 (list COVERAGE_BRIDGE_FAILURE COVERAGE_SMART_CONTRACT)  ;; Bridge discount
    _ (list COVERAGE_SMART_CONTRACT COVERAGE_LIQUIDATION COVERAGE_SYSTEMIC_RISK COVERAGE_ORACLE_FAILURE COVERAGE_BRIDGE_FAILURE))) ;; Universal discount

(define-private (is-valid-pricing-model (pricing-model uint))
  (and (>= pricing-model u1) (<= pricing-model u3)))

(define-private (calculate-industry-premium-rate (industry (string-ascii 50)) (pricing-model uint))
  ;; Calculate industry-specific premium rate
  (let ((base-rate (match pricing-model
                       u1 u300  ;; Fixed pricing - 3%
                       u2 u400  ;; Usage-based - 4%
                       u3 u500)) ;; Risk-based - 5%
        (industry-multiplier (match (string-to-int? industry)
                                    1 u800  ;; Tech - 0.8x
                                    2 u1200 ;; Finance - 1.2x
                                    3 u1500 ;; DeFi - 1.5x
                                    4 u1000 ;; Gaming - 1x
                                    _ u1000))) ;; Default - 1x
    (/ (* base-rate industry-multiplier) u10000)))

(define-private (get-industry-special-features (industry (string-ascii 50)))
  ;; Get special features for industry
  (match (string-to-int? industry)
    1 (list "smart-contract-audits" "tech-support" "rapid-response") ;; Tech
    2 (list "compliance-support" "regulatory-guidance" "financial-advisory") ;; Finance
    3 (list "defi-expertise" "yield-optimization" "liquidity-protection") ;; DeFi
    4 (list "gaming-security" "asset-protection" "player-fund-safety") ;; Gaming
    _ (list "standard-coverage" "basic-support" "general-protection"))) ;; Default

(define-private (get-industry-eligibility-criteria (industry (string-ascii 50)))
  ;; Get eligibility criteria for industry
  (match (string-to-int? industry)
    1 (list "audited-smart-contracts" "security-certifications" "technical-team") ;; Tech
    2 (list "financial-licenses" "compliance-certificates" "audited-financials") ;; Finance
    3 (list "defi-experience" "liquidity-proofs" "community-trust") ;; DeFi
    4 (list "gaming-licenses" "player-protection" "fair-play-certifications") ;; Gaming
    _ (list "basic-requirements" "verification-needed" "standard-compliance"))) ;; Default

(define-private (string-to-int? (str (string-ascii 50)))
  ;; Convert string to int for matching (simplified)
  u1) ;; Default to tech

(define-private (update-user-insurance-profile-on_policy (user principal) (policy-id uint) (coverage-amount uint) (premium-amount uint))
  (let ((profile (default-to { total-policies: u0, total-coverage: u0, total-premiums-paid: u0, total-claims-filed: u0, total-claims-paid: u0, risk-score: u5000, insurance-tier: u1, active-policies: (list), claim-history: (list), premium-discounts: (list), special-privileges: (list), last-activity-block: u0 } (map-get? user-insurance-profiles { user: user }))))
    (map-set user-insurance-profiles
      { user: user }
      (merge profile {
        total-policies: (+ (get total-policies profile) u1),
        total-coverage: (+ (get total-coverage profile) coverage-amount),
        total-premiums-paid: (+ (get total-premiums-paid profile) premium-amount),
        active-policies: (append (get active-policies profile) (list policy_id)),
        last-activity-block: block-height
      }))))

(define-private (update-user-insurance-profile-on_claim (user principal) (claim-id uint) (claim-amount uint))
  (let ((profile (default-to { total-policies: u0, total-coverage: u0, total-premiums-paid: u0, total-claims-filed: u0, total-claims-paid: u0, risk-score: u5000, insurance-tier: u1, active-policies: (list), claim-history: (list), premium-discounts: (list), special-privileges: (list), last-activity-block: u0 } (map-get? user-insurance-profiles { user: user }))))
    (map-set user-insurance-profiles
      { user: user }
      (merge profile {
        total-claims-filed: (+ (get total-claims-filed profile) u1),
        claim-history: (append (get claim-history profile) (list claim_id)),
        risk-score: (+ (get risk-score profile) u200), ;; +2% risk per claim
        last-activity-block: block-height
      }))))

(define-private (update-user-insurance-profile-on_premium (user principal) (premium-amount uint))
  (let ((profile (default-to { total-policies: u0, total-coverage: u0, total-premiums-paid: u0, total-claims-filed: u0, total-claims-paid: u0, risk-score: u5000, insurance-tier: u1, active-policies: (list), claim-history: (list), premium-discounts: (list), special-privileges: (list), last-activity-block: u0 } (map-get? user-insurance-profiles { user: user }))))
    (map-set user-insurance-profiles
      { user: user }
      (merge profile {
        total-premiums-paid: (+ (get total-premiums-paid profile) premium-amount),
        risk-score: (- (get risk-score profile) u100), ;; -1% risk for premium payment
        last-activity-block: block-height
      }))))

(define-private (handle-insurance-nft-transfer (token-id uint) (nft-type uint) (from principal) (to principal))
  (match nft-type
    NFT_TYPE_INSURANCE_POLICY
      ;; Transfer policy rights
      (let ((policy-id (unwrap-panic (get policy-id (unwrap-panic (map-get? insurance-nft-metadata { token-id: token-id }))))))
        (map-set insurance-policies
          { policy-id: policy_id }
          (merge (unwrap-panic (map-get? insurance-policies { policy-id: policy_id })) { policyholder: to })))
    NFT_TYPE_CLAIM_HISTORY
      ;; Transfer claim history (typically non-transferable)
      false
    NFT_TYPE_RISK_ASSESSMENT
      ;; Transfer assessment rights
      (let ((assessment-id (unwrap-panic (get assessment-id (unwrap-panic (map-get? insurance-nft-metadata { token-id: token-id }))))))
        (map-set risk-assessments
          { assessment-id: assessment_id }
          (merge (unwrap-panic (map-get? risk-assessments { assessment-id: assessment_id })) { assessed-entity: to })))
    NFT_TYPE_PROOF_OF_INSURANCE
      ;; Transfer certificate rights
      (let ((certificate-id (unwrap-panic (get certificate-id (unwrap-panic (map-get? insurance-nft-metadata { token-id: token-id }))))))
        (map-set proof-of-insurance
          { certificate-id: certificate_id }
          (merge (unwrap-panic (map-get? proof-of-insurance { certificate-id: certificate_id })) { policyholder: to })))
    NFT_TYPE_PREMIUM_DISCOUNT
      ;; Transfer discount rights
      (let ((discount-id (unwrap-panic (get discount-id (unwrap-panic (map-get? insurance-nft-metadata { token-id: token-id }))))))
        (map-set premium-discounts
          { discount-id: discount_id }
          (merge (unwrap-panic (map-get? premium-discounts { discount-id: discount_id })) { holder: to })))
    _ true)) ;; Other types transfer normally

;; ===== Read-Only Functions =====

(define-read-only (get-insurance-policy (policy-id uint))
  (map-get? insurance-policies { policy-id: policy_id }))

(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims { claim-id: claim_id }))

(define-read-only (get-risk-assessment (assessment-id uint))
  (map-get? risk-assessments { assessment-id: assessment_id }))

(define-read-only (get-proof-of-insurance (certificate-id uint))
  (map-get? proof-of-insurance { certificate-id: certificate_id }))

(define-read-only (get-premium-discount (discount-id uint))
  (map-get? premium-discounts { discount-id: discount_id }))

(define-read-only (get-insurance-pool (pool-id uint))
  (map-get? insurance-pools { pool-id: pool_id }))

(define-read-only (get-user-insurance-profile (user principal))
  (map-get? user-insurance-profiles { user: user }))

(define-read-only (get-industry-offering (offering-id uint))
  (map-get? industry-offerings { offering-id: offering_id }))

(define-read-only (get-insurance-nft-metadata (token-id uint))
  (map-get? insurance-nft-metadata { token-id: token-id }))

(define-read-only (get-user-policies (user principal))
  ;; Return all policies owned by user
  (list))

(define-read-only (get-user-claims (user principal))
  ;; Return all claims filed by user
  (list))

(define-read-only (calculate-premium-for-policy (coverage-type uint) (coverage-amount uint) (risk-tier uint))
  (let ((premium-rate (calculate-premium-rate coverage-type risk-tier)))
    (ok (/ (* coverage-amount premium-rate) u10000))))

(define-read-only (verify-proof-of-insurance (certificate-id uint) (verification-code (string-ascii 32)))
  ;; Verify proof of insurance certificate
  (match (map-get? proof-of-insurance { certificate-id: certificate_id })
    certificate
      (ok (is-eq (get verification-code certificate) verification-code))
    none
      (err u12001)))
