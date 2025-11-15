;; ===========================================
;; FUNDING TRAIT
;; ===========================================
;; @desc Interface for funding rate calculations and position funding.
;; This trait provides functions for perpetual contract funding mechanisms
;; including rate calculation and position funding application.
;;
;; @example
;; (use-trait funding .funding-trait.funding-trait)
;; (define-public (update-rates (funding-contract principal))
;;   (contract-call? funding-contract update-funding-rate asset))
(define-trait funding-trait
  (
    ;; @desc Update the funding rate for an asset.
    ;; @param asset: The asset to update the funding rate for.
    ;; @returns (response (tuple ...) uint): A tuple containing the funding rate data, or an error code.
    (update-funding-rate (principal) (response (tuple (funding-rate int) (index-price uint) (timestamp uint) (cumulative-funding int)) uint))

    ;; @desc Apply funding to a position.
    ;; @param position-owner: The owner of the position.
    ;; @param position-id: The identifier of the position.
    ;; @returns (response (tuple ...) uint): A tuple containing the funding payment data, or an error code.
    (apply-funding-to-position (principal uint) (response (tuple (funding-rate int) (funding-payment uint) (new-collateral uint) (timestamp uint)) uint))

    ;; @desc Get the current funding rate for an asset.
    ;; @param asset: The asset to get the funding rate for.
    ;; @returns (response (tuple ...) uint): A tuple containing the current funding rate data, or an error code.
    (get-current-funding-rate (principal) (response (tuple (rate int) (last-updated uint) (next-update uint)) uint))

    ;; @desc Get the funding rate history for an asset.
    ;; @param asset: The asset to get the history for.
    ;; @param from-block: The start block.
    ;; @param to-block: The end block.
    ;; @param limit: The maximum number of entries.
    ;; @returns (response (list ...) uint): A list of the funding rate history, or an error code.
    (get-funding-rate-history (principal uint uint uint) (response (list 20 (tuple (rate int) (index-price uint) (open-interest-long uint) (open-interest-short uint) (timestamp uint))) uint))

    ;; @desc Set the funding parameters (admin only).
    ;; @param interval: The funding interval in blocks.
    ;; @param max-rate: The maximum funding rate.
    ;; @param sensitivity: The funding rate sensitivity.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (set-funding-parameters (uint uint uint) (response bool uint))
  )
)
