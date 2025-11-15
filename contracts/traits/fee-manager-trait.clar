;; ===========================================
;; FEE MANAGER TRAIT
;; ===========================================
;; @desc Interface for managing fee tiers.
;; This trait provides functions to validate fee tiers and get fee information.

(define-trait fee-manager-trait
  (
    ;; @desc Validate a fee tier.
    ;; @param fee-tier: A uint representing the fee tier.
    ;; @returns (response bool uint): True if the fee tier is valid, otherwise an error code.
    (validate-fee-tier (uint) (response bool uint))

    ;; @desc Get the fee rate for a given tier.
    ;; @param fee-tier: A uint representing the fee tier.
    ;; @returns (response uint uint): The fee rate (e.g., 300 for 0.3%), or an error code.
    (get-fee-rate (uint) (response uint uint))
  )
)
