;; Oracle Aggregator V2
;; This contract aggregates prices from multiple oracle sources, calculates TWAP, and detects manipulation.

(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.oracle-trait)
(impl-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_INVALID_SOURCE (err u6001))
(define-constant ERR_NO_SOURCES (err u6002))
(define-constant ERR_INVALID_PRICE (err u6003))
(define-constant ERR_DEVIATION_TOO_HIGH (err u6004))
(define-constant ERR_CIRCUIT_OPEN (err u5000))

(define-constant ONE_HOUR_IN_BLOCKS u6)

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var circuit-breaker principal 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.circuit-breaker)
(define-map oracle-sources (list 20 principal) bool)
(define-map prices { token-a: principal, token-b: principal } { price: uint, last-updated: uint })
(define-map twap { token-a: principal, token-b: principal } { price: uint, last-updated: uint })

;; --- Public Functions ---

(define-public (add-oracle-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set oracle-sources (list source) true)
    (ok true)
  )
)

(define-public (remove-oracle-source (source principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete oracle-sources (list source))
    (ok true)
  )
)

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

(define-public (update-price (token-a principal) (token-b principal))
  (let ((sources (map-get? oracle-sources)))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-some sources) ERR_NO_SOURCES)
    (let ((prices (try! (get-prices-from-sources (unwrap-panic sources) token-a token-b))))
      (let ((median-price (try! (calculate-median prices))))
        (try! (check-deviation median-price token-a token-b))
        (map-set prices { token-a: token-a, token-b: token-b } { price: median-price, last-updated: block-height })
        (try! (update-twap median-price token-a token-b))
        (ok median-price)
      )
    )
  )
)

(define-read-only (get-price (token-a principal) (token-b principal))
  (ok (get price (unwrap! (map-get? prices { token-a: token-a, token-b: token-b }) (err ERR_INVALID_PRICE))))
)

(define-read-only (get-twap (token-a principal) (token-b principal))
  (ok (get price (unwrap! (map-get? twap { token-a: token-a, token-b: token-b }) (err ERR_INVALID_PRICE))))
)

;; --- Private Helper Functions ---

(define-private (check-circuit-breaker)
  (contract-call? (var-get circuit-breaker) is-circuit-open)
)

(define-private (get-prices-from-sources (sources (list 20 principal)) (token-a principal) (token-b principal))
  (ok (fold (lambda (source acc)
    (match (contract-call? source get-price token-a token-b)
      (success price) (append acc (list price))
      (error error-code) acc
    )
  ) sources (list)))
)

(define-private (calculate-median (prices (list 20 uint)))
  (let ((sorted (sort < prices)))
    (let ((len (len sorted)))
      (if (is-eq (mod len u2) u1)
        (ok (unwrap-panic (element-at sorted (/ (- len u1) u2))))
        (ok (/ (+ (unwrap-panic (element-at sorted (/ len u2))) (unwrap-panic (element-at sorted (- (/ len u2) u1)))) u2))
      )
    )
  )
)

(define-private (check-deviation (new-price uint) (token-a principal) (token-b principal))
  (match (map-get? prices { token-a: token-a, token-b: token-b })
    (some price-data) (let ((old-price (get price price-data)))
      (let ((deviation (/ (* (abs (- old-price new-price)) u10000) old-price)))
        (asserts! (< deviation u500) ERR_DEVIATION_TOO_HIGH)
        (ok true)
      )
    )
    (none) (ok true)
  )
)

(define-private (update-twap (new-price uint) (token-a principal) (token-b principal))
  (let ((current-twap (map-get? twap { token-a: token-a, token-b: token-b })))
    (if (is-some current-twap)
      (let ((old-twap (get price (unwrap-panic current-twap)))
            (last-updated (get last-updated (unwrap-panic current-twap))))
        (let ((time-diff (- block-height last-updated)))
          (if (> time-diff ONE_HOUR_IN_BLOCKS)
            (map-set twap { token-a: token-a, token-b: token-b } { price: new-price, last-updated: block-height })
            (let ((new-twap (/ (+ (* old-twap (- ONE_HOUR_IN_BLOCKS time-diff)) (* new-price time-diff)) ONE_HOUR_IN_BLOCKS)))
              (map-set twap { token-a: token-a, token-b: token-b } { price: new-twap, last-updated: block-height })
            )
          )
        )
      )
      (map-set twap { token-a: token-a, token-b: token-b } { price: new-price, last-updated: block-height })
    )
    (ok true)
  )
)