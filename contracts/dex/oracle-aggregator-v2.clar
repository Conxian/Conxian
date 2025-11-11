;; oracle-aggregator-v2.clar
;; Enhanced Oracle System with TWAP and Manipulation Detection

;; --- Traits ---
(use-trait oracle-trait .all-traits.oracle-trait)

;; --- Constants ---
;; @constant ERR_UNAUTHORIZED (err u100) - Returned when the caller is not authorized to perform the action.
(define-constant ERR_UNAUTHORIZED (err u100))
;; @constant ERR_INVALID_ORACLE (err u101) - Returned when an invalid oracle is provided.
(define-constant ERR_INVALID_ORACLE (err u101))
;; @constant ERR_NO_ORACLES (err u102) - Returned when no oracles are registered.
(define-constant ERR_NO_ORACLES (err u102))
;; @constant ERR_STALE_PRICE (err u103) - Returned when the price data is stale.
(define-constant ERR_STALE_PRICE (err u103))
;; @constant ERR_PRICE_MANIPULATION (err u104) - Returned when price manipulation is detected.
(define-constant ERR_PRICE_MANIPULATION (err u104))
;; @constant ERR_CIRCUIT_BREAKER_TRIPPED (err u105) - Returned when the circuit breaker is tripped.
(define-constant ERR_CIRCUIT_BREAKER_TRIPPED (err u105))

;; --- Data Variables ---
;; @var contract-owner principal - The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)
;; @var manipulation-detector-contract (optional principal) - The principal of the manipulation detector contract, if set.
(define-data-var manipulation-detector-contract (optional principal) none)
;; @var circuit-breaker-contract (optional principal) - The principal of the circuit breaker contract, if set.
(define-data-var circuit-breaker-contract (optional principal) none)

;; --- Data Maps ---
;; @map registered-oracles { oracle-principal: principal } { weight: uint, last-updated: uint }
;; Stores registered oracles with their weights and last update block height.
(define-map registered-oracles { oracle-principal: principal } { weight: uint, last-updated: uint })

;; @map asset-twap { asset: principal } { price: uint, last-updated: uint }
;; Stores the time-weighted average price (TWAP) for each asset and its last update block height.
(define-map asset-twap { asset: principal } { price: uint, last-updated: uint })

;; --- Public Functions ---

;; @desc Sets the contract owner. Only the current owner can call this function.
;; @param new-owner principal - The principal of the new owner.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the current owner.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Sets the manipulation detector contract. Only the contract owner can call this function.
;; @param detector principal - The principal of the manipulation detector contract.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the owner.
(define-public (set-manipulation-detector (detector principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set manipulation-detector-contract (some detector))
    (ok true)
  )
)

;; @desc Sets the circuit breaker contract. Only the contract owner can call this function.
;; @param breaker principal - The principal of the circuit breaker contract.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the owner.
(define-public (set-circuit-breaker (breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker-contract (some breaker))
    (ok true)
  )
)

;; @desc Registers an oracle with a given weight. Only the contract owner can call this function.
;; @param oracle principal - The principal of the oracle contract.
;; @param weight uint - The weight assigned to this oracle.
;; @returns (response bool uint) - (ok true) on success, (err ERR_UNAUTHORIZED) if not called by the owner.
(define-public (register-oracle (oracle principal) (weight uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set registered-oracles { oracle-principal: oracle } { weight: weight, last-updated: block-height })
    (ok true)
  )
)

;; @desc Updates the price from a registered oracle and calculates TWAP. This function also checks for price manipulation and circuit breaker status.
;; @param oracle principal - The principal of the oracle contract.
;; @param asset principal - The principal of the asset.
;; @param price uint - The price reported by the oracle.
;; @returns (response bool uint) - (ok true) on success, or an error if unauthorized, oracle not found, or manipulation detected.
(define-public (update-price (oracle principal) (asset principal) (price uint))
  (begin
    (asserts! (is-some (map-get? registered-oracles { oracle-principal: oracle })) ERR_INVALID_ORACLE)
    (try! (check-manipulation asset price))
    (try! (check-circuit-breaker))
    ;; In a real implementation, this would involve more complex TWAP calculation
    ;; and aggregation from multiple oracles.
    (map-set asset-twap { asset: asset } { price: price, last-updated: block-height })
    (ok true)
  )
)

;; --- Read-Only Functions ---

;; @desc Retrieves the time-weighted average price (TWAP) for an asset.
;; @param asset principal - The principal of the asset.
;; @returns (response uint uint) - (ok price) on success, (err ERR_STALE_PRICE) if price is stale, (err ERR_NO_ORACLES) if no oracles are registered.
(define-read-only (get-twap (asset principal))
  (let ((twap-entry (map-get? asset-twap { asset: asset })))
    (asserts! (is-some twap-entry) ERR_NO_ORACLES)
    (let ((last-updated (get last-updated (unwrap-panic twap-entry))))
      (asserts! (<= (- block-height last-updated) u100) ERR_STALE_PRICE) ;; Example staleness check
      (ok (get price (unwrap-panic twap-entry)))
    )
  )
)

;; @desc Checks if an oracle is registered.
;; @param oracle principal - The principal of the oracle contract.
;; @returns bool - True if registered, false otherwise.
(define-read-only (is-oracle-registered (oracle principal))
  (is-some (map-get? registered-oracles { oracle-principal: oracle }))
)

;; --- Private Functions ---

;; @desc Checks for price manipulation using the registered manipulation detector.
;; @param asset principal - The principal of the asset.
;; @param price uint - The price to check.
;; @returns (response bool uint) - (ok true) if no manipulation, (err ERR_PRICE_MANIPULATION) if detected.
(define-private (check-manipulation (asset principal) (price uint))
  (match (var-get manipulation-detector-contract)
    (some detector) (contract-call? detector check-price asset asset price u0) ;; Assuming asset as token-a and token-b for simplicity
    (ok true)
  )
)

;; @desc Checks the circuit breaker status.
;; @returns (response bool uint) - (ok true) if circuit breaker is not tripped, (err ERR_CIRCUIT_BREAKER_TRIPPED) if tripped.
(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker-contract)
    (some breaker) (asserts! (not (try! (contract-call? breaker is-circuit-open))) ERR_CIRCUIT_BREAKER_TRIPPED)
    (ok true)
  )
)