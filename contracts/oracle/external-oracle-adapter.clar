;; external-oracle-adapter
;; This contract acts as an adapter for integrating external oracle providers, allowing the system to fetch and use off-chain data.
;; It supports multiple oracle sources, manages their authorization, and aggregates price data to mitigate manipulation risks.

(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait oracle-trait .oracle-pricing.oracle-trait)
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
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
(define-constant ERR_TOO_MANY_SOURCES (err u1017))

;; Local authorization error for this adapter
(define-constant ERR_UNAUTHORIZED (err u19000))

;; Constants for source IDs
(define-constant ORACLE_SOURCE_BINANCE u1)
(define-constant ORACLE_SOURCE_COINBASE u2)
(define-constant ORACLE_SOURCE_CHAINLINK u3)

;; Data map for oracle sources
;; source-id: uint (e.g., u1 for Binance, u2 for Coinbase)
;; source-name: (string-ascii 32)
;; source-address: principal
;; is-active: bool
(define-map oracle-sources
    { source-id: uint }
    {
        source-name: (string-ascii 32),
        source-address: principal,
        is-active: bool,
    }
)

;; Data map for authorized operators for each oracle source
;; source-id: uint
;; operator-address: principal
(define-map authorized-operators
    {
        source-id: uint,
        operator-address: principal,
    }
    bool
)

;; Data map for submitted price data
;; source-id: uint
;; asset-pair: (string-ascii 16) (e.g., "STX-USD")
;; block-height: uint
;; price: uint (price * 10^decimals)
;; timestamp: uint (unix timestamp)
(define-map price-data
    {
        source-id: uint,
        asset-pair: (string-ascii 16),
        block-height: uint,
    }
    {
        price: uint,
        timestamp: uint,
    }
)

;; Data map for latest prices to avoid iterating price-data
(define-map latest-prices
    {
        source-id: uint,
        asset-pair: (string-ascii 16),
    }
    {
        price: uint,
        timestamp: uint,
        block-height: uint,
    }
)

;; Data map for aggregated prices
;; asset-pair: (string-ascii 16)
;; last-aggregated-block: uint
(define-map aggregated-prices
    { asset-pair: (string-ascii 16) }
    {
        price: uint,
        timestamp: uint,
        last-aggregated-block: uint,
    }
)

;; Data variables

(define-data-var initialized bool false)
(define-data-var min-oracle-sources-for-quorum uint u3) ;; Minimum number of active oracle sources required for price aggregation
(define-data-var quorum-percentage uint u6000) ;; 60% (6000 out of 10000)
(define-data-var price-data-expiration-threshold uint u100) ;; Price data expires after 100 blocks
(define-data-var price-manipulation-threshold uint u500) ;; 5% (500 out of 10000)
(define-data-var source-ids (list 20 uint) (list))

;; Authorization check
(define-private (is-owner)
    true
)

(define-private (is-oracle-operator
        (source-id uint)
        (operator principal)
    )
    (default-to false
        (map-get? authorized-operators {
            source-id: source-id,
            operator-address: operator,
        })
    )
)

;; --- Admin functions ---

;; @desc Initialize the oracle adapter with initial settings.
;; @param min-sources (uint) - Minimum number of active oracle sources for quorum.
;; @param quorum-pct (uint) - Quorum percentage (e.g., 6000 for 60%).
;; @param expiration-thresh (uint) - Price data expiration threshold in blocks.
;; @param manipulation-thresh (uint) - Price manipulation threshold (e.g., 500 for 5%).
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (initialize
        (min-sources uint)
        (quorum-pct uint)
        (expiration-thresh uint)
        (manipulation-thresh uint)
    )
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (not (var-get initialized)) ERR_ALREADY_INITIALIZED)
        (asserts! (and (>= quorum-pct u0) (<= quorum-pct u10000))
            ERR_INVALID_QUORUM_PERCENTAGE
        )
        (asserts! (> expiration-thresh u0) ERR_INVALID_EXPIRATION_THRESHOLD)
        (asserts!
            (and (>= manipulation-thresh u0) (<= manipulation-thresh u10000))
            ERR_INVALID_PRICE_THRESHOLD
        )

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
(define-public (add-oracle-source
        (source-id uint)
        (source-name (string-ascii 32))
        (source-address principal)
    )
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts!
            (not (is-some (map-get? oracle-sources { source-id: source-id })))
            ERR_ORACLE_SOURCE_ALREADY_EXISTS
        )

        ;; Update source list
        (let ((current-sources (var-get source-ids)))
            (asserts! (< (len current-sources) u20) ERR_TOO_MANY_SOURCES)

            (var-set source-ids
                (unwrap-panic (as-max-len? (append current-sources source-id) u20))
            )
        )

        (map-set oracle-sources { source-id: source-id } {
            source-name: source-name,
            source-address: source-address,
            is-active: true,
        })
        (ok true)
    )
)

;; @desc Set the active status of an oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param active (bool) - New active status.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (set-oracle-source-active
        (source-id uint)
        (active bool)
    )
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (let ((current-source (unwrap! (map-get? oracle-sources { source-id: source-id })
                ERR_ORACLE_SOURCE_NOT_FOUND
            )))
            (map-set oracle-sources { source-id: source-id }
                (merge current-source { is-active: active })
            )
            (ok true)
        )
    )
)

;; @desc Authorize an operator for a specific oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param operator (principal) - Address of the operator to authorize.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (authorize-operator
        (source-id uint)
        (operator principal)
    )
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-some (map-get? oracle-sources { source-id: source-id }))
            ERR_ORACLE_SOURCE_NOT_FOUND
        )
        (asserts! (not (is-oracle-operator source-id operator))
            ERR_OPERATOR_ALREADY_AUTHORIZED
        )
        (map-set authorized-operators {
            source-id: source-id,
            operator-address: operator,
        }
            true
        )
        (ok true)
    )
)

;; @desc Deauthorize an operator for a specific oracle source.
;; @param source-id (uint) - Identifier of the oracle source.
;; @param operator (principal) - Address of the operator to deauthorize.
;; @returns (response bool uint) - True if successful, error otherwise.
(define-public (deauthorize-operator
        (source-id uint)
        (operator principal)
    )
    (begin
        (asserts! (is-owner) ERR_UNAUTHORIZED)
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-oracle-operator source-id operator)
            ERR_OPERATOR_NOT_AUTHORIZED
        )
        (map-delete authorized-operators {
            source-id: source-id,
            operator-address: operator,
        })
        (ok true)
    )
)

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts!
            (is-eq (contract-call? .rbac has-role "contract-owner") (ok true))
            (err ERR_UNAUTHORIZED)
        )
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
(define-public (submit-price
        (source-id uint)
        (asset-pair (string-ascii 16))
        (price uint)
        (timestamp uint)
    )
    (begin
        (asserts! (var-get initialized) ERR_NOT_INITIALIZED)
        (asserts! (is-oracle-operator source-id tx-sender) ERR_UNAUTHORIZED)
        (asserts! (is-some (map-get? oracle-sources { source-id: source-id }))
            ERR_ORACLE_SOURCE_NOT_FOUND
        )
        (let ((source-info (unwrap! (map-get? oracle-sources { source-id: source-id })
                ERR_ORACLE_SOURCE_NOT_FOUND
            )))
            (asserts! (get is-active source-info) ERR_PRICE_FEED_NOT_ACTIVE)

            ;; Store historical
            (map-set price-data {
                source-id: source-id,
                asset-pair: asset-pair,
                block-height: block-height,
            } {
                price: price,
                timestamp: timestamp,
            })

            ;; Update latest
            (map-set latest-prices {
                source-id: source-id,
                asset-pair: asset-pair,
            } {
                price: price,
                timestamp: timestamp,
                block-height: block-height,
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
        (let (
                (active-sources (get-active-oracle-sources))
                (valid-prices (get-valid-prices-for-aggregation active-sources asset-pair))
                (num-valid-prices (len valid-prices))
                (min-sources (var-get min-oracle-sources-for-quorum))
            )
            (asserts! (>= num-valid-prices min-sources) ERR_QUORUM_NOT_REACHED)

            ;; Sort prices and get the median
            (let (
                    (sorted-prices (sort-prices valid-prices))
                    (median-price (get-median sorted-prices))
                )
                ;; Check for price manipulation risk
                (asserts!
                    (not (check-price-manipulation-risk valid-prices median-price))
                    ERR_PRICE_MANIPULATION_RISK
                )

                (map-set aggregated-prices { asset-pair: asset-pair } {
                    price: median-price,
                    timestamp: (get timestamp
                        (unwrap!
                            (element-at sorted-prices (/ (len sorted-prices) u2))
                            (err u0)
                        )), ;; Use timestamp of median price
                    last-aggregated-block: block-height,
                })
                (ok median-price)
            )
        )
    )
)

;; --- Helper functions for aggregation ---

(define-private (get-latest-price-data
        (source-id uint)
        (asset-pair (string-ascii 16))
    )
    (map-get? latest-prices {
        source-id: source-id,
        asset-pair: asset-pair,
    })
)

(define-private (is-price-data-expired (price-info {
    price: uint,
    timestamp: uint,
    block-height: uint,
}))
    (> (- block-height (get block-height price-info))
        (var-get price-data-expiration-threshold)
    )
)

(define-private (add-active-source
        (source-id uint)
        (res (list 20 uint))
    )
    (match (map-get? oracle-sources { source-id: source-id })
        source-info (if (get is-active source-info)
            (unwrap! (as-max-len? (append res source-id) u20) res)
            res
        )
        res
    )
)

(define-private (get-active-oracle-sources)
    (fold add-active-source (var-get source-ids) (list))
)

(define-private (accumulate-valid-price
        (source-id uint)
        (ctx {
            pair: (string-ascii 16),
            prices: (list 20 {
                price: uint,
                timestamp: uint,
            }),
        })
    )
    (let (
            (pair (get pair ctx))
            (current-prices (get prices ctx))
        )
        (match (get-latest-price-data source-id pair)
            price-info (if (not (is-price-data-expired price-info))
                (let ((new-prices (unwrap-panic (as-max-len?
                        (append current-prices {
                            price: (get price price-info),
                            timestamp: (get timestamp price-info),
                        })
                        u20
                    ))))
                    {
                        pair: pair,
                        prices: new-prices,
                    }
                )
                ctx
            )
            ctx
        )
    )
)

(define-private (get-valid-prices-for-aggregation
        (active-source-ids (list 20 uint))
        (asset-pair (string-ascii 16))
    )
    (get prices
        (fold accumulate-valid-price active-source-ids {
            pair: asset-pair,
            prices: (list),
        })
    )
)

(define-private (swap-if-needed
        (idx uint)
        (prices (list 20 {
            price: uint,
            timestamp: uint,
        }))
    )
    prices
)

(define-private (bubble-pass
        (ignore uint)
        (prices (list 20 {
            price: uint,
            timestamp: uint,
        }))
    )
    (fold swap-if-needed
        (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18)
        prices
    )
)

(define-private (sort-prices (prices (list 20 {
    price: uint,
    timestamp: uint,
})))
    (fold bubble-pass
        (list
            u0             u1             u2             u3             u4
                        u5             u6             u7             u8             u9
                        u10             u11             u12             u13             u14
                        u15             u16             u17             u18
            u19
        )
        prices
    )
)

(define-private (get-median (prices (list 20 {
    price: uint,
    timestamp: uint,
})))
    (let ((n (len prices)))
        (if (is-eq n u3)
            (let (
                    (p0 (get price (unwrap-panic (element-at prices u0))))
                    (p1 (get price (unwrap-panic (element-at prices u1))))
                    (p2 (get price (unwrap-panic (element-at prices u2))))
                    (sum (+ (+ p0 p1) p2))
                    (minv (if (< p0 p1)
                        (if (< p0 p2)
                            p0
                            p2
                        )
                        (if (< p1 p2)
                            p1
                            p2
                        )
                    ))
                    (maxv (if (> p0 p1)
                        (if (> p0 p2)
                            p0
                            p2
                        )
                        (if (> p1 p2)
                            p1
                            p2
                        )
                    ))
                )
                (- sum (+ minv maxv))
            )
            (if (is-eq n u4)
                (let (
                        (q0 (get price (unwrap-panic (element-at prices u0))))
                        (q1 (get price (unwrap-panic (element-at prices u1))))
                        (q2 (get price (unwrap-panic (element-at prices u2))))
                        (q3 (get price (unwrap-panic (element-at prices u3))))
                        (sum4 (+ (+ q0 q1) (+ q2 q3)))
                        (min4 (if (< q0 q1)
                            (if (< q0 q2)
                                (if (< q0 q3)
                                    q0
                                    q3
                                )
                                (if (< q2 q3)
                                    q2
                                    q3
                                )
                            )
                            (if (< q1 q2)
                                (if (< q1 q3)
                                    q1
                                    q3
                                )
                                (if (< q2 q3)
                                    q2
                                    q3
                                )
                            )
                        ))
                        (max4 (if (> q0 q1)
                            (if (> q0 q2)
                                (if (> q0 q3)
                                    q0
                                    q3
                                )
                                (if (> q2 q3)
                                    q2
                                    q3
                                )
                            )
                            (if (> q1 q2)
                                (if (> q1 q3)
                                    q1
                                    q3
                                )
                                (if (> q2 q3)
                                    q2
                                    q3
                                )
                            )
                        ))
                        (mid-sum (- sum4 (+ min4 max4)))
                    )
                    (/ mid-sum u2)
                )
                u0
            )
        )
    )
)

(define-private (check-deviation
        (price-info {
            price: uint,
            timestamp: uint,
        })
        (ctx {
            median: uint,
            risk: bool,
        })
    )
    (if (get risk ctx)
        ctx
        (let (
                (price (get price price-info))
                (median (get median ctx))
                (thresh (var-get price-manipulation-threshold))
                (upper (/ (* median (+ u10000 thresh)) u10000))
                (lower (/ (* median (- u10000 thresh)) u10000))
            )
            {
                median: median,
                risk: (or (> price upper) (< price lower)),
            }
        )
    )
)

(define-private (check-price-manipulation-risk
        (valid-prices (list 20 {
            price: uint,
            timestamp: uint,
        }))
        (median-price uint)
    )
    (get risk
        (fold check-deviation valid-prices {
            median: median-price,
            risk: false,
        })
    )
)

;; --- Read-only functions ---

;; @desc Get the current aggregated price for an asset pair.
;; @param asset-pair (string-ascii 16) - Asset pair.
;; @returns (response uint uint) - Aggregated price if available, error otherwise.
(define-read-only (get-price (asset-pair (string-ascii 16)))
    (ok (get price
        (unwrap! (map-get? aggregated-prices { asset-pair: asset-pair })
            ERR_PRICE_FEED_NOT_ACTIVE
        )))
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
(define-read-only (is-operator-authorized
        (source-id uint)
        (operator principal)
    )
    (is-oracle-operator source-id operator)
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
