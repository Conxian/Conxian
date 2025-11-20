;; chainlink-adapter.clar
;; Adapts Chainlink oracle data for use within the Clarity ecosystem.

;; SIP-010: Fungible Token Standard
(use-trait sip-010-ft-trait .dex-traits.sip-010-ft-trait)

;; Constants
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u5000))
(define-constant ERR-INVALID-FEED-ID (err u5001))
(define-constant ERR-STALE-DATA (err u5002))

;; Data Maps
;; Stores Chainlink feed configurations
;; { feed-id: uint } { aggregator-contract: principal, decimals: uint, heartbeat: uint }
(define-map feed-configs { feed-id: uint } { aggregator-contract: principal, decimals: uint, heartbeat: uint })

;; Data Variables
;; Contract owner
(define-data-var contract-owner principal tx-sender)
;; Governance address
(define-data-var governance-address principal tx-sender)

;; Events
(define-event feed-configured
  (tuple
    (event (string-ascii 16))
    (feed-id uint)
    (aggregator-contract principal)
    (decimals uint)
    (heartbeat uint)
    (sender principal)
    (block-height uint)
  )
)

(define-event price-updated
  (tuple
    (event (string-ascii 16))
    (feed-id uint)
    (price uint)
    (timestamp uint)
    (sender principal)
    (block-height uint)
  )
)

;; Private Helper Functions

;; @desc Checks if the caller is the contract owner.
;; @returns A response with ok if authorized, or an error.
(define-private (is-contract-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED))
)

;; @desc Checks if the caller is the governance address.
;; @returns A response with ok if authorized, or an error.
(define-private (is-governance)
  (ok (asserts! (is-eq tx-sender (var-get governance-address)) ERR-NOT-AUTHORIZED))
)

;; Public Functions

;; @desc Configures a new Chainlink data feed.
;; @param feed-id A unique identifier for the feed.
;; @param aggregator-contract The principal of the Chainlink aggregator contract.
;; @param decimals The number of decimals the feed uses.
;; @param heartbeat The maximum time in seconds before data is considered stale.
;; @returns A response with ok on success, or an error.
(define-public (configure-feed (feed-id uint) (aggregator-contract principal) (decimals uint) (heartbeat uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (map-set feed-configs
      { feed-id: feed-id }
      { aggregator-contract: aggregator-contract, decimals: decimals, heartbeat: heartbeat }
    )
    (print (merge-tuple (map-get? feed-configs { feed-id: feed-id }) { event: "feed-configured", sender: tx-sender, block-height: (get-block-info? block-height) }))
    (ok true)
  )
)

;; @desc Fetches the latest price from a configured Chainlink feed.
;; @param feed-id The unique identifier for the feed.
;; @returns A response with the price and timestamp on success, or an error.
(define-public (get-latest-price (feed-id uint))
  (let
    ((feed-config (unwrap! (map-get? feed-configs { feed-id: feed-id }) ERR-INVALID-FEED-ID)))
    (let
      ((aggregator-contract (get aggregator-contract feed-config))
       (decimals (get decimals feed-config))
       (heartbeat (get heartbeat feed-config))
      )
      ;; Simulate calling the Chainlink aggregator contract
      ;; In a real scenario, this would be a contract-call? to the actual Chainlink aggregator
      (let
        ((price-data (unwrap-panic (contract-call? aggregator-contract get-latest-price-data)))
         (price (get price price-data))
         (timestamp (get timestamp price-data))
        )
        (asserts! (>= (get-block-info? block-height) (+ timestamp heartbeat)) ERR-STALE-DATA)
        (print (merge-tuple { event: "price-updated", feed-id: feed-id, price: price, timestamp: timestamp, sender: tx-sender, block-height: (get-block-info? block-height) }))
        (ok { price: price, timestamp: timestamp })
      )
    )
  )
)

;; @desc Sets the contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns A response with ok on success, or an error.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Sets the governance address.
;; @param new-governance The principal of the new governance address.
;; @returns A response with ok on success, or an error.
(define-public (set-governance-address (new-governance principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set governance-address new-governance)
    (ok true)
  )
)

;; Read-only Functions

;; @desc Gets the configuration for a given feed ID.
;; @param feed-id The unique identifier for the feed.
;; @returns An optional tuple containing the feed configuration.
(define-read-only (get-feed-config (feed-id uint))
  (map-get? feed-configs { feed-id: feed-id })
)

;; @desc Gets the current contract owner.
;; @returns The principal of the contract owner.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

;; @desc Gets the current governance address.
;; @returns The principal of the governance address.
(define-read-only (get-governance-address)
  (ok (var-get governance-address))
)
