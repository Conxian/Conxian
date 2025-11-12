;; ===========================================
;; BOND FACTORY TRAIT
;; ===========================================
;; Interface for creating and managing bond tokens
;;
;; This trait provides functions to create bond tokens with specific terms
;; and manage the bond creation process.
;;
;; Example usage:
;;   (use-trait bond-factory .bond-factory-trait.bond-factory-trait)
(define-trait bond-factory-trait
  (
    ;; Create a new bond token
    ;; @param name: bond name
    ;; @param symbol: bond symbol
    ;; @param decimals: number of decimals
    ;; @param initial-supply: initial supply of bonds
    ;; @param maturity-in-blocks: blocks until maturity
    ;; @param coupon-rate-scaled: coupon rate (scaled by 10^6)
    ;; @param frequency-in-blocks: blocks between coupon payments
    ;; @param payment-token-address: token used for payments
    ;; @return (response bool uint): success flag and error code
    (create-bond ((string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool uint))

    ;; Get bond details by principal
    ;; @param bond-contract: principal of the bond contract
    ;; @return (response (tuple ...) uint): bond details and error code
    (get-bond-details (principal) (response (tuple (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (total-supply uint) (maturity-in-blocks uint) (coupon-rate-scaled uint) (frequency-in-blocks uint) (payment-token principal)) uint))

    ;; Get list of all created bonds
    ;; @return (response (list 20 principal) uint): list of bond principals and error code
    (get-all-bonds () (response (list 20 principal) uint))
  )
)
