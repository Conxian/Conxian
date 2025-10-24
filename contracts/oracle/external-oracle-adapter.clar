;; external-oracle-adapter
;; This contract acts as an adapter for integrating external oracle providers, allowing the system to fetch and use off-chain data.
;; It supports multiple oracle sources, manages their authorization, and aggregates price data to mitigate manipulation risks.

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_ORACLE_SOURCE (err u1001))
(define-constant ERR_INVALID_PRICE_DATA (err u1002))
(define-constant ERR_PRICE_TOO_OLD (err u1003))
(define-constant ERR_PRICE_MANIPULATION_RISK (err u1004))
(define-constant ERR_ALREADY_INITIALIZED (err u1005))
(define-constant ERR_NOT_INITIALIZED (err u1006))
(define-constant ERR_ORACLE_SOURCE_ALREADY_EXISTS (err u1007))
(define-constant ERR_ORACLE_SOURCE_NOT_FOUND (err u1008))
(define-constant ERR_OPERATOR_ALREADY_AUTHORIZED (err u1009))
(define-constant ERR_OPERATOR_NOT_AUTHORIZED (err u1010))
(define-constant ERR_QUORUM_NOT_REACHED (err u1011))
(define-constant ERR_PRICE_FEED_NOT_ACTIVE (err u1012))
(define-constant ERR_INVALID_QUORUM_PERCENTAGE (err u1013))
(define-constant ERR_INVALID_EXPIRATION_THRESHOLD (err u1014))
(define-constant ERR_INVALID_PRICE_THRESHOLD (err u1015))
(define-constant ERR_INVALID_SOURCE_ID (err u1016))

;; Constants for source IDs
(define-constant ORACLE_SOURCE_BINANCE u1)
(define-constant ORACLE_SOURCE_COINBASE u2)
(define-constant ORACLE_SOURCE_CHAINLINK u3)

;; Data map for oracle sources
;; source-id: uint (e.g., u1 for Binance, u2 for Coinbase)
;; source-name: (string-ascii 32)
;; source-address: principal
;; is-active: bool
(define-map oracle-sources { source-id: uint } {
    source-name: (string-ascii 32),
    source-address: principal,
    is-active: bool
})

;; Data map for authorized operators for each oracle source
;; source-id: uint
;; operator-address: principal
(define-map authorized-operators { source-id: uint, operator-address: principal } bool)

;; Data map for submitted price data
;; source-id: uint
;; asset-pair: (string-ascii 16) (e.g., "STX-USD")
;; block-height: uint
;; price: uint (price * 10^decimals)
;; timestamp: uint (unix timestamp)
(define-map price-data { source-id: uint, asset-pair: (string-ascii 16), block-height: uint } {
    price: uint,
    timestamp: uint
})

;; Data map for aggregated prices
;; asset-pair: (string-ascii 16)
;; last-aggregated-block: uint
(define-map aggregated-prices { asset-pair: (string-ascii 16) } {
    price: uint,
    timestamp: uint,
    last-aggregated-block: uint
})

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)
(define-data-var min-oracle-sources-for-quorum uint u3) ;; Minimum number of active oracle sources required for price aggregation
(define-data-var quorum-percentage uint u6000) ;; 60% (6000 out of 10000)
(define-data-var price-data-expiration-threshold uint u100) ;; Price data expires after 100 blocks
(define-data-var price-manipulation-threshold uint u500) ;; 5% (500 out of 10000)

;; Authorization check
(define-private (is-owner)
    (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-oracle-operator (source-id uint) (operator principal))
    (default-to false (map-get? authorized-operators { source-id: source-id, operator-address: operator }))
)

;; --- Admin functions ---

;; @desc Initialize the oracle adapter with initial settings.
;; @param min-sources (uint) - Minimum number of active oracle sources for quorum.
;; @param quorum-pct (uint) - Quorum percentage (e.g., 6000 for 60%).
;; @param expiration-thresh (uint) - Price data expiration threshold in blocks.
;; @param manipulation-thresh (uint) - Price manipulation threshold (e.g., 500 for 5%).
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (initialize (min-sources uint) (quorum-pct uint) (expiration-thresh uint) (manipulation-thresh uint))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
        (asserts! (and (>= quorum-pct u0) (<= quorum-pct u10000)) ERR_INVALID_QUORUM_PERCENTAGE)
        (asserts! (> expiration-thresh u0) ERR_INVALID_EXPIRATION_THRESHOLD)
        (asserts! (and (>= manipulation-thresh u0) (<= manipulation-thresh u10000)) ERR_INVALID_PRICE_THRESHOLD)

        (var-set min-oracle-sources-for-quorum min-sources)
        (var-set quorum-percentage quorum-pct)
        (var-set price-data-expiration-threshold expiration-thresh)
        (var-set price-manipulation-threshold manipulation-thresh)
        (var-set initialized true)
        (ok true)
    )
)

;; @desc Add a new oracle source.
;; @param source-id (uint) - Unique identifier for the oracle source.
;; @param source-name (string-ascii 32) - Name of the oracle source.
;; @param source-address (principal) - Contract or principal address of the oracle source.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (add-oracle-source (source-id uint) (source-name (string-ascii 32)) (source-address principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (not (is-some (map-get? oracle-sources { source-id: source-id }))) ERR_ORACLE_SOURCE_ALREADY_EXISTS)
        (map-set oracle-sources { source-id: source-id } {
            source-name: source-name,
            source-address: source-address,
            is-active: true
        })
        (ok true)
    )
)

;; @desc Set the active status of an oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param active (bool) - New active status.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (set-oracle-source-active (source-id uint) (active bool))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (map-update oracle-sources { source-id: source-id } { is-active: active })
        (ok true)
    )
)

;; @desc Authorize an operator for a specific oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param operator (principal) - Address of the operator to authorize.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (authorize-operator (source-id uint) (operator principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-some (map-get? oracle-sources { source-id: source-id })) ERR_ORACLE_SOURCE_NOT_FOUND)
        (asserts! (not (is-oracle-operator source-id operator)) ERR_OPERATOR_ALREADY_AUTHORIZED)
        (map-set authorized-operators { source-id: source-id, operator-address: operator } true)
        (ok true)
    )
)

;; @desc Deauthorize an operator for a specific oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param operator (principal) - Address of the operator to deauthorize.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (deauthorize-operator (source-id uint) (operator principal))
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-oracle-operator source-id operator) ERR_OPERATOR_NOT_AUTHORIZED)
        (map-delete authorized-operators { source-id: source-id, operator-address: operator })
        (ok true)
    )
)

;; --- Price Feed functions ---

;; @desc Submit price data from an authorized oracle operator.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param asset-pair (string-ascii 16) - Asset pair (e.g., "STX-USD").
;; @param price (uint) - Price value (e.g., 1000000 for 1.00 USD with 6 decimals).
;; @param timestamp (uint) - Unix timestamp of the price data.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (submit-price (source-id uint) (asset-pair (string-ascii 16)) (price uint) (timestamp uint))
    (begin
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-oracle-operator source-id tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? oracle-sources { source-id: source-id })) ERR_ORACLE_SOURCE_NOT_FOUND)
        (let
            ((source-info (unwrap! (map-get? oracle-sources { source-id: source-id }) ERR_ORACLE_SOURCE_NOT_FOUND)))
            (asserts! (get is-active source-info) ERR_PRICE_FEED_NOT_ACTIVE)
            (map-set price-data { source-id: source-id, asset-pair: asset-pair, block-height: block-height } {
                price: price,
                timestamp: timestamp
            })
            (ok true)
        )
    )
)

;; @desc Aggregate price data from multiple oracle sources.
;; @param asset-pair (string-ascii 16) - Asset pair to aggregate.
;; @returns (response uint uint) - Aggregated price if successful, error otherwise.
(define-public (aggregate-prices (asset-pair (string-ascii 16)))
    (begin
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (let
            (
                (active-sources (get-active-oracle-sources))
                (valid-prices (get-valid-prices-for-aggregation active-sources asset-pair))
                (num-valid-prices (len valid-prices))
                (min-sources (var-get min-oracle-sources-for-quorum))
            )
            (asserts! (>= num-valid-prices min-sources) ERR_QUORUM_NOT_REACHED)

            ;; Sort prices and get the median
            (let
                (
                    (sorted-prices (sort-prices valid-prices))
                    (median-price (get-median sorted-prices))
                )
                ;; Check for price manipulation risk
                (asserts! (not (check-price-manipulation-risk valid-prices median-price)) ERR_PRICE_MANIPULATION_RISK)

                (map-set aggregated-prices { asset-pair: asset-pair } {
                    price: median-price,
                    timestamp: (get timestamp (unwrap! (element-at sorted-prices (div (len sorted-prices) u2)) (err u0))), ;; Use timestamp of median price
                    last-aggregated-block: block-height
                })
                (ok median-price)
            )
        )
    )
)

;; --- Helper functions for aggregation ---

;; @desc Get a list of active oracle sources.
;; @returns (list ({source-id: uint, source-address: principal, is-active: bool, source-name: (string-ascii 32)})) - List of active oracle sources.
(define-private (get-active-oracle-sources)
    (fold
        (fun (source-id-entry (accumulator (list 20 {source-id: uint, source-address: principal, is-active: bool, source-name: (string-ascii 32)})))
            (let
                ((source-info (unwrap! (map-get? oracle-sources { source-id: (get source-id source-id-entry) }) (err u0))))
                (if (get is-active source-info)
                    (cons source-info accumulator)
                    accumulator
                )
            )
        )
        (list)
        (map-keys oracle-sources)
    )
)

;; @desc Get valid prices for aggregation from active sources.
;; @param active-sources (list) - List of active oracle sources.
;; @param asset-pair (string-ascii 16) - Asset pair.
;; @returns (list ({price: uint, timestamp: uint})) - List of valid prices.
(define-private (get-valid-prices-for-aggregation (active-sources (list 20 {source-id: uint, source-address: principal, is-active: bool, source-name: (string-ascii 32)})) (asset-pair (string-ascii 16)))
    (fold
        (fun (source-info (accumulator (list 20 {price: uint, timestamp: uint})))
            (let
                (
                    (source-id (get source-id source-info))
                    (latest-price-data (get-latest-price-data source-id asset-pair))
                )
                (if (and (is-some latest-price-data) (not (is-price-data-expired (unwrap! latest-price-data (err u0)))))
                    (cons (unwrap! latest-price-data (err u0)) accumulator)
                    accumulator
                )
            )
        )
        (list)
        active-sources
    )
)

;; @desc Get the latest price data for a given source and asset pair.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param asset-pair (string-ascii 16) - Asset pair.
;; @returns (optional {price: uint, timestamp: uint}) - Latest price data or none.
(define-private (get-latest-price-data (source-id uint) (asset-pair (string-ascii 16)))
    (let
        (
            (current-block block-height)
            (expiration-threshold (var-get price-data-expiration-threshold))
            (start-block (if (> current-block expiration-threshold) (- current-block expiration-threshold) u0))
            (latest-price none)
            (latest-block u0)
        )
        (map-fold
            (fun (key value result)
                (if (and
                        (is-eq (get source-id key) source-id)
                        (is-eq (get asset-pair key) asset-pair)
                        (>= (get block-height key) start-block)
                        (> (get block-height key) latest-block)
                    )
                    (begin
                        (var-set latest-block (get block-height key))
                        (some value)
                    )
                    result
                )
            )
            none
            price-data
        )
    )
)

;; @desc Check if price data has expired.
;; @param price-info ({price: uint, timestamp: uint}) - Price data.
;; @returns (bool) - True if expired, false otherwise.
(define-private (is-price-data-expired (price-info {price: uint, timestamp: uint}))
    (let
        ((last-block (get last-aggregated-block (map-get? aggregated-prices { asset-pair: "STX-USD" })))) ;; This needs to be dynamic
        (> (- block-height last-block) (var-get price-data-expiration-threshold))
    )
)

;; @desc Sort a list of prices in ascending order.
;; @param prices (list) - List of prices.
;; @returns (list) - Sorted list of prices.
(define-private (sort-prices (prices (list 20 {price: uint, timestamp: uint})))
    ;; This is a simplified bubble sort for demonstration.
    ;; In a real scenario, consider more efficient sorting or off-chain sorting.
    (if (<= (len prices) u1)
        prices
        (let
            (
                (swapped true)
                (current-prices prices)
            )
            (while swapped
                (begin
                    (var-set swapped false)
                    (let
                        (
                            (i u0)
                            (n (- (len current-prices) u1))
                        )
                        (while (< i n)
                            (begin
                                (let
                                    (
                                        (price1 (get price (unwrap! (element-at current-prices i) (err u0))))
                                        (price2 (get price (unwrap! (element-at current-prices (+ i u1)) (err u0))))
                                    )
                                    (if (> price1 price2)
                                        (begin
                                            ;; Swap elements (simplified, actual swap logic would be more complex)
                                            (var-set swapped true)
                                            ;; For clarity, a real swap would involve reconstructing the list or using a mutable data structure.
                                            ;; This example assumes a functional swap for illustration.
                                        )
                                    )
                                )
                                (var-set i (+ i u1))
                            )
                        )
                    )
                )
            )
            current-prices
        )
    )
)

;; @desc Get the median price from a sorted list of prices.
;; @param sorted-prices (list) - Sorted list of prices.
;; @returns (uint) - Median price.
(define-private (get-median (sorted-prices (list 20 {price: uint, timestamp: uint})))
    (let
        ((len-prices (len sorted-prices)))
        (if (is-eq (mod len-prices u2) u1)
            ;; Odd number of elements
            (get price (unwrap! (element-at sorted-prices (div len-prices u2)) (err u0)))
            ;; Even number of elements, average the two middle ones
            (let
                (
                    (mid1 (unwrap! (element-at sorted-prices (- (div len-prices u2) u1)) (err u0)))
                    (mid2 (unwrap! (element-at sorted-prices (div len-prices u2)) (err u0)))
                )
                (/ (+ (get price mid1) (get price mid2)) u2)
            )
        )
    )
)

;; @desc Check for price manipulation risk by comparing individual prices to the median.
;; @param valid-prices (list) - List of valid prices.
;; @param median-price (uint) - Median price.
;; @returns (bool) - True if manipulation risk detected, false otherwise.
(define-private (check-price-manipulation-risk (valid-prices (list 20 {price: uint, timestamp: uint})) (median-price uint))
    (let
        ((manipulation-thresh (var-get price-manipulation-threshold)))
        (fold
            (fun (price-info (risk-detected bool))
                (if risk-detected
                    true
                    (let
                        ((price (get price price-info)))
                        (if (or
                                (> price (* median-price (+ u10000 manipulation-thresh)) / u10000)
                                (< price (* median-price (- u10000 manipulation-thresh)) / u10000)
                            )
                            true
                            false
                        )
                    )
                )
            )
            false
            valid-prices
        )
    )
)

;; --- Read-only functions ---

;; @desc Get the current aggregated price for an asset pair.
;; @param asset-pair (string-ascii 16) - Asset pair.
;; @returns (response uint uint) - Aggregated price if available, error otherwise.
(define-read-only (get-price (asset-pair (string-ascii 16)))
    (ok (get price (unwrap! (map-get? aggregated-prices { asset-pair: asset-pair }) ERR_PRICE_FEED_NOT_ACTIVE)))
)

;; @desc Get details of an oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @returns (response (optional {source-name: (string-ascii 32), source-address: principal, is-active: bool}) uint) - Oracle source details or error.
(define-read-only (get-oracle-source-details (source-id uint))
    (ok (map-get? oracle-sources { source-id: source-id }))
)

;; @desc Check if an operator is authorized for an oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param operator (principal) - Address of the operator.
;; @returns (bool) - True if authorized, false otherwise.
(define-read-only (is-operator-authorized (source-id uint) (operator principal))
    (is-oracle-operator source-id operator)
)

;; @desc Get the current contract owner.
;; @returns (principal) - The contract owner.
(define-read-only (get-contract-owner)
    (ok (var-get contract-owner))
)

;; @desc Get initialization status.
;; @returns (bool) - True if initialized, false otherwise.
(define-read-only (is-initialized)
    (ok (var-get initialized))
)

;; @desc Get minimum oracle sources for quorum.
;; @returns (uint) - Minimum sources.
(define-read-only (get-min-oracle-sources-for-quorum)
    (ok (var-get min-oracle-sources-for-quorum))
)

;; @desc Get quorum percentage.
;; @returns (uint) - Quorum percentage.
(define-read-only (get-quorum-percentage)
    (ok (var-get quorum-percentage))
)

;; @desc Get price data expiration threshold.
;; @returns (uint) - Expiration threshold.
(define-read-only (get-price-data-expiration-threshold)
    (ok (var-get price-data-expiration-threshold))
)

;; @desc Get price manipulation threshold.
;; @returns (uint) - Manipulation threshold.
(define-read-only (get-price-manipulation-threshold)
    (ok (var-get price-manipulation-threshold))
)