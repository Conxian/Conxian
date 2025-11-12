;; finance-metrics.clar
;; Unified financial metrics (EBITDA, CAPEX, OPEX) tracking and reporting

(use-trait finance-metrics-trait .finance-metrics-trait.finance-metrics-trait)
(impl-trait .finance-metrics-trait.finance-metrics-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u900))
(define-constant ERR_INVALID_CATEGORY (err u901))

(define-constant SYSTEM_MODULE "SYSTEM")
(define-constant CAT_EBITDA "EBITDA")
(define-constant CAT_CAPEX "CAPEX")
(define-constant CAT_OPEX "OPEX")

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var writer-principal principal tx-sender)

;; ===== Data Maps =====
(define-map cumulative 
  { module-id: (string-ascii 32), category: (string-ascii 8) }
  { total: uint, last-updated: uint }
)

;; ===== Private Functions =====
(define-private (get-cumulative-total (module-id (string-ascii 32)) (category (string-ascii 8)))
  (get total 
    (default-to { total: u0, last-updated: u0 } 
      (map-get? cumulative { module-id: module-id, category: category })
    )
  )
)

(define-private (update-cumulative (module-id (string-ascii 32)) (category (string-ascii 8)) (amount uint))
  (let (
    (key { module-id: module-id, category: category })
    (current-total (get-cumulative-total module-id category))
    (new-total (+ current-total amount))
  )
(map-set cumulative key { total: new-total, last-updated: (contract-call? .block-utils get-burn-height) })
    true
  )
)

(define-private (record-metric (module-id (string-ascii 32)) (category (string-ascii 8)) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) ERR_UNAUTHORIZED)
    
    ;; Update module-level cumulative
    (update-cumulative module-id category amount)
    
    ;; Update system-level cumulative
    (update-cumulative SYSTEM_MODULE category amount)
    
    (ok true)
  )
)

;; ===== Public Functions =====
(define-public (set-writer-principal (new-writer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set writer-principal new-writer)
    (ok true)
  )
)

(define-public (record-ebitda (module-id (string-ascii 32)) (amount uint))
  (record-metric module-id CAT_EBITDA amount)
)

(define-public (record-capex (module-id (string-ascii 32)) (amount uint))
  (record-metric module-id CAT_CAPEX amount)
)

(define-public (record-opex (module-id (string-ascii 32)) (amount uint))
  (record-metric module-id CAT_OPEX amount)
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-aggregate (module-id (string-ascii 32)) (category (string-ascii 8)) (window uint))
  (ok (get-cumulative-total module-id category))
)

(define-read-only (get-system-finance-summary (window uint))
  (ok {
    ebitda: (get-cumulative-total SYSTEM_MODULE CAT_EBITDA),
    capex: (get-cumulative-total SYSTEM_MODULE CAT_CAPEX),
    opex: (get-cumulative-total SYSTEM_MODULE CAT_OPEX)
  })
)

(define-read-only (get-contract-owner) 
  (ok (var-get contract-owner))
)
