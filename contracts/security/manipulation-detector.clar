;; manipulation-detector.clar
;; Detects price manipulation in the Conxian DEX.

(use-trait oracle-aggregator-v2-trait .oracle-aggregator-v2.oracle-aggregator-v2-trait)
(use-trait math-lib-trait .math-lib.math-lib-trait)

(define-trait oracle-aggregator-v2-trait
  (
    (get-price (principal) (response uint uint))
  )
)

(define-trait math-lib-trait
  (
    (mean (list 100 uint)) (response uint uint))
    (std-dev (list 100 uint)) (response uint uint))
  )
)

(define-constant ERR_UNAUTHORIZED (err u4000))

(define-map price-history { asset: principal } (list 100 uint))

(define-public (report-price (asset principal) (price uint))
  (begin
    (asserts! (is-eq tx-sender (contract-of <oracle-aggregator-v2-trait>)) ERR_UNAUTHORIZED)
    (let ((history (default-to (list) (map-get? price-history { asset: asset }))))
      (map-set price-history { asset: asset } (prepend history price))
    )
    (ok true)
  )
)

(define-read-only (is-manipulated (asset principal))
  (let ((history (unwrap! (map-get? price-history { asset: asset }) (ok false)))
        (latest-price (unwrap! (contract-call? .oracle-aggregator-v2 get-price asset) (err u0))))
    (if (< (len history) u10)
      (ok false)
      (let ((mean (unwrap! (contract-call? .math-lib mean history) (err u0)))
            (std-dev (unwrap! (contract-call? .math-lib std-dev history) (err u0))))
        (ok (> (if (> latest-price mean) (- latest-price mean) (- mean latest-price)) (* u3 std-dev)))
      )
    )
  )
)
