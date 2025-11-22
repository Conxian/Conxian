;; sbtc-bond-integration.clar
;; sBTC Bond Integration - Advanced bond issuance with sBTC collateral and yields

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

;; CONSTANTS AND ERROR CODES
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u5000))
(define-constant ERR_INVALID_BOND_TERMS (err u5001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u5002))
(define-constant ERR_BOND_NOT_FOUND (err u5003))
(define-constant ERR_BOND_ALREADY_MATURED (err u5004))
(define-constant ERR_INSUFFICIENT_YIELD (err u5005))
(define-constant ERR_EARLY_REDEMPTION_NOT_ALLOWED (err u5006))
(define-constant ERR_LIQUIDATION_THRESHOLD_BREACHED (err u5007))
(define-constant ERR_INVALID_YIELD_DISTRIBUTION (err u5008))
(define-constant ERR_POOL_NOT_FOUND (err u5009))

;; Bond parameters
(define-constant MIN_BOND_AMOUNT u10000000000)
(define-constant MAX_BOND_AMOUNT u500000000000)
(define-constant MIN_MATURITY_BLOCKS u52560)
(define-constant MAX_MATURITY_BLOCKS u262800)
(define-constant COLLATERAL_RATIO u1200000)
(define-constant LIQUIDATION_THRESHOLD u1100000)

;; Yield parameters
(define-constant BASE_YIELD_RATE u50000)
(define-constant MAX_YIELD_RATE u200000)
(define-constant YIELD_PRECISION u1000000)
(define-constant ANNUAL_BLOCKS u52560)
(define-constant LIQUIDATION_DISCOUNT u950000)

;; DATA STRUCTURES
(define-map sbtc-bonds
  { bond-id: uint }
  {
    issuer: principal,
    principal-amount: uint,
    coupon-rate: uint,
    maturity-block: uint,
    issue-block: uint,
    collateral-amount: uint,
    collateral-ratio: uint,
    is-callable: bool,
    call-premium: uint,
    status: uint
  })

(define-map bond-holders
  { bond-id: uint, holder: principal }
  {
    amount-held: uint,
    purchase-block: uint,
    purchase-price: uint,
    accrued-interest: uint,
    last-interest-claim: uint
  })

(define-map yield-distribution-pools
  { pool-id: uint }
  {
    total-sbtc-deposited: uint,
    total-bonds-backed: uint,
    current-yield-rate: uint,
    last-yield-calculation: uint,
    pool-manager: principal,
    is-active: bool
  })

(define-map bond-yield-allocations
  { bond-id: uint, pool-id: uint }
  {
    allocated-amount: uint,
    yield-share: uint,
    allocation-block: uint
  })

(define-map enterprise-loan-bonds
  { loan-id: uint }
  {
    bond-ids: (list 10 uint),
    total-bond-value: uint,
    loan-to-bond-ratio: uint,
    risk-tier: uint
  })

;; DATA VARIABLES
(define-data-var next-bond-id uint u1)
(define-data-var next-pool-id uint u1)
(define-data-var total-sbtc-bonds uint u0)
(define-data-var total-yield-distributed uint u0)

;; PRIVATE FUNCTIONS
(define-private (validate-bond-terms (principal-amount uint) (coupon-rate uint) (maturity-blocks uint))
  (and
    (>= principal-amount MIN_BOND_AMOUNT)
    (<= principal-amount MAX_BOND_AMOUNT)
    (>= maturity-blocks MIN_MATURITY_BLOCKS)
    (<= maturity-blocks MAX_MATURITY_BLOCKS)
    (<= coupon-rate MAX_YIELD_RATE)))

(define-private (calculate-required-collateral (principal-amount uint))
  (/ (* principal-amount COLLATERAL_RATIO) u1000000))

(define-private (calculate-collateral-value (collateral-amount uint) (sbtc-price uint))
  (* collateral-amount sbtc-price))

(define-private (calculate-collateral-ratio (collateral-value uint) (principal-amount uint))
  (/ (* collateral-value u1000000) principal-amount))

(define-private (distribute-pool-yield (pool-id uint) (total-yield uint))
  (begin
    (print { event: "yield-available-for-claim", pool-id: pool-id, amount: total-yield })
    (ok true)))

(define-private (sum-bond-amounts (bond-spec { amount: uint, coupon: uint, maturity: uint }) (acc uint))
  (+ acc (get amount bond-spec)))

(define-private (create-loan-bonds (bond-structure (list 10 { amount: uint, coupon: uint, maturity: uint })))
  (list (var-get next-bond-id)))

;; PUBLIC FUNCTIONS
(define-public (issue-sbtc-backed-bond
    (principal-amount uint)
    (coupon-rate uint)
    (maturity-blocks uint)
    (collateral-amount uint)
    (is-callable bool)
    (call-premium uint))
  (let ((bond-id (var-get next-bond-id)))
    (begin
      (asserts! (validate-bond-terms principal-amount coupon-rate maturity-blocks) ERR_INVALID_BOND_TERMS)
      
      (match (contract-call? .sbtc-integration get-sbtc-price)
        sbtc-price (let (
            (collateral-value (calculate-collateral-value collateral-amount sbtc-price))
            (required-collateral (calculate-required-collateral principal-amount)))
          (asserts! (>= collateral-value required-collateral) ERR_INSUFFICIENT_COLLATERAL)
          
          (try! (contract-call? .sbtc-token transfer collateral-amount tx-sender (as-contract tx-sender) none))
          
          (map-set sbtc-bonds
            { bond-id: bond-id }
            {
              issuer: tx-sender,
              principal-amount: principal-amount,
              coupon-rate: coupon-rate,
              maturity-block: (+ block-height maturity-blocks),
              issue-block: block-height,
              collateral-amount: collateral-amount,
              collateral-ratio: (calculate-collateral-ratio collateral-value principal-amount),
              is-callable: is-callable,
              call-premium: call-premium,
              status: u0
            })
          
          (var-set next-bond-id (+ bond-id u1))
          (var-set total-sbtc-bonds (+ (var-get total-sbtc-bonds) principal-amount))
          
          (print {
            event: "sbtc-bond-issued",
            bond-id: bond-id,
            issuer: tx-sender,
            principal: principal-amount,
            collateral: collateral-amount
          })
          (ok bond-id))
        ERR_INSUFFICIENT_COLLATERAL))))

(define-public (purchase-bond (bond-id uint) (amount uint))
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (begin
      (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
      (asserts! (> amount u0) ERR_INVALID_BOND_TERMS)
      (asserts! (<= amount (get principal-amount bond)) ERR_INVALID_BOND_TERMS)
      
      (try! (contract-call? .sbtc-token transfer amount tx-sender (get issuer bond) none))
      
      (let ((existing-holding (default-to
          { amount-held: u0, purchase-block: u0, purchase-price: u0, accrued-interest: u0, last-interest-claim: u0 }
          (map-get? bond-holders { bond-id: bond-id, holder: tx-sender }))))
        (map-set bond-holders
          { bond-id: bond-id, holder: tx-sender }
          {
            amount-held: (+ (get amount-held existing-holding) amount),
            purchase-block: block-height,
            purchase-price: (+ (get purchase-price existing-holding) amount),
            accrued-interest: (get accrued-interest existing-holding),
            last-interest-claim: (max (get last-interest-claim existing-holding) block-height)
          }))
      
      (print { event: "bond-purchased", bond-id: bond-id, buyer: tx-sender, amount: amount })
      (ok true))
    ERR_BOND_NOT_FOUND))

(define-public (create-yield-pool (initial-sbtc-amount uint))
  (let ((pool-id (var-get next-pool-id)))
    (begin
      (asserts! (> initial-sbtc-amount u0) ERR_INVALID_YIELD_DISTRIBUTION)
      
      (try! (contract-call? .sbtc-token transfer initial-sbtc-amount tx-sender (as-contract tx-sender) none))
      
      (map-set yield-distribution-pools
        { pool-id: pool-id }
        {
          total-sbtc-deposited: initial-sbtc-amount,
          total-bonds-backed: u0,
          current-yield-rate: BASE_YIELD_RATE,
          last-yield-calculation: block-height,
          pool-manager: tx-sender,
          is-active: true
        })
      
      (var-set next-pool-id (+ pool-id u1))
      
      (print { event: "yield-pool-created", pool-id: pool-id, manager: tx-sender, initial-amount: initial-sbtc-amount })
      (ok pool-id))))

(define-public (allocate-yield-to-bond (bond-id uint) (pool-id uint) (allocation-percentage uint))
  (let (
      (bond (unwrap! (map-get? sbtc-bonds { bond-id: bond-id }) ERR_BOND_NOT_FOUND))
      (pool (unwrap! (map-get? yield-distribution-pools { pool-id: pool-id }) ERR_POOL_NOT_FOUND)))
    (begin
      (asserts! (or (is-eq tx-sender (get pool-manager pool))
                    (is-eq tx-sender (get issuer bond))) ERR_NOT_AUTHORIZED)
      (asserts! (get is-active pool) ERR_INVALID_YIELD_DISTRIBUTION)
      (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
      (asserts! (<= allocation-percentage u1000000) ERR_INVALID_YIELD_DISTRIBUTION)
      
      (let ((allocated-amount (/ (* (get total-sbtc-deposited pool) allocation-percentage) u1000000)))
        (map-set bond-yield-allocations
          { bond-id: bond-id, pool-id: pool-id }
          {
            allocated-amount: allocated-amount,
            yield-share: allocation-percentage,
            allocation-block: block-height
          })
        
        (map-set yield-distribution-pools
          { pool-id: pool-id }
          (merge pool { total-bonds-backed: (+ (get total-bonds-backed pool) (get principal-amount bond)) }))
        
        (print {
          event: "yield-allocated-to-bond",
          bond-id: bond-id,
          pool-id: pool-id,
          allocated-amount: allocated-amount,
          allocation-percentage: allocation-percentage
        })
        (ok allocated-amount)))))

(define-public (calculate-and-distribute-yield (pool-id uint))
  (match (map-get? yield-distribution-pools { pool-id: pool-id })
    pool (begin
      (asserts! (is-eq tx-sender (get pool-manager pool)) ERR_NOT_AUTHORIZED)
      
      (let ((blocks-elapsed (- block-height (get last-yield-calculation pool))))
        (match (contract-call? .enhanced-yield-strategy get-current-apy)
          current-apy (let ((yield-amount (/ (* (get total-sbtc-deposited pool) current-apy blocks-elapsed) (* ANNUAL_BLOCKS u1000000))))
            (try! (distribute-pool-yield pool-id yield-amount))
            
            (map-set yield-distribution-pools
              { pool-id: pool-id }
              (merge pool {
                current-yield-rate: current-apy,
                last-yield-calculation: block-height
              }))
            
            (var-set total-yield-distributed (+ (var-get total-yield-distributed) yield-amount))
            
            (print { event: "yield-distributed", pool-id: pool-id, amount: yield-amount })
            (ok yield-amount))
          ERR_INSUFFICIENT_YIELD)))
    ERR_POOL_NOT_FOUND))

(define-public (redeem-matured-bond (bond-id uint))
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (match (map-get? bond-holders { bond-id: bond-id, holder: tx-sender })
      holding (begin
        (asserts! (>= block-height (get maturity-block bond)) ERR_EARLY_REDEMPTION_NOT_ALLOWED)
        (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
        
        (let ((redemption-amount (get amount-held holding)))
          (try! (as-contract (contract-call? .sbtc-token transfer redemption-amount tx-sender tx-sender none)))
          
          (map-delete bond-holders { bond-id: bond-id, holder: tx-sender })
          
          (map-set sbtc-bonds
            { bond-id: bond-id }
            (merge bond { status: u1 }))
          
          (print { event: "bond-redeemed", bond-id: bond-id, holder: tx-sender, amount: redemption-amount })
          (ok redemption-amount)))
      ERR_BOND_NOT_FOUND)
    ERR_BOND_NOT_FOUND))

(define-public (early-call-bond (bond-id uint))
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (begin
      (asserts! (is-eq tx-sender (get issuer bond)) ERR_NOT_AUTHORIZED)
      (asserts! (get is-callable bond) ERR_EARLY_REDEMPTION_NOT_ALLOWED)
      (asserts! (is-eq (get status bond) u0) ERR_BOND_ALREADY_MATURED)
      
      (let ((call-price (+ (get principal-amount bond) (get call-premium bond))))
        (map-set sbtc-bonds
          { bond-id: bond-id }
          (merge bond { status: u2 }))
        
        (print { event: "bond-called", bond-id: bond-id, call-price: call-price })
        (ok call-price)))
    ERR_BOND_NOT_FOUND))

(define-public (check-bond-collateralization (bond-id uint))
  (match (map-get? sbtc-bonds { bond-id: bond-id })
    bond (match (contract-call? .sbtc-integration get-sbtc-price)
      sbtc-price (let (
          (collateral-value (calculate-collateral-value (get collateral-amount bond) sbtc-price))
          (required-collateral (calculate-required-collateral (get principal-amount bond)))
          (current-ratio (calculate-collateral-ratio collateral-value (get principal-amount bond)))
          (is-liquidatable (< current-ratio LIQUIDATION_THRESHOLD)))
        (ok {
          bond-id: bond-id,
          collateral-amount: (get collateral-amount bond),
          collateral-value: collateral-value,
          required-collateral: required-collateral,
          current-ratio: current-ratio,
          is-liquidatable: is-liquidatable,
          status: (get status bond)
        }))
      ERR_INSUFFICIENT_COLLATERAL)
    ERR_BOND_NOT_FOUND))
