;; ===========================================
;; FUNDING TRAIT
;; ===========================================
;; Interface for funding rate calculations and position funding
;;
;; This trait provides functions for perpetual contract funding mechanisms
;; including rate calculation and position funding application.
;;
;; Example usage:
;;   (use-trait funding .funding-trait.funding-trait)
;;   (define-public (update-rates (funding-contract principal))
;;     (contract-call? funding-contract update-funding-rate asset))
(define-trait funding-trait
  (
    ;; Update funding rate for an asset
    ;; @param asset: asset to update funding rate for
    ;; @return (response (tuple ...) uint): funding rate data and error code
    (update-funding-rate (principal) (response (tuple (funding-rate int) (index-price uint) (timestamp uint) (cumulative-funding int)) uint))

    ;; Apply funding to a position
    ;; @param position-owner: owner of the position
    ;; @param position-id: position identifier
    ;; @return (response (tuple ...) uint): funding payment data and error code
    (apply-funding-to-position (principal uint) (response (tuple (funding-rate int) (funding-payment uint) (new-collateral uint) (timestamp uint)) uint))

    ;; Get current funding rate for an asset
    ;; @param asset: asset to get funding rate for
    ;; @return (response (tuple ...) uint): current funding rate data and error code
    (get-current-funding-rate (principal) (response (tuple (rate int) (last-updated uint) (next-update uint)) uint))

    ;; Get funding rate history
    ;; @param asset: asset to get history for
    ;; @param from-block: start block
    ;; @param to-block: end block
    ;; @param limit: maximum number of entries
    ;; @return (response (list ...) uint): funding rate history and error code
    (get-funding-rate-history (principal uint uint uint) (response (list 20 (tuple (rate int) (index-price uint) (open-interest-long uint) (open-interest-short uint) (timestamp uint))) uint))

    ;; Set funding parameters (admin only)
    ;; @param interval: funding interval in blocks
    ;; @param max-rate: maximum funding rate
    ;; @param sensitivity: funding rate sensitivity
    ;; @return (response bool uint): success flag and error code
    (set-funding-parameters (uint uint uint) (response bool uint))
  )
)
