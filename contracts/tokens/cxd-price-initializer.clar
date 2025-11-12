;; cxd-price-initializer.clar
;; Handles initial price setting and management for CXD token

(use-trait token-trait .sip-010-trait)
(use-trait governance-trait .governance-token-trait)
(use-trait oracle-trait .oracle-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_PRICE (err u1001))
(define-constant ERR_ALREADY_INITIALIZED (err u1002))
(define-constant ERR_NOT_INITIALIZED (err u1003))
(define-constant ERR_INVALID_TIMELOCK (err u1004))

;; Price precision (6 decimals)
(define-constant PRECISION u1000000)

;; Initial price parameters
(define-data-var is-initialized bool false)
(define-data-var initial-price (optional uint) none)
(define-data-var min-price (optional uint) none)
(define-data-var price-last-updated (optional uint) none)
(define-data-var timelock-end-block (optional uint) none)
(define-data-var cxd-token (optional principal) none)
(define-data-var oracle (optional principal) none)

;; Events
(define-event PriceInitialized (price uint) (min-price uint) (block uint))
(define-event PriceUpdated (old-price uint) (new-price uint) (block uint))
(define-event MinPriceUpdated (old-min-price uint) (new-min-price uint) (block uint))

;; Initialization function - can only be called once
;; @desc Initializes the CXD price initializer contract with initial price, minimum price, and timelock.
;; @param cxd-token-principal The principal of the CXD token contract.
;; @param oracle-principal The principal of the oracle contract for emergency updates.
;; @param initial-price-amount The initial price of the CXD token.
;; @param min-price-amount The minimum allowed price for the CXD token.
;; @param timelock-blocks The number of blocks for the timelock period.
;; @returns An `ok` response with a `PriceInitialized` event on success, or an error code on failure.
(define-public (initialize 
    (cxd-token-principal principal)
    (oracle-principal principal)
    (initial-price-amount uint)
    (min-price-amount uint)
    (timelock-blocks uint)
)
    (let (
        (caller tx-sender)
    )
        (asserts! (is-eq caller (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)
        (asserts! (> initial-price-amount u0) ERR_INVALID_PRICE)
        (asserts! (> min-price-amount u0) ERR_INVALID_PRICE)
        (asserts! (>= initial-price-amount min-price-amount) ERR_INVALID_PRICE)
        
        (var-set cxd-token (some cxd-token-principal))
        (var-set oracle (some oracle-principal))
        (var-set initial-price (some initial-price-amount))
        (var-set min-price (some min-price-amount))
        (var-set price-last-updated (some block-height))
        (var-set timelock-end-block (some (+ block-height timelock-blocks)))
        (var-set is-initialized true)
        
        (ok (print (PriceInitialized 
            { price: initial-price-amount, 
              min-price: min-price-amount, 
              block: block-height })))
    )
)

;; Get current price
;; Get current price
;; @desc Retrieves the current price of the CXD token.
;; @returns An `ok` response with the current price (uint) on success, or an error code if not initialized.
(define-read-only (get-price)
    (let ((price (var-get initial-price)))
        (asserts! (is-some price) ERR_NOT_INITIALIZED)
        (ok (unwrap-panic price))
    )
)

;; Get minimum price
;; @desc Retrieves the minimum allowed price for the CXD token.
;; @returns An `ok` response with the minimum price (uint) on success, or an error code if not initialized.
(define-read-only (get-min-price)
    (let ((min (var-get min-price)))
        (asserts! (is-some min) ERR_NOT_INITIALIZED)
        (ok (unwrap-panic min))
    )
)

;; Update price (governance function)
;; @desc Updates the current price of the CXD token. Can only be called by governance after the timelock.
;; @param new-price The new price to set for the CXD token.
;; @returns An `ok` response with a `PriceUpdated` event on success, or an error code on failure.
(define-public (update-price (new-price uint))
    (let (
        (caller tx-sender)
        (current-price (unwrap-panic (var-get initial-price)))
        (current-min (unwrap-panic (var-get min-price)))
        (timelock (unwrap-panic (var-get timelock-end-block)))
    )
        (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
        (asserts! (contract-call? .all-traits.governance-token-trait has-voting-power caller) ERR_UNAUTHORIZED)
        (asserts! (>= block-height timelock) (err (try! (as-max-len? (concat "Timelocked until block " (unwrap-panic (to-uint timelock))) u128))))
        (asserts! (>= new-price current-min) ERR_INVALID_PRICE)
        
        (var-set initial-price (some new-price))
        (var-set price-last-updated (some block-height))
        
        (ok (print (PriceUpdated { 
            old-price: current-price, 
            new-price: new-price, 
            block: block-height 
        })))
    )
)

;; Update minimum price (governance function)
;; @desc Updates the minimum allowed price for the CXD token. Can only be called by governance after the timelock.
;; @param new-min-price The new minimum price to set for the CXD token.
;; @returns An `ok` response with a `MinPriceUpdated` event on success, or an error code on failure.
(define-public (update-min-price (new-min-price uint))
    (let (
        (caller tx-sender)
        (current-price (unwrap-panic (var-get initial-price)))
        (current-min (unwrap-panic (var-get min-price)))
        (timelock (unwrap-panic (var-get timelock-end-block)))
    )
        (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
        (asserts! (contract-call? .all-traits.governance-token-trait has-voting-power caller) ERR_UNAUTHORIZED)
        (asserts! (>= block-height timelock) (err (try! (as-max-len? (concat "Timelocked until block " (unwrap-panic (to-uint timelock))) u128))))
        (asserts! (<= new-min-price current-price) ERR_INVALID_PRICE)
        
        (var-set min-price (some new-min-price))
        
        (ok (print (MinPriceUpdated { 
            old-min-price: current-min, 
            new-min-price: new-min-price, 
            block: block-height 
        })))
    )
)

;; Emergency price update (circuit breaker)
;; @desc Allows an authorized oracle to update the CXD token price in an emergency.
;; @param new-price The new price to set for the CXD token.
;; @returns An `ok` response with a `PriceUpdated` event on success, or an error code on failure.
(define-public (emergency-update-price (new-price uint))
    (let (
        (caller tx-sender)
        (current-price (unwrap-panic (var-get initial-price)))
        (current-min (unwrap-panic (var-get min-price)))
        (oracle-principal (unwrap-panic (var-get oracle)))
    )
        (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-eq caller oracle-principal) ERR_UNAUTHORIZED)
        (asserts! (>= new-price current-min) ERR_INVALID_PRICE)
        
        (var-set initial-price (some new-price))
        (var-set price-last-updated (some block-height))
        
        (ok (print (PriceUpdated { 
            old-price: current-price, 
            new-price: new-price, 
            block: block-height,
            emergency: true
        })))
    )
)

;; Get price with minimum check (for external contracts)
;; @desc Retrieves the current price, minimum price, and last updated block height.
;; @returns An `ok` response with a tuple containing `price`, `min-price`, and `last-updated` on success.
(define-read-only (get-price-with-minimum)
    (let (
        (price (unwrap-panic (var-get initial-price)))
        (min-price (unwrap-panic (var-get min-price)))
    )
        (ok {
            price: price,
            min-price: min-price,
            last-updated: (unwrap-panic (var-get price-last-updated))
        })
    )
)

;; Get initialization status
;; @desc Retrieves the current initialization status and all related parameters of the contract.
;; @returns An `ok` response with a tuple containing `is-initialized`, `cxd-token`, `oracle`, `initial-price`, `min-price`, `last-updated`, and `timelock-end` on success.
(define-read-only (get-initialization-status)
    (ok {
        is-initialized: (var-get is-initialized),
        cxd-token: (var-get cxd-token),
        oracle: (var-get oracle),
        initial-price: (var-get initial-price),
        min-price: (var-get min-price),
        last-updated: (var-get price-last-updated),
        timelock-end: (var-get timelock-end-block)
    })
)

