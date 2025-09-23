;; Manipulation Detector
;; This contract detects price manipulation attempts using statistical analysis.

(use-trait circuit-breaker-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_INVALID_PRICE (err u7001))
(define-constant ERR_DEVIATION_TOO_HIGH (err u7002))
(define-constant ERR_CIRCUIT_BREAKER_TRIPPED (err u7003))

(define-data-var contract-owner principal tx-sender)
(define-data-var circuit-breaker (optional principal) none)

(define-map price-history { token-a: principal, token-b: principal, block: uint } { price: uint, volume: uint })
(define-map moving-average { token-a: principal, token-b: principal } { price: uint, period: uint })

(define-public (set-circuit-breaker (breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker (some breaker))
    (ok true)
  )
)

(define-public (check-price (token-a principal) (token-b principal) (price uint) (volume uint))
  (begin
    (try! (check-circuit-breaker))
    (let ((ma (get-moving-average token-a token-b u10)))
      (if (is-some ma)
        (let ((deviation (/ (* (abs (- (unwrap-panic ma) price)) u10000) (unwrap-panic ma))))
          (if (> deviation u1000)
            (begin
              (try! (trip-circuit-breaker))
              (err ERR_DEVIATION_TOO_HIGH)
            )
            (ok true)
          )
        )
        (ok true)
      )
    )
  )
)

(define-public (record-price (token-a principal) (token-b principal) (price uint) (volume uint))
  (map-set price-history { token-a: token-a, token-b: token-b, block: block-height } { price: price, volume: volume })
  (ok true)
)

(define-private (get-moving-average (token-a principal) (token-b principal) (period uint))
  (let ((prices (get-price-history token-a token-b period)))
    (if (> (len prices) u0)
      (some (/ (fold + prices u0) (len prices)))
      none
    )
  )
)

(define-private (get-price-history (token-a principal) (token-b principal) (period uint))
  (let ((current-block block-height))
    (fold (lambda (i acc)
      (match (map-get? price-history { token-a: token-a, token-b: token-b, block: (- current-block i) })
        (some data) (append acc (list (get price data)))
        (none) acc
      )
    ) (range period) (list))
  )
)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (some breaker) (asserts! (not (try! (contract-call? breaker is-tripped))) ERR_CIRCUIT_BREAKER_TRIPPED)
    none (ok true)
  )
)

(define-private (trip-circuit-breaker)
  (match (var-get circuit-breaker)
    (some breaker) (contract-call? breaker trip)
    none (ok true)
  )
)