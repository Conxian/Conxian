;; ===========================================
;; BOND FACTORY TRAIT
;; ===========================================
;; @desc Interface for creating and managing bond tokens.
;; This trait provides functions to create bond tokens with specific terms
;; and manage the bond creation process.
;;
;; @example
;; (use-trait bond-factory .bond-factory-trait.bond-factory-trait)
(define-trait bond-factory-trait
  (
    ;; @desc Create a new bond token.
    ;; @param name: The name of the bond.
    ;; @param symbol: The symbol of the bond.
    ;; @param decimals: The number of decimals for the bond token.
    ;; @param initial-supply: The initial supply of the bond tokens.
    ;; @param maturity-in-blocks: The number of blocks until the bond matures.
    ;; @param coupon-rate-scaled: The coupon rate, scaled by 10^6.
    ;; @param frequency-in-blocks: The number of blocks between coupon payments.
    ;; @param payment-token-address: The address of the token used for payments.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (create-bond ((string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool uint))

    ;; @desc Get the details of a specific bond by its principal.
    ;; @param bond-contract: The principal of the bond contract.
    ;; @returns (response (tuple ...) uint): A tuple containing the bond details, or an error code.
    (get-bond-details (principal) (response (tuple (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (total-supply uint) (maturity-in-blocks uint) (coupon-rate-scaled uint) (frequency-in-blocks uint) (payment-token principal)) uint))

    ;; @desc Get a list of all bonds created by this factory.
    ;; @returns (response (list 20 principal) uint): A list of the principals of all created bonds, or an error code.
    (get-all-bonds () (response (list 20 principal) uint))
  )
)
