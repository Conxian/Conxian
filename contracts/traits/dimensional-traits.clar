;; ===========================================
;; DIMENSIONAL TRAITS MODULE
;; ===========================================
;; @desc Multi-dimensional DeFi specific traits.
;; Optimized for complex position management.

;; ===========================================
;; DIMENSIONAL TRAIT
;; ===========================================
;; @desc Interface for a dimensional position.
(define-trait dimensional-trait
  (
    ;; @desc Gets the details of a specific position.
    ;; @param position-id: The ID of the position to retrieve.
    ;; @returns (response (optional { ... }) uint): A tuple containing the position details, or none if the position is not found.
    (get-position (uint) (response (optional {
      owner: principal,
      asset: principal,
      collateral: uint,
      size: uint,
      entry-price: uint,
      leverage: uint,
      is-long: bool
    }) uint))

    ;; @desc Closes a position.
    ;; @param position-id: The ID of the position to close.
    ;; @param amount: The amount of the position to close.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (close-position (uint uint) (response bool uint))

    ;; @desc Gets the protocol statistics.
    ;; @returns (response { ... } uint): A tuple containing the protocol statistics, or an error code.
    (get-protocol-stats () (response {
      total-positions: uint,
      total-volume: uint,
      total-value-locked: uint
    } uint))
  )
)

