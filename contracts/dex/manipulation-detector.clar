

;; Manipulation Detector

;; This contract detects price manipulation attempts using statistical analysis.

;; --- Constants ---
;; @constant ERR_UNAUTHORIZED (err u1003) - Returned when the caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED (err u1003))
;; @constant ERR_INVALID_PRICE (err u7001) - Returned when an invalid price is provided.
(define-constant ERR_INVALID_PRICE (err u7001))
;; @constant ERR_DEVIATION_TOO_HIGH (err u7002) - Returned when the price deviation exceeds the allowed threshold.
(define-constant ERR_DEVIATION_TOO_HIGH (err u7002))
;; @constant ERR_CIRCUIT_BREAKER_TRIPPED (err u7003) - Returned when the circuit breaker is tripped.
(define-constant ERR_CIRCUIT_BREAKER_TRIPPED (err u7003))

;; --- Data Variables ---
;; @var contract-owner principal - The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var circuit-breaker (optional principal) - The principal of the circuit breaker contract, if set.
(define-data-var circuit-breaker (optional principal) none)

;; --- Data Maps ---
;; @map price-history { token-a: principal, token-b: principal, block: uint } { price: uint, volume: uint }
;; Stores historical price and volume data for token pairs.
(define-map price-history { token-a: principal, token-b: principal, block: uint } { price: uint, volume: uint })
;; @map moving-average { token-a: principal, token-b: principal } { price: uint, period: uint }
;; Stores the calculated moving average for token pairs.
(define-map moving-average { token-a: principal, token-b: principal } { price: uint, period: uint })

;; --- Public Functions ---

;; @desc Sets the circuit breaker contract principal. Only callable by the contract owner.
;; @param breaker principal - The principal of the circuit breaker contract.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the owner.
;; @events (print (ok true))
(define-public (set-circuit-breaker (breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker (some breaker))
    (ok true)
  )
)

;; @desc Checks a given price against the moving average to detect manipulation.
;; @param token-a principal - The principal of the first token.
;; @param token-b principal - The principal of the second token.
;; @param price uint - The current price to check.
;; @param volume uint - The volume associated with the current price.
;; @returns (response bool uint) - (ok true) if no manipulation is detected, (err ERR_DEVIATION_TOO_HIGH) if deviation is too high, or (err ERR_CIRCUIT_BREAKER_TRIPPED) if the circuit breaker is tripped.
;; @events (print (ok true)) (print (err ERR_DEVIATION_TOO_HIGH))
(define-public (check-price (token-a principal) (token-b principal) (price uint) (volume uint))
  (begin
    (try! (check-circuit-breaker))
    (let ((ma (get-moving-average token-a token-b u10)))
      (if (is-some ma)
        (let ((deviation (/ (* (if (< (unwrap-panic ma) price) (- price (unwrap-panic ma)) (- (unwrap-panic ma) price)) u10000) (unwrap-panic ma))))
          (if (> deviation u1000) ;; 10% deviation
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

;; @desc Records a price and volume for a given token pair at the current block height.
;; @param token-a principal - The principal of the first token.
;; @param token-b principal - The principal of the second token.
;; @param price uint - The price to record.
;; @param volume uint - The volume to record.
;; @returns (response bool uint) - (ok true) on success.
;; @events (print (ok true))
(define-public (record-price (token-a principal) (token-b principal) (price uint) (volume uint))
  (map-set price-history { token-a: token-a, token-b: token-b, block: block-height } { price: price, volume: volume })
  (ok true)
)

;; --- Private Functions ---

;; @desc Calculates the moving average price for a token pair over a specified period.
;; @param token-a principal - The principal of the first token.
;; @param token-b principal - The principal of the second token.
;; @param period uint - The number of blocks to consider for the moving average.
;; @returns (optional uint) - The calculated moving average, or none if no price history is available.
(define-private (get-moving-average (token-a principal) (token-b principal) (period uint))
  (let ((prices (get-price-history token-a token-b period)))
    (if (> (len prices) u0)
      (some (/ (fold + prices u0) (len prices)))
      none
    )
  )
)

;; @desc Retrieves the price history for a token pair over a specified period.
;; @param token-a principal - The principal of the first token.
;; @param token-b principal - The principal of the second token.
;; @param period uint - The number of blocks to retrieve history for.
;; @returns (list 100 uint) - A list of prices from the history.
(define-private (get-price-history (token-a principal) (token-b principal) (period uint))
  (let ((current-block block-height))
    (let ((prices (list)))
      ;; In a real implementation, this would iterate through price-history map
      ;; and filter by token-a, token-b, and block-height within the period.
      ;; For simplicity, returning an empty list or a placeholder.
      (ok (unwrap-panic (as-max-len? prices u100))) ;; Placeholder
    )
  )
)

;; @desc Checks if the associated circuit breaker is open.
;; @returns (response bool uint) - (ok true) if the circuit breaker is closed, (err ERR_CIRCUIT_BREAKER_TRIPPED) if it's open.
(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (some breaker) (asserts! (not (try! (contract-call? breaker is-circuit-open))) ERR_CIRCUIT_BREAKER_TRIPPED)
    (ok true)
  )
)

;; @desc Trips the associated circuit breaker.
;; @returns (response bool uint) - (ok true) on success.
;; @events (print (ok true))
(define-private (trip-circuit-breaker)
  (match (var-get circuit-breaker)
    (some breaker) (contract-call? breaker record-failure "manipulation-detector")
    (ok true)
  )
)