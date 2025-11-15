;; bond-factory.clar
;; Factory contract for creating and managing bond tokens
(use-trait bond-factory-trait .bond-factory-trait.bond-factory-trait)

(impl-trait .bond-factory-trait.bond-factory-trait)
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
;; @desc Safely adds two unsigned integers, returning an error on overflow.
;; @param a The first unsigned integer.
;; @param b The second unsigned integer.
;; @returns (response uint uint) The sum or an error code.
(define-private (safe-add (a uint) (b uint))
  (if (>= (unwrap! (- u340282366920938463463374607431768211455 b) (err ERR_OVERFLOW)) a)
    (ok (+ a b))
    (err ERR_OVERFLOW)
  )
)

;; @desc Safely subtracts two unsigned integers, returning an error on underflow.
;; @param a The first unsigned integer (minuend).
;; @param b The second unsigned integer (subtrahend).
;; @returns (response uint uint) The difference or an error code.
(define-private (safe-sub (a uint) (b uint))
  (if (>= a b)
    (ok (- a b))
    (err ERR_UNDERFLOW)
  )
)

;; @desc Safely multiplies two unsigned integers, returning an error on overflow.
;; @param a The first unsigned integer.
;; @param b The second unsigned integer.
;; @returns (response uint uint) The product or an error code.
(define-private (safe-mul (a uint) (b uint))
  (let ((c (* a b)))
    (if (or (is-eq a u0) (<= (/ c a) b))
      (ok c)
      (err ERR_OVERFLOW)
    )
  )
)

;; @desc Safely divides two unsigned integers, returning an error on division by zero.
;; @param a The dividend.
;; @param b The divisor.
;; @returns (response uint uint) The quotient or an error code.
(define-private (safe-div (a uint) (b uint))
  (if (is-eq b u0)
    (err ERR_ZERO_DIVISION)
    (ok (/ a b))
  )
)
;; --- Data Variables ---
;; @desc Stores the contract owner's principal.
(define-data-var contract-owner principal tx-sender)
;; @desc Stores the next available bond ID.
(define-data-var next-bond-id uint u1)
;; @desc Stores the Clarity code for the bond token contract.
(define-data-var bond-token-code (string-utf8 100000) "")  ;; Will store the bond token contract code

;; Bond registry
;; @desc Maps bond IDs to bond details.
;; @map-key bond-id uint The unique identifier for the bond.
;; @map-value (tuple
;;   (issuer principal) The principal of the bond issuer.
;;   (principal-amount uint) The principal amount of the bond.
;;   (coupon-rate uint) The coupon rate of the bond.
;;   (issue-block uint) The block height at which the bond was issued.
;;   (maturity-block uint) The block height at which the bond matures.
;;   (collateral-amount uint) The amount of collateral held for the bond.
;;   (collateral-token principal) The principal of the collateral token contract.
;;   (status (string-ascii 20)) The current status of the bond (e.g., "active", "matured").
;;   (is-callable bool) Indicates if the bond is callable.
;;   (call-premium uint) The premium to be paid if the bond is called.
;;   (bond-contract principal) The principal of the deployed bond token contract.
;;   (name (string-ascii 32)) The name of the bond token.
;;   (symbol (string-ascii 10)) The symbol of the bond token.
;;   (decimals uint) The number of decimals for the bond token.
;;   (face-value uint) The face value of the bond token.
;; )
(define-map bonds
  uint  ;; bond-id
  (tuple
    (issuer principal)
    (principal-amount uint)
    (coupon-rate uint)
    (issue-block uint)
    (maturity-block uint)
    (collateral-amount uint)
    (collateral-token principal)
    (status (string-ascii 20))
    (is-callable bool)
    (call-premium uint)
    (bond-contract principal)
    (name (string-ascii 32))
    (symbol (string-ascii 10))
    (decimals uint)
    (face-value uint)
  )
)

;; @desc Maps bond contract principals to bond details for reverse lookup.
;; @map-key bond-contract-principal principal The principal of the deployed bond token contract.
;; @map-value (tuple
;;   (issuer principal) The principal of the bond issuer.
;;   (principal-amount uint) The principal amount of the bond.
;;   (coupon-rate uint) The coupon rate of the bond.
;;   (issue-block uint) The block height at which the bond was issued.
;;   (maturity-block uint) The block height at which the bond matures.
;;   (collateral-amount uint) The amount of collateral held for the bond.
;;   (collateral-token principal) The principal of the collateral token contract.
;;   (status (string-ascii 20)) The current status of the bond (e.g., "active", "matured").
;;   (is-callable bool) Indicates if the bond is callable.
;;   (call-premium uint) The premium to be paid if the bond is called.
;;   (bond-contract principal) The principal of the deployed bond token contract.
;;   (name (string-ascii 32)) The name of the bond token.
;;   (symbol (string-ascii 10)) The symbol of the bond token.
;;   (decimals uint) The number of decimals for the bond token.
;;   (face-value uint) The face value of the bond token.
;; )
(define-map bonds-by-contract
  principal ;; bond-contract-principal
  (tuple
    (issuer principal)
    (principal-amount uint)
    (coupon-rate uint)
    (issue-block uint)
    (maturity-block uint)
    (collateral-amount uint)
    (collateral-token principal)
    (status (string-ascii 20))
    (is-callable bool)
    (call-premium uint)
    (bond-contract principal)
    (name (string-ascii 32))
    (symbol (string-ascii 10))
    (decimals uint)
    (face-value uint)
  )
)

;; --- Events ---
;; @desc Stores a nonce for event emission to ensure uniqueness.
(define-data-var event-nonce uint u0)

;; @desc Emits a structured event for off-chain indexing and monitoring.
;; @param event-type (string-ascii 50) A string describing the type of event (e.g., "bond_created", "bond_redeemed").
;; @param event-data (tuple (issuer principal) (bond-id uint) (amount uint) (timestamp uint)) A tuple containing event-specific data.
;; @returns (response bool uint) Returns (ok true) on successful emission.
(define-private (emit-event (event-type (string-ascii 50)) (event-data (tuple (issuer principal) (bond-id uint) (amount uint) (timestamp uint))))
  (let ((nonce (var-get event-nonce)))
    (var-set event-nonce (+ nonce u1))
    (print (tuple
      (event event-type)
      (data event-data)
      (nonce nonce)
      (block block-height)
    ))
  )
)

;; --- Admin Functions ---
;; @desc Sets the Clarity code for the bond token contract. Only callable by the contract owner.
;; @param code (string-utf8 100000) The Clarity code for the bond token contract.
;; @returns (response bool uint) Returns (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the owner.
(define-public (set-bond-token-code (code (string-utf8 100000)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set bond-token-code code)
    (ok true)
  )
)

;; @desc Transfers ownership of the contract to a new principal. Only callable by the current contract owner.
;; @param new-owner principal The principal of the new contract owner.
;; @returns (response bool uint) Returns (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the owner.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Bond Constants ---
;; @desc Minimum principal amount for a bond (1.0 token with 6 decimals).
(define-constant MIN_BOND_AMOUNT u1000000)  ;; 1.0 token with 6 decimals
;; @desc Maximum principal amount for a bond (1,000,000 tokens with 6 decimals).
(define-constant MAX_BOND_AMOUNT u1000000000000)  ;; 1,000,000 tokens with 6 decimals
;; @desc Minimum bond duration in blocks (~1 day).
(define-constant MIN_BOND_DURATION u144)  ;; ~1 day in blocks
;; @desc Maximum bond duration in blocks (~4 years).
(define-constant MAX_BOND_DURATION u2102400)  ;; ~4 years in blocks (assuming 1 block = 30s)
;; @desc Bond status: active.
(define-constant BOND_STATUS_ACTIVE "active")
;; @desc Bond status: matured.
(define-constant BOND_STATUS_MATURED "matured")
;; @desc Bond status: called.
(define-constant BOND_STATUS_CALLED "called")
;; @desc Bond status: defaulted.
(define-constant BOND_STATUS_DEFAULTED "defaulted")

;; --- Bond Creation ---
;; @desc Creates a new bond with specified parameters.
;; @param principal-amount uint The principal amount of the bond.
;; @param coupon-rate uint The coupon rate of the bond (in basis points, e.g., u100 for 1%).
;; @param maturity-blocks uint The duration of the bond in blocks.
;; @param collateral-amount uint The amount of collateral to be provided.
;; @param collateral-token principal The principal of the collateral token contract.
;; @param is-callable bool Indicates if the bond can be called early.
;; @param call-premium uint The premium to be paid if the bond is called.
;; @param name (string-ascii 32) The name of the bond token.
;; @param symbol (string-ascii 10) The symbol of the bond token.
;; @param decimals uint The number of decimals for the bond token.
;; @param face-value uint The face value of the bond token.
;; @returns (response (tuple (bond-id uint) (bond-contract principal) (maturity-block uint)) uint) Returns bond details on success, or an error code.
(define-public (create-bond
    (principal-amount uint)
    (coupon-rate uint)
    (maturity-blocks uint)
    (collateral-amount uint)
    (collateral-token principal)
    (is-callable bool)
    (call-premium uint)
    (name (string-ascii 32))
    (symbol (string-ascii 10))
    (decimals uint)
    (face-value uint)
  )
  (let (
      (issuer tx-sender)
      (bond-id (var-get next-bond-id))
      (issue-block block-height)
      (maturity-block (unwrap! (safe-add block-height maturity-blocks) (err ERR_OVERFLOW)))
      (bond-status BOND_STATUS_ACTIVE)
    )
    ;; Input validation with safe math
    (asserts! (>= principal-amount MIN_BOND_AMOUNT) (err ERR_INVALID_AMOUNT))
    (asserts! (<= principal-amount MAX_BOND_AMOUNT) (err ERR_INVALID_AMOUNT))
    (asserts! (>= maturity-blocks MIN_BOND_DURATION) (err ERR_INVALID_TERMS))
    (asserts! (<= maturity-blocks MAX_BOND_DURATION) (err ERR_INVALID_TERMS))
    (asserts! (>= coupon-rate u0) (err ERR_INVALID_TERMS))
    (asserts! (<= coupon-rate u5000) (err ERR_INVALID_TERMS))  ;; Max 50%
    (asserts! (not (is-eq collateral-amount u0)) (err ERR_INSUFFICIENT_COLLATERAL))

    ;; Calculate total payout to ensure no overflow
    (let ((total-payout (unwrap!
                          (safe-add principal-amount
                            (unwrap! (safe-mul principal-amount coupon-rate) (err ERR_OVERFLOW)))
                          (err ERR_OVERFLOW))))
      (asserts! (>= collateral-amount total-payout) (err ERR_INSUFFICIENT_COLLATERAL))

      ;; Transfer collateral from issuer
      (try! (contract-call? collateral-token transfer collateral-amount issuer (as-contract tx-sender) none))

      ;; Increment bond ID safely
      (var-set next-bond-id (unwrap! (safe-add bond-id u1) (err ERR_OVERFLOW)))

      ;; Deploy new bond token contract (simplified)
      (let ((bond-contract (try! (contract-call? .token-soft-launch deploy-contract))))

        ;; Save bond details
        (map-set bonds bond-id (tuple
          (issuer issuer)
          (principal-amount principal-amount)
          (coupon-rate coupon-rate)
          (issue-block issue-block)
          (maturity-block maturity-block)
          (collateral-amount collateral-amount)
          (collateral-token collateral-token)
          (status bond-status)
          (is-callable is-callable)
          (call-premium call-premium)
          (bond-contract bond-contract)
          (name name)
          (symbol symbol)
          (decimals decimals)
          (face-value face-value)
        ))

        (map-set bonds-by-contract bond-contract (tuple
          (issuer issuer)
          (principal-amount principal-amount)
          (coupon-rate coupon-rate)
          (issue-block issue-block)
          (maturity-block maturity-block)
          (collateral-amount collateral-amount)
          (collateral-token collateral-token)
          (status bond-status)
          (is-callable is-callable)
          (call-premium call-premium)
          (bond-contract bond-contract)
          (name name)
          (symbol symbol)
          (decimals decimals)
          (face-value face-value)
        ))

        ;; Emit event
        (emit-event "bond_created" (tuple
          (issuer issuer)
          (bond-id bond-id)
          (amount principal-amount)
          (timestamp block-height)
        ))

        (ok (tuple
          (bond-id bond-id)
          (bond-contract bond-contract)
          (maturity-block maturity-block)
        ))
      )
    )
  )
)

;; --- Bond Utility Functions ---
;; @desc Calculates the accrued interest for a given bond ID.
;; @param bond-id uint The ID of the bond.
;; @returns (response uint uint) Returns the accrued interest on success, or an error code.
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
;; @desc Redeems a matured bond, transferring principal and interest to the bond holder.
;; @param bond-id uint The ID of the bond to redeem.
;; @returns (response (tuple (principal uint) (interest uint) (total-payout uint)) uint) Returns payout details on success, or an error code.
(define-public (redeem-bond (bond-id uint))
  (let (
      (caller tx-sender)
      (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
      (current-block block-height)
    )
    ;; Check bond status and maturity
    (asserts! (is-eq (get status bond) BOND_STATUS_ACTIVE) (err "Bond not active"))
    (asserts! (>= current-block (get maturity-block bond)) (err "Bond not yet mature"))
    
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
      (match (contract-call? bond-contract redeem-bond bond-id)
        (ok result) (begin
          ;; Calculate available collateral (principal + interest)
          (let ((payout total-payout))
            ;; Transfer principal + interest to bond holder
            (try! (contract-call? collateral-token transfer 
                    payout 
                    (as-contract tx-sender) 
                    caller 
                    none))
            
            ;; Update bond status to matured
            (map-set bonds bond-id (merge bond (tuple
              (status BOND_STATUS_MATURED)
            )))
            
            (emit-event "bond_redeemed" (tuple
              (issuer caller)
              (bond-id bond-id)
              (amount payout)
              (timestamp block-height)
            ))
            
            (ok (tuple
              (principal principal)
              (interest interest)
              (total-payout payout)
            ))
          )
        )
        (err error) (err error)
      )
    ))
  )
)


;; @desc Reports a coupon payment made by the bond issuer.
;; @param bond-id uint The ID of the bond for which the coupon payment is made.
;; @param payment-amount uint The amount of the coupon payment.
;; @returns (response bool uint) Returns (ok true) on success, or an error code.
(define-public (report-coupon-payment (bond-id uint) (payment-amount uint))
  (let (
      (caller tx-sender)
      (bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND))
      (current-block block-height)
    )
    ;; Validate bond is active and not matured
    (asserts! (is-eq (get status bond) BOND_STATUS_ACTIVE) (err "Bond not active"))
    (asserts! (< current-block (get maturity-block bond)) (err "Bond already matured"))
    
    ;; Calculate expected coupon payment using safe math
    (let (
        (principal (get principal-amount bond))
        (coupon-rate (get coupon-rate bond))
        (expected-interest (unwrap! (safe-div (unwrap! (safe-mul principal coupon-rate) (err ERR_OVERFLOW)) u10000) (err ERR_OVERFLOW)))
      )
      (asserts! (>= payment-amount expected-interest) (err "Insufficient coupon payment"))
      
      ;; Ensure caller is the bond issuer
      (asserts! (is-eq caller (get issuer bond)) ERR_UNAUTHORIZED)
      
      ;; Transfer coupon payment from issuer to contract
      (try! (contract-call? (get collateral-token bond) transfer 
              payment-amount 
              caller 
              (as-contract tx-sender) 
              none))
      
      ;; Emit coupon payment event
      (emit-event "coupon_paid" (tuple
        (issuer caller)
        (bond-id bond-id)
        (amount payment-amount)
        (timestamp block-height)
      ))
      (ok true)
    )
  )
)

;; @desc Retrieves the current status of a bond.
;; @param bond-id uint The ID of the bond.
;; @returns (response (tuple (bond-id uint) (status (string-ascii 20)) (is-mature bool) (blocks-until-maturity uint) (current-block uint) (maturity-block uint)) uint) Returns bond status details on success, or an error code.
(define-read-only (get-bond-status (bond-id uint))
  (let ((bond (unwrap! (map-get? bonds bond-id) ERR_BOND_NOT_FOUND)))
    (ok (tuple
      (bond-id bond-id)
      (status (get status bond))
      (is-mature (>= block-height (get maturity-block bond)))
      (blocks-until-maturity (unwrap! (safe-sub (get maturity-block bond) block-height) (err ERR_UNDERFLOW)))
      (current-block block-height)
      (maturity-block (get maturity-block bond))
    ))
  )
)

;; @desc Retrieves the total number of bonds created.
;; @returns (response uint uint) Returns the total bond count on success.
(define-read-only (get-bond-count)
  (ok (var-get next-bond-id))
)

;; @desc Get all bond contract principals.
;; @returns (list (principal))
(define-read-only (get-all-bonds)
  (map-keys bonds-by-contract)
)

;; @desc Get bond details by bond ID.
;; @param bond-id The ID of the bond.
;; @returns (response (tuple
;;   (issuer principal)
;;   (principal-amount uint)
;;   (coupon-rate uint)
;;   (issue-block uint)
;;   (maturity-block uint)
;;   (collateral-amount uint)
;;   (collateral-token principal)
;;   (status (string-ascii 20))
;;   (is-callable bool)
;;   (call-premium uint)
;;   (bond-contract principal)
;;   (name (string-ascii 32))
;;   (symbol (string-ascii 10))
;;   (decimals uint)
;;   (face-value uint)
;; ) (err uint))
(define-read-only (get-bond (bond-id uint))
  (ok (unwrap! (map-get? bonds bond-id) (err ERR_BOND_NOT_FOUND))))

;; @desc Get bond details by bond contract principal.
;; @param bond-contract The principal of the bond contract.
;; @returns (response (tuple
;;   (issuer principal)
;;   (principal-amount uint)
;;   (coupon-rate uint)
;;   (issue-block uint)
;;   (maturity-block uint)
;;   (collateral-amount uint)
;;   (collateral-token principal)
;;   (status (string-ascii 20))
;;   (is-callable bool)
;;   (call-premium uint)
;;   (bond-contract principal)
;;   (name (string-ascii 32))
;;   (symbol (string-ascii 10))
;;   (decimals uint)
;;   (face-value uint)
;; ) (err uint))
(define-read-only (get-bond-details (bond-contract principal))
  (ok (unwrap! (map-get? bonds-by-contract bond-contract) (err ERR_BOND_NOT_FOUND)))
)

;; @desc Retrieves a paginated list of all bonds.
;; @param offset uint The starting index for the list.
;; @param limit uint The maximum number of bonds to return.
;; @returns (response (list (tuple (bond-id uint) ...)) uint) Returns a list of bond details on success, or an error code.
(define-read-only (list-bonds (offset uint) (limit uint))
  (let (
      (max-id (var-get next-bond-id))
    )
    (ok (fold (range offset (min (+ offset limit) max-id)) (list)
      (lambda (id acc)
        (match (map-get? bonds id)
          (some bond) (append acc (list (merge bond (tuple (bond-id id)))))
          none acc
        )
      )
    )))
)
