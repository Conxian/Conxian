;; bond-factory.clar
;; Factory contract for creating and managing bond tokens

(use-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.traits.standard-constants-trait)
(use-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.traits.bond-trait)
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.traits.bond-factory-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_INVALID_TERMS (err u5001))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u5002))
(define-constant ERR_BOND_NOT_FOUND (err u5003))
(define-constant ERR_BOND_MATURED (err u5004))
(define-constant ERR_INVALID_AMOUNT (err u5005))
(define-constant ERR_TRANSFER_FAILED (err u5006))
(define-constant ERR_BOND_NOT_MATURE (err u5007))
(define-constant ERR_OVERFLOW (err u5008))
(define-constant ERR_UNDERFLOW (err u5009))
(define-constant ERR_ZERO_DIVISION (err u5010))

;; --- Safe Math Functions ---
(define-private (safe-add (a uint) (b uint))
  (if (>= (unwrap! (safe-sub u340282366920938463463374607431768211455 b) (err ERR_OVERFLOW)) a)
    (ok (+ a b))
    (err ERR_OVERFLOW)
  )
)

(define-private (safe-sub (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    (err ERR_UNDERFLOW)
  )
)

(define-private (safe-mul (a uint) (b uint))
  (let ((c (* a b)))
    (if (or (= a u0) (= c (div c a)))
      (ok c)
      (err ERR_OVERFLOW)
    )
  )
)

(define-private (safe-div (a uint) (b uint))
  (if (is-eq b u0)
    (err ERR_ZERO_DIVISION)
    (ok (/ a b))
  )
)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var next-bond-id uint u1)
(define-data-var bond-token-code (string-utf8 100000) "")  ;; Will store the bond token contract code

;; Bond registry
(define-map bonds
  uint  ;; bond-id
  {
    issuer: principal,
    principal-amount: uint,
    coupon-rate: uint,
    issue-block: uint,
    maturity-block: uint,
    collateral-amount: uint,
    collateral-token: principal,
    status: (string-ascii 20),
    is-callable: bool,
    call-premium: uint,
    bond-contract: principal
  }
)

;; --- Events ---
(define-data-var event-nonce uint u0)

(define-private (emit-event (event-type (string-ascii 50)) (event-data {issuer: principal, bond-id: uint, amount: uint, timestamp: uint}))
  (let ((nonce (var-get event-nonce)))
    (var-set event-nonce (+ nonce u1))
    (print {
      event: event-type,
      data: event-data,
      nonce: nonce,
      block: block-height
    })
  )
)

;; --- Admin Functions ---
(define-public (set-bond-token-code (code (string-utf8 100000)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set bond-token-code code)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Bond Constants ---
(define-constant MIN_BOND_AMOUNT u1000000)  ;; 1.0 token with 6 decimals
(define-constant MAX_BOND_AMOUNT u1000000000000)  ;; 1,000,000 tokens with 6 decimals
(define-constant MIN_BOND_DURATION u144)  ;; ~1 day in blocks
(define-constant MAX_BOND_DURATION u2102400)  ;; ~4 years in blocks (assuming 1 block = 30s)
(define-constant BOND_STATUS_ACTIVE "active")
(define-constant BOND_STATUS_MATURED "matured")
(define-constant BOND_STATUS_CALLED "called")
(define-constant BOND_STATUS_DEFAULTED "defaulted")

;; --- Bond Creation ---
(define-public (create-bond
    (principal-amount uint)
    (coupon-rate uint)
    (maturity-blocks uint)
    (collateral-amount uint)
    (collateral-token principal)
    (is-callable bool)
    (call-premium uint)
  )
  (let (
      (issuer tx-sender)
      (bond-id (var-get next-bond-id))
      (issue-block block-height)
      (maturity-block (unwrap! (safe-add block-height maturity-blocks) (err ERR_OVERFLOW)))
      (bond-status BOND_STATUS_ACTIVE)
    )
    ;; Input validation with safe math
    (asserts! (>= principal-amount MIN_BOND_AMOUNT) (err u"Bond amount below minimum"))
    (asserts! (<= principal-amount MAX_BOND_AMOUNT) (err u"Bond amount above maximum"))
    (asserts! (>= maturity-blocks MIN_BOND_DURATION) (err u"Maturity too short"))
    (asserts! (<= maturity-blocks MAX_BOND_DURATION) (err u"Maturity too long"))
    (asserts! (>= coupon-rate u0) (err u"Invalid coupon rate"))
    (asserts! (<= coupon-rate u5000) (err u"Coupon rate too high"))  ;; Max 50%
    (asserts! (not (is-eq collateral-amount u0)) (err u"Collateral amount cannot be zero"))
    
    ;; Calculate total payout to ensure no overflow
    (let ((total-payout (unwrap! (safe-add principal-amount (unwrap! (safe-mul principal-amount coupon-rate) (err ERR_OVERFLOW))) (err ERR_OVERFLOW))))
      (asserts! (>= collateral-amount total-payout) (err u"Insufficient collateral"))
      
      ;; Transfer collateral from issuer
      (try! (contract-call? collateral-token transfer collateral-amount issuer (as-contract tx-sender) none))
      
      ;; Increment bond ID safely
      (var-set next-bond-id (unwrap! (safe-add bond-id u1) (err ERR_OVERFLOW)))
      
      ;; Deploy new bond token contract
    (let ((bond-contract (contract-call? .bond-token deploy-contract
      (unwrap-panic (string-utf8-append 
        "(define-constant BOND_ISSUER '" 
        (unwrap-panic (principal-to-address issuer)) 
        ")\n\n" 
        (unwrap! (var-get bond-token-code) (err u"Bond token code not set")) 
        "\n(issue-bond " (unwrap-panic (to-string bond-id)) " " (unwrap-panic (to-string principal-amount)) ")"))))))
      
      ;; Save bond details
      (map-set bonds bond-id {
        issuer: issuer,
        principal-amount: principal-amount,
        coupon-rate: coupon-rate,
        issue-block: issue-block,
        maturity-block: maturity-block,
        collateral-amount: collateral-amount,
        collateral-token: collateral-token,
        status: bond-status,
        is-callable: is-callable,
        call-premium: call-premium,
        bond-contract: bond-contract
      })
      
      ;; Increment bond ID for next issue
      (var-set next-bond-id (+ bond-id u1))
      
      ;; Emit event
      (emit-event "bond_created" {
        issuer: issuer,
        bond-id: bond-id,
        amount: principal-amount,
        timestamp: block-height
      })
      
      (ok {
        bond-id: bond-id,
        bond-contract: bond-contract,
        maturity-block: maturity-block
      })
    )
  )
)

;; --- Bond Utility Functions ---
(define-read-only (get-accrued-interest (bond-id uint))
  (let (
      (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
      (current-block block-height)
      (issue-block (get issue-block bond))
      (maturity-block (get maturity-block bond))
    )
    (if (>= current-block maturity-block)
      (ok (get principal-amount bond))  ;; At maturity, return full principal
      (let (
          (elapsed (unwrap! (safe-sub current-block issue-block) (err ERR_UNDERFLOW)))
          (total-period (unwrap! (safe-sub maturity-block issue-block) (err ERR_UNDERFLOW)))
          (principal (get principal-amount bond))
          (rate (get coupon-rate bond))
        )
        (if (or (is-eq total-period u0) (is-eq elapsed u0))
          (ok u0)
          (let (
              (interest (unwrap! (safe-mul principal rate) (err ERR_OVERFLOW)))
              (accrued (unwrap! (safe-div (unwrap! (safe-mul interest elapsed) (err ERR_OVERFLOW)) total-period) (err ERR_OVERFLOW)))
            )
            (ok (unwrap! (safe-div accrued u10000) (err ERR_OVERFLOW)))  ;; Scale down by 10000 (basis points)
          )
        )
      )
    )
  )
)

;; --- Bond Management ---
(define-public (redeem-bond (bond-id uint))
  (let (
      (caller tx-sender)
      (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
      (current-block block-height)
    )
    ;; Check bond status and maturity
    (asserts! (is-eq (get status bond) BOND_STATUS_ACTIVE) (err u"Bond not active"))
    (asserts! (>= current-block (get maturity-block bond)) (err u"Bond not yet mature"))
    
    ;; Calculate payout with safe math
    (let (
        (principal (get principal-amount bond))
        (interest (unwrap! (safe-div (unwrap! (safe-mul principal (get coupon-rate bond)) (err ERR_OVERFLOW)) u10000) (err ERR_OVERFLOW)))
        (total-payout (unwrap! (safe-add principal interest) (err ERR_OVERFLOW)))
        (collateral-token (get collateral-token bond))
      )
    (asserts! (is-eq caller (get issuer bond)) ERR_UNAUTHORIZED)
    
    ;; Ensure bond contract exists and is valid
    (let ((bond-contract (get bond-contract bond)))
      (asserts! (is-ok (contract-of bond-contract)) (err u"Invalid bond contract"))
      
      (match (contract-call? bond-contract redeem-bond bond-id)
        (ok result) (begin
          ;; Calculate available collateral (principal + interest)
          (let ((payout (unwrap! (safe-sub (get collateral-amount bond) (get collateral-amount bond)) (err ERR_UNDERFLOW))))
            ;; Transfer principal + interest to bond holder
            (try! (contract-call? collateral-token transfer 
                    payout 
                    (as-contract tx-sender) 
                    caller 
                    none))
            
            ;; Update bond status to matured
            (map-set bonds bond-id (merge bond {
              status: BOND_STATUS_MATURED
            }))
            
            (emit-event "bond_redeemed" {
              issuer: caller,
              bond-id: bond-id,
              amount: payout,
              timestamp: block-height
            })
            
            (ok {
              principal: principal,
              interest: interest,
              total-payout: payout
            })
          )
        )
        err (err (unwrap-err err))
      )
    )
        (ok result)
      )
      (err error) error
    )
  )
)

(define-public (report-coupon-payment (bond-id uint) (payment-amount uint))
  (let (
      (caller tx-sender)
      (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
      (current-block block-height)
    )
    ;; Validate bond is active and not matured
    (asserts! (is-eq (get status bond) BOND_STATUS_ACTIVE) (err u"Bond not active"))
    (asserts! (< current-block (get maturity-block bond)) (err u"Bond already matured"))
    
    ;; Calculate expected coupon payment using safe math
    (let (
        (principal (get principal-amount bond))
        (coupon-rate (get coupon-rate bond))
        (expected-interest (unwrap! (safe-div (unwrap! (safe-mul principal coupon-rate) (err ERR_OVERFLOW)) u10000) (err ERR_OVERFLOW)))
      )
      (asserts! (>= payment-amount expected-interest) (err u"Insufficient coupon payment"))
      
      ;; Ensure caller is the bond issuer
      (asserts! (is-eq caller (get issuer bond)) ERR_UNAUTHORIZED)
      
      ;; Transfer coupon payment from issuer to contract
      (try! (contract-call? (get collateral-token bond) transfer 
              payment-amount 
              caller 
              (as-contract tx-sender) 
              none))
      
      ;; Emit coupon payment event
      (emit-event "coupon_paid" {
        issuer: caller,
        bond-id: bond-id,
        amount: payment-amount,
        timestamp: block-height
      })
      (ok true)
    )
  )
)

(define-read-only (get-bond-status (bond-id uint))
  (let ((bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND)))
    (ok {
      bond-id: bond-id,
      status: (get status bond),
      is-mature: (>= block-height (get maturity-block bond)),
      blocks-until-maturity: (unwrap! (safe-sub (get maturity-block bond) block-height) (err ERR_UNDERFLOW)),
      current-block: block-height,
      maturity-block: (get maturity-block bond)
    })
  )
)

(define-read-only (get-bond-count)
  (ok (var-get next-bond-id))
)

;; --- View Functions ---
(define-read-only (get-bond (bond-id uint))
  (match (map-get? bonds bond-id)
    bond (ok (merge bond {bond-id: bond-id}))
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (get-bond-contract (bond-id uint))
  (match (map-get? bonds bond-id)
    bond (ok (get bond-contract bond))
    (err ERR_BOND_NOT_FOUND)
  )
)

(define-read-only (list-bonds (offset uint) (limit uint))
  (let (
      (max-id (var-get next-bond-id))
    )
    (ok (fold (range offset (min (+ offset limit) max-id)) (list)
      (lambda (id acc)
        (match (map-get? bonds id)
          (some bond) (append acc (list (merge bond {bond-id: id})))
          acc
        )
      )
    ))
  )
)
