;; @desc Handles initial price setting and management for the CXD token.
;; This contract is responsible for initializing the price of the CXD token,
;; and provides functions for updating the price through governance or in an emergency.

(use-trait token-trait .traits.sip-010-ft-trait.sip-010-ft-trait)
(use-trait governance-trait .traits.governance-token-trait.governance-token-trait)
(use-trait oracle-trait .traits.oracle-aggregator-v2-trait.oracle-aggregator-v2-trait)

;; @constants
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED (err u1001))
;; @var ERR_INVALID_PRICE: The provided price is invalid.
(define-constant ERR_INVALID_PRICE (err u5001))
;; @var ERR_ALREADY_INITIALIZED: The contract has already been initialized.
(define-constant ERR_ALREADY_INITIALIZED (err u1006))
;; @var ERR_NOT_INITIALIZED: The contract has not yet been initialized.
(define-constant ERR_NOT_INITIALIZED (err u1007))
;; @var ERR_INVALID_TIMELOCK: The timelock has not yet expired.
(define-constant ERR_INVALID_TIMELOCK (err u6006))
;; @var PRECISION: The precision used for price calculations (6 decimals).
(define-constant PRECISION u1000000)

;; @data-vars
;; @var is-initialized: A boolean indicating if the contract has been initialized.
(define-data-var is-initialized bool false)
;; @var initial-price: The initial price of the CXD token.
(define-data-var initial-price (optional uint) none)
;; @var min-price: The minimum allowed price for the CXD token.
(define-data-var min-price (optional uint) none)
;; @var price-last-updated: The block height at which the price was last updated.
(define-data-var price-last-updated (optional uint) none)
;; @var timelock-end-block: The block height at which the timelock expires.
(define-data-var timelock-end-block (optional uint) none)
;; @var cxd-token: The principal of the CXD token contract.
(define-data-var cxd-token (optional principal) none)
;; @var oracle: The principal of the oracle contract for emergency updates.
(define-data-var oracle (optional principal) none)

;; @events
;; @var PriceInitialized: Emitted when the price is initialized.
(define-event PriceInitialized { price: uint, min-price: uint, block: uint })
;; @var PriceUpdated: Emitted when the price is updated.
(define-event PriceUpdated { old-price: uint, new-price: uint, block: uint, emergency: bool })
;; @var MinPriceUpdated: Emitted when the minimum price is updated.
(define-event MinPriceUpdated { old-min-price: uint, new-min-price: uint, block: uint })

;; @desc Initializes the CXD price initializer contract with an initial price, minimum price, and timelock.
;; @param cxd-token-principal: The principal of the CXD token contract.
;; @param oracle-principal: The principal of the oracle contract for emergency updates.
;; @param initial-price-amount: The initial price of the CXD token.
;; @param min-price-amount: The minimum allowed price for the CXD token.
;; @param timelock-blocks: The number of blocks for the timelock period.
;; @returns (response (tuple) uint): An `ok` response with a `PriceInitialized` event on success, or an error code on failure.
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

;; @desc Retrieves the current price of the CXD token.
;; @returns (response uint uint): An `ok` response with the current price on success, or an error code if not initialized.
(define-read-only (get-price)
    (let ((price (var-get initial-price)))
        (asserts! (is-some price) ERR_NOT_INITIALIZED)
        (ok (unwrap-panic price))
    )
)

;; @desc Retrieves the minimum allowed price for the CXD token.
;; @returns (response uint uint): An `ok` response with the minimum price on success, or an error code if not initialized.
(define-read-only (get-min-price)
    (let ((min (var-get min-price)))
        (asserts! (is-some min) ERR_NOT_INITIALIZED)
        (ok (unwrap-panic min))
    )
)

;; @desc Updates the current price of the CXD token. Can only be called by governance after the timelock.
;; @param new-price: The new price to set for the CXD token.
;; @returns (response (tuple) uint): An `ok` response with a `PriceUpdated` event on success, or an error code on failure.
(define-public (update-price (new-price uint))
    (let (
        (caller tx-sender)
        (current-price (unwrap-panic (var-get initial-price)))
        (current-min (unwrap-panic (var-get min-price)))
        (timelock (unwrap-panic (var-get timelock-end-block)))
    )
        (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-ok (contract-call? .governance-token-trait get-voting-power caller)) ERR_UNAUTHORIZED)
        (asserts! (>= block-height timelock) ERR_INVALID_TIMELOCK)
        (asserts! (>= new-price current-min) ERR_INVALID_PRICE)
        
        (var-set initial-price (some new-price))
        (var-set price-last-updated (some block-height))
        
        (ok (print (PriceUpdated { 
            old-price: current-price, 
            new-price: new-price, 
            block: block-height,
            emergency: false
        })))
    )
)

;; @desc Updates the minimum allowed price for the CXD token. Can only be called by governance after the timelock.
;; @param new-min-price: The new minimum price to set for the CXD token.
;; @returns (response (tuple) uint): An `ok` response with a `MinPriceUpdated` event on success, or an error code on failure.
(define-public (update-min-price (new-min-price uint))
    (let (
        (caller tx-sender)
        (current-price (unwrap-panic (var-get initial-price)))
        (current-min (unwrap-panic (var-get min-price)))
        (timelock (unwrap-panic (var-get timelock-end-block)))
    )
        (asserts! (var-get is-initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-ok (contract-call? .governance-token-trait get-voting-power caller)) ERR_UNAUTHORIZED)
        (asserts! (>= block-height timelock) ERR_INVALID_TIMELOCK)
        (asserts! (<= new-min-price current-price) ERR_INVALID_PRICE)
        
        (var-set min-price (some new-min-price))
        
        (ok (print (MinPriceUpdated { 
            old-min-price: current-min, 
            new-min-price: new-min-price, 
            block: block-height 
        })))
    )
)

;; @desc Allows an authorized oracle to update the CXD token price in an emergency.
;; @param new-price: The new price to set for the CXD token.
;; @returns (response (tuple) uint): An `ok` response with a `PriceUpdated` event on success, or an error code on failure.
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

;; @desc Retrieves the current price, minimum price, and last updated block height.
;; @returns (response { ... } uint): An `ok` response with a tuple containing `price`, `min-price`, and `last-updated` on success.
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

;; @desc Retrieves the current initialization status and all related parameters of the contract.
;; @returns (response { ... } uint): An `ok` response with a tuple containing `is-initialized`, `cxd-token`, `oracle`, `initial-price`, `min-price`, `last-updated`, and `timelock-end` on success.
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
