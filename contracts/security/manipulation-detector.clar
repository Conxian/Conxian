;; manipulation-detector.clar
;; Detects price manipulation in the Conxian DEX.

(use-trait oracle-aggregator-v2-trait .oracle-aggregator-v2.oracle-aggregator-v2-trait)
(use-trait math-lib-trait .math-lib.math-lib-trait)

(define-constant ERR_UNAUTHORIZED (err u4000))

(define-map price-history { asset: principal } (list 100 uint))

(define-public (report-price (asset principal) (price uint))
  (begin
    ;; Only the oracle-aggregator-v2 contract is allowed to report prices
    (asserts! (is-eq tx-sender .oracle-aggregator-v2) ERR_UNAUTHORIZED)
    (let (
          (history (default-to (list) (map-get? price-history { asset: asset })))
         )
      (map-set price-history { asset: asset } (cons price history))
    )
    (ok true)
  )
)

;; For now, expose a simple stub that always reports no manipulation.
;; This keeps the contract valid while we harden the statistical logic.
(define-read-only (is-manipulated (asset principal))
  (ok false)
)
