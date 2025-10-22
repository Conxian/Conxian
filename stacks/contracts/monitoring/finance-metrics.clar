;; finance-metrics.clar

;; Unified financial metrics (EBITDA, CAPEX, OPEX) tracking and reporting

;; Errors
(use-trait finance-metrics-trait .all-traits.finance-metrics-trait)
(impl-trait .all-traits.finance-metrics-trait)
(define-constant ERR_UNAUTHORIZED (err u900))
(define-constant ERR_INVALID_CATEGORY (err u901))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var writer-principal principal tx-sender)

;; Cumulative totals per module/category
(define-map cumulative { module-id: (string-ascii 32), category: (string-ascii 8) }
  { total: uint, last-updated: uint })

;; System-level totals (use module-id "SYSTEM")
(define-constant SYSTEM_MODULE "SYSTEM")
(define-constant CAT_EBITDA "EBITDA")
(define-constant CAT_CAPEX "CAPEX")
(define-constant CAT_OPEX "OPEX")

;; Admin: set writer principal
(define-public (set-writer-principal (new-writer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set writer-principal new-writer)
    (ok true)
  )
)

;; Internal: update cumulative totals for module/category and system
(define-private (record-metric (module-id (string-ascii 32)) (category (string-ascii 8)) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get writer-principal)) ERR_UNAUTHORIZED)
    
;; Update module-level cumulative
    (let (
      (key { module-id: module-id, category: category })
      (entry (map-get? cumulative key))
    )
      (let ((new-total (+ amount (default-to u0 (get total (default-to { total: u0, last-updated: u0 } (unwrap-panic entry)))))))
        (map-set cumulative key { total: new-total, last-updated: block-height })
      )
    )
    
;; Update system-level cumulative
    (let (
      (sys-key { module-id: SYSTEM_MODULE, category: category })
      (sys-entry (map-get? cumulative sys-key))
    )
      (let ((new-total (+ amount (default-to u0 (get total (default-to { total: u0, last-updated: u0 } (unwrap-panic sys-entry)))))))
        (map-set cumulative sys-key { total: new-total, last-updated: block-height })
      )
    )
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

;; Read-only aggregation: returns cumulative total (window currently not applied)
(define-read-only (get-aggregate (module-id (string-ascii 32)) (category (string-ascii 8)) (window uint))
  (let ((entry (map-get? cumulative { module-id: module-id, category: category })))
    (ok (default-to u0 (get total (default-to { total: u0, last-updated: u0 } (unwrap-panic entry)))))
  )
)

(define-read-only (get-system-finance-summary (window uint))
  (let (
    (ebitda (unwrap-panic (get-aggregate SYSTEM_MODULE CAT_EBITDA window)))
    (capex (unwrap-panic (get-aggregate SYSTEM_MODULE CAT_CAPEX window)))
    (opex (unwrap-panic (get-aggregate SYSTEM_MODULE CAT_OPEX window)))
  )
    (ok { ebitda: ebitda, capex: capex, opex: opex })
  )
)

;; Ownership management
(define-read-only (get-contract-owner) (ok (var-get contract-owner)))
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)