;; ===========================================
;; FEE MANAGER TRAIT
;; ===========================================
;; Interface for managing fee tiers
;;
;; This trait provides functions to validate fee tiers and get fee information.

(define-trait fee-manager-trait
  (
    ;; Validate a fee tier
    ;; @param fee-tier: uint representing the fee tier
    ;; @return (response bool uint): true if valid, error code otherwise
    (validate-fee-tier (uint) (response bool uint))

    ;; Get the fee rate for a given tier
    ;; @param fee-tier: uint representing the fee tier
    ;; @return (response uint uint): fee rate (e.g., 300 for 0.3%) and error code
    (get-fee-rate (uint) (response uint uint))
  )
)
