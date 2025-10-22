;; cxd-price-initializer.clar
;; Handles initial price setting and management for CXD token

(use-trait token-trait .all-traits.sip-010-ft-trait)
(use-trait governance-trait .all-traits.governance-token-trait)
(use-trait oracle-trait .all-traits.oracle-trait)

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
(define-data-var timelock-end-block (optional uint) none
(define-data-var cxd-token (optional principal) none)
(define-data-var oracle (optional principal) none)

;; Events
(define-event PriceInitialized (price:uint min-price:uint block:uint))
(define-event PriceUpdated (old-price:uint new-price:uint block:uint))
(define-event MinPriceUpdated (old-min-price:uint new-min-price:uint block:uint))

;; Initialization function - can only be called once
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
        (asserts! (is-eq caller (contract-call? .all-traits.ownable-trait get-owner)) ERR_UNAUTHORIZED)
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
(define-read-only (get-price)
    (let ((price (var-get initial-price)))
        (asserts! (is-some price) ERR_NOT_INITIALIZED)
        (ok (unwrap-panic price))
    )
)

;; Get minimum price
(define-read-only (get-min-price)
    (let ((min (var-get min-price)))
        (asserts! (is-some min) ERR_NOT_INITIALIZED)
        (ok (unwrap-panic min))
    )
)

;; Update price (governance function)
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
