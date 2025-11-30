;; twap-oracle.clar
;; Provides Time-Weighted Average Price (TWAP) data for assets.

;; SIP-010: Fungible Token Standard
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)

;; Constants
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u6000))
(define-constant ERR-INVALID-PERIOD (err u6001))
(define-constant ERR-NO-DATA (err u6002))

;; Data Maps
;; Stores TWAP data for a given asset and period
;; { asset: principal, period: uint } { last-price: uint, last-timestamp: uint, cumulative-price: uint, samples: uint }
(define-map twap-data { asset: principal, period: uint } { last-price: uint, last-timestamp: uint, cumulative-price: uint, samples: uint })

;; Data Variables
;; Contract owner
(define-data-var contract-owner principal tx-sender)
;; Governance address
(define-data-var governance-address principal tx-sender)

;; Events
;; Temporarily remove define-event until available
;; (define-event twap-updated
;;   (tuple
;;     (event (string-ascii 16))
;;     (asset principal)
;;     (period uint)
;;     (twap uint)
;;     (sender principal)
;;     (block-height uint)
;;   )
;; )

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

;; @desc Updates the TWAP data for a given asset and period.
;; @param asset The principal of the asset.
;; @param period The time period for the TWAP calculation (in seconds).
;; @param current-price The current price of the asset.
;; @returns A response with ok on success, or an error.
(define-public (update-twap (asset principal) (period uint) (current-price uint))
  (begin
    (try! (is-governance))
    (asserts! (> period u0) ERR-INVALID-PERIOD)

    (let
      ((current-block-height (unwrap-panic (get-block-info? time block-height)))
       (key { asset: asset, period: period })
       (existing-data (map-get? twap-data key))
      )
      (if (is-some existing-data)
        (let
          ((data (unwrap! existing-data (err u0)))
           (last-price (get last-price data))
           (last-timestamp (get last-timestamp data))
           (cumulative-price (get cumulative-price data))
           (samples (get samples data))
           (time-elapsed (- current-block-height last-timestamp))
          )
          (map-set twap-data key
            {
              last-price: current-price,
              last-timestamp: current-block-height,
              cumulative-price: (+ cumulative-price (* last-price time-elapsed)),
              samples: (+ samples u1)
            }
          )
        )
        (map-set twap-data key
          {
            last-price: current-price,
            last-timestamp: current-block-height,
            cumulative-price: u0,
            samples: u0
          }
        )
      )
    )
    (print { event: "twap-updated", asset: asset, period: period, twap: (get-twap asset period), sender: tx-sender, block-height: (unwrap-panic (get-block-info? time block-height)) })
    (ok true)
  )
)

;; @desc Sets the contract owner.
;; @param new-owner The principal of the new contract owner.
;; @returns A response with ok on success, or an error.
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (unwrap! (is-contract-owner) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @desc Sets the governance address.
;; @param new-governance The principal of the new governance address.
;; @returns A response with ok on success, or an error.
(define-public (set-governance-address (new-governance principal))
  (begin
    (asserts! (unwrap! (is-contract-owner) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
    (var-set governance-address new-governance)
    (ok true)
  )
)

;; Read-only Functions

;; @desc Gets the current TWAP for a given asset and period.
;; @param asset The principal of the asset.
;; @param period The time period for the TWAP calculation (in seconds).
;; @returns A response with the TWAP on success, or an error.
(define-read-only (get-twap (asset principal) (period uint))
  (let
    ((key { asset: asset, period: period })
     (data (unwrap! (map-get? twap-data key) ERR-NO-DATA))
    )
    (let
      ((last-price (get last-price data))
       (last-timestamp (get last-timestamp data))
       (cumulative-price (get cumulative-price data))
       (samples (get samples data))
       (current-block-height (unwrap-panic (get-block-info? time block-height)))
       (time-elapsed (- current-block-height last-timestamp))
      )
      (if (> samples u0)
        (ok (/ (+ cumulative-price (* last-price time-elapsed)) (+ samples u1)))
        (ok last-price) ;; If no samples, return the last price
      )
    )
  )
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
