;; block-automation-manager.clar
;; Stacks native block-based automation system
;; Replaces custom keeper coordinator with block-anchored operations

(define-constant ERR_NOT_READY (err u6000))
(define-constant ERR_UNAUTHORIZED (err u6001))

;; Block-based timing constants (5-second blocks)
(define-constant BLOCKS_PER_HOUR u720)
(define-constant BLOCKS_PER_DAY u17280)
(define-constant BLOCKS_PER_WEEK u120960)

;; Operation tracking
(define-data-var last-interest-accrual uint u0)
(define-data-var last-fee-distribution uint u0)
(define-data-var last-liquidation-check uint u0)
(define-data-var last-metrics-update uint u0)
(define-data-var last-epoch-transition uint u0)

;; Authorized operators (no bonding needed - use native STX stacking)
(define-data-var authorized-operators (list 20 principal) (list))

;; Authorization using native address checks
(define-private (is-authorized-operator)
  (is-some (index-of (var-get authorized-operators) tx-sender))
)

;; Add operator (owner only)
(define-public (add-operator (operator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set authorized-operators
      (unwrap-panic (as-max-len? (append (var-get authorized-operators) operator) u20))
    )
    (ok true)
  )
)

;; Interest Accrual - runs daily
(define-public (process-daily-interest-accrual)
  (begin
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (>= (- block-height (var-get last-interest-accrual)) BLOCKS_PER_DAY) ERR_NOT_READY)
    
    ;; Process interest for all lending positions
    (try! (contract-call? .comprehensive-lending-system accrue-interest-all))
    
    (var-set last-interest-accrual block-height)
    (print {event: "interest-accrual-processed", block: block-height})
    (ok true)
  )
)

;; Fee Distribution - runs every 6 hours
(define-public (process-fee-distribution)
  (begin
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (>= (- block-height (var-get last-fee-distribution)) (* BLOCKS_PER_HOUR u6)) ERR_NOT_READY)
    
    ;; Distribute accumulated protocol fees
    (try! (contract-call? .protocol-fee-switch distribute-fees))
    
    (var-set last-fee-distribution block-height)
    (print {event: "fee-distribution-processed", block: block-height})
    (ok true)
  )
)

;; Liquidation Check - runs hourly
(define-public (process-liquidation-check)
  (begin
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (>= (- block-height (var-get last-liquidation-check)) BLOCKS_PER_HOUR) ERR_NOT_READY)
    
    ;; Check and process liquidations
    (try! (contract-call? .liquidation-manager check-liquidations))
    
    (var-set last-liquidation-check block-height)
    (print {event: "liquidation-check-processed", block: block-height})
    (ok true)
  )
)

;; Metrics Update - runs daily
(define-public (process-daily-metrics)
  (begin
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (>= (- block-height (var-get last-metrics-update)) BLOCKS_PER_DAY) ERR_NOT_READY)
    
    ;; Update protocol metrics
    (try! (contract-call? .analytics-aggregator update-daily-metrics))
    
    (var-set last-metrics-update block-height)
    (print {event: "metrics-updated", block: block-height})
    (ok true)
  )
)

;; Epoch Transition - runs weekly
(define-public (process-weekly-epoch)
  (begin
    (asserts! (is-authorized-operator) ERR_UNAUTHORIZED)
    (asserts! (>= (- block-height (var-get last-epoch-transition)) BLOCKS_PER_WEEK) ERR_NOT_READY)
    
    ;; Process epoch transition
    (try! (contract-call? .gamification-manager finalize-epoch))
    (try! (contract-call? .gamification-manager initialize-epoch 
            (+ (var-get last-epoch-transition) BLOCKS_PER_WEEK) 
            block-height 
            (+ block-height BLOCKS_PER_DAY) 
            u45833 
            u45833))
    
    (var-set last-epoch-transition block-height)
    (print {event: "epoch-transition-processed", block: block-height})
    (ok true)
  )
)

;; Read-only views for operation status
(define-read-only (get-next-operations)
  {
    interest-accrual-ready: (>= (- block-height (var-get last-interest-accrual)) BLOCKS_PER_DAY),
    fee-distribution-ready: (>= (- block-height (var-get last-fee-distribution)) (* BLOCKS_PER_HOUR u6)),
    liquidation-check-ready: (>= (- block-height (var-get last-liquidation-check)) BLOCKS_PER_HOUR),
    metrics-update-ready: (>= (- block-height (var-get last-metrics-update)) BLOCKS_PER_DAY),
    epoch-transition-ready: (>= (- block-height (var-get last-epoch-transition)) BLOCKS_PER_WEEK),
  }
)

(define-read-only (get-operation-status)
  {
    last-interest-accrual: (var-get last-interest-accrual),
    last-fee-distribution: (var-get last-fee-distribution),
    last-liquidation-check: (var-get last-liquidation-check),
    last-metrics-update: (var-get last-metrics-update),
    last-epoch-transition: (var-get last-epoch-transition),
    current-block: block-height,
  }
)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
