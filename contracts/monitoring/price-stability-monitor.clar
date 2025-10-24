;; price-stability-monitor.clar
;; Monitors price stability and suggests parameter adjustments

(use-trait price-initializer-trait .all-traits.price-initializer-trait)
(use-trait amm-trait .all-traits.amm-trait)
(use-trait governance-trait .all-traits.governance-token-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_INTERVAL (err u1001))
(define-constant ERR_NOT_READY (err u1002))

;; Configuration
(define-constant PRICE_DEVIATION_THRESHOLD u50000)  ;; 5%
(define-constant VOLATILITY_WINDOW u100)            ;; ~1 day
(define-constant ADJUSTMENT_COOLDOWN u144)          ;; ~1 day

;; State
(define-data-var is-initialized bool false)
(define-data-var price-initializer (optional principal) none)
(define-data-var amm-contract (optional principal) none)
(define-data-var last-adjustment-block uint u0)
(define-data-var last-price uint u0)
(define-data-var price-history (list 100 uint) (list))
(define-data-var volatility-history (list 20 uint) (list))

;; Events
(define-event PriceDeviation (current: uint, average: uint, deviation: uint, block: uint))
(define-event ParameterAdjustment (parameter: (string-ascii 32), old-value: uint, new-value: uint, reason: (string-ascii 128)))

;; ===== Initialization =====

(define-public (initialize (price-initializer-principal principal) (amm-principal principal))
    (let ((caller tx-sender))
        (asserts! (is-eq caller (contract-call? .all-traits.ownable-trait get-owner)) ERR_UNAUTHORIZED)
        (asserts! (not (var-get is-initialized)) ERR_ALREADY_INITIALIZED)
        
        (var-set price-initializer (some price-initializer-principal))
        (var-set amm-contract (some amm-principal))
        (var-set is-initialized true)
        
        (ok true)
    )
)

;; ===== Core Monitoring =====

(define-public (check-price-stability)
    (let (
        (caller tx-sender)
        (initialized (var-get is-initialized))
        (price-init (unwrap-panic (var-get price-initializer)))
        (amm (unwrap-panic (var-get amm-contract)))
    )
        (asserts! initialized ERR_NOT_INITIALIZED)
        
        ;; Get current price data
        (let* (
            (price-data (unwrap-panic (contract-call? price-init get-price-with-minimum)))
            (current-price (get price-data 'price))
            (min-price (get price-data 'min-price))
            (last-block (get price-data 'last-updated))
            
            ;; Calculate price statistics
            (history (var-get price-history))
            (history-length (len history))
            (average-price (if (> history-length 0) (/ (fold sum-uint history u0) history-length) current-price))
            (deviation (abs (- current-price average-price)))
            (deviation-bps (/ (* deviation 10000) average-price))
        )
            ;; Update price history
            (var-set price-history (append-capped history current-price u100))
            
            ;; Check for significant deviation
            (when (> deviation-bps PRICE_DEVIATION_THRESHOLD)
                (print (PriceDeviation {
                    current: current-price,
                    average: average-price,
                    deviation: deviation-bps,
                    block: block-height
                }))
                
                ;; Suggest parameter adjustment if needed
                (try! (suggest-parameter-adjustment current-price average-price min-price))
            )
            
            ;; Update volatility metrics
            (when (> history-length 1)
                (let* (
                    (price-change (abs (- current-price last-price)))
                    (volatility (/ (* price-change PRECISION) last-price))
                )
                    (var-set volatility-history (append-capped (var-get volatility-history) volatility u20))
                )
            )
            
            (var-set last-price current-price)
            
            (ok {
                current-price: current-price,
                average-price: average-price,
                price-deviation: deviation-bps,
                min-price: min-price,
                last-updated: last-block,
                volatility: (if (> (len (var-get volatility-history)) 0) 
                    (/ (fold sum-uint (var-get volatility-history) u0) (len (var-get volatility-history)))
                    u0)
            })
        )
    )
)

;; ===== Parameter Adjustment Logic =====

(define-private (suggest-parameter-adjustment (current uint) (average uint) (min-price uint))
    (let (
        (amm (unwrap-panic (var-get amm-contract)))
        (price-init (unwrap-panic (var-get price-initializer)))
        (deviation (/ (* (abs (- current average)) 10000) average))
        (current-fee (unwrap-panic (contract-call? amm get-fee-rate)))
        (cooldown-over (>= (- block-height (var-get last-adjustment-block)) ADJUSTMENT_COOLDOWN))
    )
        (when (and (> deviation PRICE_DEVIATION_THRESHOLD) cooldown-over)
            (if (> current average)
                ;; Price is above average - consider increasing fees or minimum price
                (let (
                    (new-min-price (+ min-price (/ (* min-price 500) 10000)))  ;; +5%
                )
                    (print (ParameterAdjustment {
                        parameter: "min-price",
                        old-value: min-price,
                        new-value: new-min-price,
                        reason: "Price above average, increasing price floor"
                    }))
                    
                    ;; In a real implementation, this would be a governance proposal
                    (contract-call? price-init propose-min-price-update new-min-price)
                )
                
                ;; Price is below average - consider decreasing fees or providing incentives
                (let (
                    (new-fee (max u1000 (- current-fee 500)))  ;; -0.5% fee, min 0.1%
                )
                    (when (< new-fee current-fee)
                        (print (ParameterAdjustment {
                            parameter: "fee-rate",
                            old-value: current-fee,
                            new-value: new-fee,
                            reason: "Price below average, reducing fees to encourage trading"
                        }))
                        
                        ;; In a real implementation, this would be a governance proposal
                        (contract-call? amm propose-fee-update new-fee)
                    )
                )
            )
            
            (var-set last-adjustment-block block-height)
            (ok true)
        )
        (ok false)
    )
)

;; ===== Utility Functions =====

(define-private (sum-uint (a uint) (b uint)) (+ a b))

(define-private (append-capped (xs (list 100 uint)) (x uint) (cap uint))
    (let ((n (len xs)))
        (if (< n cap)
            (unwrap-panic (as-max-len? (append xs x) cap))
            (let ((tail (unwrap-panic (slice? xs u1 n))))
                (unwrap-panic (as-max-len? (append tail x) cap))
            )
        )
    )
)

;; ===== View Functions =====

(define-read-only (get-price-statistics)
    (let (
        (history (var-get price-history))
        (volatility (var-get volatility-history))
        (n (len history))
    )
        (ok {
            current-price: (if (> n 0) (element-at history (- n 1)) u0),
            average-price: (if (> n 0) (/ (fold sum-uint history u0) n) u0),
            min-24h: (if (> n 0) (fold min-uint (unwrap-panic (slice? history 0 n)) MAX_UINT) u0),
            max-24h: (if (> n 0) (fold max-uint (unwrap-panic (slice? history 0 n)) u0) u0),
            volatility: (if (> (len volatility) 0) 
                (/ (fold sum-uint volatility u0) (len volatility))
                u0),
            last-updated: block-height
        })
    )
)

(define-read-only (get-min-uint (a uint) (b uint)) (if (< a b) a b))
(define-read-only (get-max-uint (a uint) (b uint)) (if (> a b) a b))
