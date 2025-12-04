
;; Oracle Mock for Testing
(define-trait oracle-trait
  (
    (get-price (principal) (response uint uint))
    (get-historical-price (principal uint) (response uint uint))
  )
)

(define-data-var last-price uint u100000000)

(define-read-only (get-price (asset principal))
  (ok (var-get last-price))
)

(define-read-only (get-historical-price (asset principal) (blocks uint))
  (ok (var-get last-price))
)

(define-public (set-price (price uint))
  (begin
    (var-set last-price price)
    (ok true)
  )
)
