;; dlc-manager-trait.clar
;; Interface for managing Discreet Log Contracts (DLCs)
;; Enables Native Bitcoin Financial Services (Dimension 4 & 5)

(define-trait dlc-manager-trait
  (
    ;; @desc Register a new DLC that has been broadcast to Bitcoin
    ;; @param dlc-uuid: The unique identifier of the DLC
    ;; @param value-locked: The amount of BTC locked (in sats)
    ;; @param owner: The principal of the DLC owner (borrower)
    ;; @param loan-id: The associated loan ID in the lending protocol
    ;; @returns (response bool uint): True if registered successfully
    (register-dlc ((buff 32) uint principal uint) (response bool uint))

    ;; @desc Close a DLC normally (Repayment or Expiry)
    ;; @param dlc-uuid: The unique identifier of the DLC
    ;; @returns (response bool uint): True if closed successfully
    (close-dlc ((buff 32)) (response bool uint))

    ;; @desc Liquidate a DLC (Force Close due to risk health)
    ;; @param dlc-uuid: The unique identifier of the DLC
    ;; @returns (response bool uint): True if liquidation triggered successfully
    (liquidate-dlc ((buff 32)) (response bool uint))

    ;; @desc Get DLC details
    ;; @param dlc-uuid: The unique identifier of the DLC
    ;; @returns (response (optional { ... }) uint): The DLC details
    (get-dlc-info ((buff 32)) (response (optional {
      owner: principal,
      value-locked: uint,
      loan-id: uint,
      status: (string-ascii 20),
      closing-price: (optional uint)
    }) uint))
  )
)
