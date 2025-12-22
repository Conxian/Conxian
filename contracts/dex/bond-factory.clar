;; bond-factory.clar
;; Factory contract for creating and managing bond tokens
(use-trait bond-factory-trait .bond-traits.bond-factory-trait)
(impl-trait .bond-traits.bond-factory-trait)
;; (use-trait pool-factory-trait .defi-traits.pool-factory-trait) ;; Disabled until trait definition matches
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

;; --- Enhanced Maturity Periods: TradFi + DeFi + Innovation ---
;; Based on Stacks Nakamoto Block Time (~5 seconds)
;; 1 day = 86400 seconds / 5 = 17280 blocks
(define-constant BLOCKS_PER_DAY u2073600)
(define-constant BLOCKS_PER_YEAR u756864000) ;; 365 * 17280

;; DeFi Ultra-Short (Flash Bonds) - High frequency / Intraday
(define-constant MATURITY_FLASH u720)          ;; ~1 hour (720 blocks)
(define-constant MATURITY_4_HOURS u2880)       ;; ~4 hours
(define-constant MATURITY_12_HOURS u8640)      ;; ~12 hours
(define-constant MATURITY_ULTRA_SHORT u120960) ;; ~1 week (7 days)

;; TradFi Short-Term (Money Market equivalent)
(define-constant MATURITY_30_DAYS u518400)     ;; ~30 days
(define-constant MATURITY_90_DAYS u1555200)    ;; ~90 days
(define-constant MATURITY_180_DAYS u3110400)   ;; ~180 days

;; TradFi Medium-Term (Notes)
(define-constant MATURITY_1_YEAR u6307200)     ;; ~1 year
(define-constant MATURITY_2_YEARS u12614400)   ;; ~2 years
(define-constant MATURITY_3_YEARS u18921600)   ;; ~3 years
(define-constant MATURITY_5_YEARS u31536000)   ;; ~5 years

;; TradFi Long-Term (Traditional Bonds)
(define-constant MATURITY_7_YEARS u44150400)   ;; ~7 years
(define-constant MATURITY_10_YEARS u63072000)  ;; ~10 years
(define-constant MATURITY_20_YEARS u126144000) ;; ~20 years
(define-constant MATURITY_30_YEARS u189216000) ;; ~30 years

;; Innovation: Perpetual & Algorithmic
(define-constant MATURITY_PERPETUAL u0)        ;; Perpetual bonds (no fixed maturity, callable only)
(define-constant MATURITY_ALGORITHMIC u1)      ;; Dynamic maturity based on on-chain conditions

;; @desc Minimum bond duration in blocks (~1 hour for flash bonds).
(define-constant MIN_BOND_DURATION u86400)
;; @desc Maximum bond duration in blocks (~30 years).
(define-constant MAX_BOND_DURATION u22705920000)
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
      (maturity-block (if (is-eq maturity-blocks MATURITY_PERPETUAL)
                         u0  ;; Perpetual bonds have no maturity block
                         (unwrap! (safe-add block-height maturity-blocks) (err ERR_OVERFLOW))))
      (bond-status BOND_STATUS_ACTIVE)
    )
    ;; Input validation with safe math
    (asserts! (>= principal-amount MIN_BOND_AMOUNT) (err ERR_INVALID_AMOUNT))
    (asserts! (<= principal-amount MAX_BOND_AMOUNT) (err ERR_INVALID_AMOUNT))
    
    ;; Validate maturity: allow perpetual (u0), algorithmic (u1), or standard ranges
    (asserts! (or 
                (is-eq maturity-blocks MATURITY_PERPETUAL)
                (is-eq maturity-blocks MATURITY_ALGORITHMIC)
                (and (>= maturity-blocks MIN_BOND_DURATION) 
                     (<= maturity-blocks MAX_BOND_DURATION)))
              (err ERR_INVALID_TERMS))
    
    (asserts! (>= coupon-rate u0) (err ERR_INVALID_TERMS))
    
    ;; Register bond
    (map-set bonds bond-id {
      issuer: issuer,
      principal-amount: principal-amount,
      coupon-rate: coupon-rate,
      issue-block: issue-block,
      maturity-block: maturity-block,
      collateral-amount: collateral-amount,
      collateral-token: collateral-token,
      status: BOND_STATUS_ACTIVE,
      is-callable: is-callable,
      call-premium: call-premium,
      bond-contract: tx-sender, ;; Placeholder: Dynamic deployment requires deployer trait
      name: name,
      symbol: symbol,
      decimals: decimals,
      face-value: face-value
    })

    (var-set next-bond-id (+ bond-id u1))

    (let ((event-data {
      issuer: issuer,
      bond-id: bond-id,
      amount: principal-amount,
      timestamp: block-height
    }))
      (emit-event "bond_created" event-data)
    )

    (ok {
      bond-id: bond-id,
      bond-contract: tx-sender,
      maturity-block: maturity-block
    })
  )
)

(define-read-only (get-bond-details (bond-id uint))
  (ok (unwrap! (map-get? bonds bond-id) (err ERR_BOND_NOT_FOUND)))
)
