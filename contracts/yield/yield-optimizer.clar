;; Yield Optimizer
;; Automated strategy selection and allocation
;; Manages yield strategies and allocates funds to the highest yielding safe strategy.

(use-trait vault-trait .defi-traits.vault-trait)

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_INVALID_STRATEGY (err u6001))
(define-constant ERR_NO_STRATEGY (err u6002))
(define-constant ERR_LOW_YIELD (err u6003))

(define-data-var contract-owner principal tx-sender)
(define-data-var best-strategy principal tx-sender)
(define-data-var max-risk-score uint u50) ;; Max allowed risk (0-100)

(define-map strategies
    { strategy: principal }
    { active: bool, apy: uint, risk-score: uint, total-allocated: uint }
)

;; --- Public Functions ---

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (set-max-risk (risk uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set max-risk-score risk)
        (ok true)
    )
)

(define-public (add-strategy (strategy principal) (apy uint) (risk uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (map-set strategies { strategy: strategy } { active: true, apy: apy, risk-score: risk, total-allocated: u0 })
        
        ;; Check if this is the new best strategy
        (unwrap-panic (check-and-update-best strategy apy risk))
        (ok true)
    )
)

(define-public (update-metrics (strategy principal) (apy uint) (risk uint))
    (let (
        (current (unwrap! (map-get? strategies { strategy: strategy }) ERR_INVALID_STRATEGY))
    )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED) ;; Only owner/keeper can update metrics
        (map-set strategies { strategy: strategy } (merge current { apy: apy, risk-score: risk }))
        
        (unwrap-panic (check-and-update-best strategy apy risk))
        (ok true)
    )
)

(define-public (optimize-allocation (vault <vault-trait>) (amount uint))
    (let (
        (target-strategy (var-get best-strategy))
        (current-alloc (unwrap! (map-get? strategies { strategy: target-strategy }) ERR_NO_STRATEGY))
    )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (asserts! (get active current-alloc) ERR_INVALID_STRATEGY)
        
        ;; Allocate funds to the best strategy via the vault
        ;; The vault must support `allocate-to-strategy`
        (try! (contract-call? vault allocate-to-strategy target-strategy amount))
        
        ;; Update tracking
        (map-set strategies { strategy: target-strategy } 
            (merge current-alloc { total-allocated: (+ (get total-allocated current-alloc) amount) }))
            
        (ok true)
    )
)

;; --- Private Functions ---

(define-private (check-and-update-best (candidate principal) (apy uint) (risk uint))
    (let (
        (current-best (var-get best-strategy))
        (current-stats (default-to { active: false, apy: u0, risk-score: u0, total-allocated: u0 } (map-get? strategies { strategy: current-best })))
    )
        ;; If candidate has better APY and acceptable risk, update best
        (if (and 
                (<= risk (var-get max-risk-score)) 
                (> apy (get apy current-stats))
            )
            (begin
                (var-set best-strategy candidate)
                (ok true)
            )
            (ok false)
        )
    )
)

;; --- Read-Only ---

(define-read-only (get-strategy (strategy principal))
    (map-get? strategies { strategy: strategy })
)

(define-read-only (get-best-strategy)
    (ok (var-get best-strategy))
)
