;; ===========================================
;; BOND TRAIT
;; ===========================================
;; @desc Interface for fixed-income bond instruments.
;; This trait provides functions to issue bonds, claim coupon payments,
;; and redeem bonds at maturity.
;;
;; @example
;; (use-trait bond .bond-trait.bond-trait)
(define-trait bond-trait
  (
    ;; @desc Issue a new bond.
    ;; @param name: The name of the bond.
    ;; @param symbol: The symbol of the bond.
    ;; @param decimals: The number of decimals for the bond token.
    ;; @param initial-supply: The initial supply of the bond tokens.
    ;; @param maturity-in-blocks: The number of blocks until the bond matures.
    ;; @param coupon-rate-scaled: The coupon rate, scaled by 10^6.
    ;; @param frequency-in-blocks: The number of blocks between coupon payments.
    ;; @param payment-token-address: The address of the token used for payments.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (issue-bond ((string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool uint))
    
    ;; @desc Claim a coupon payment.
    ;; @returns (response uint uint): The amount of the coupon payment, or an error code.
    (claim-coupon () (response uint uint))
    
    ;; @desc Redeem the bond at maturity.
    ;; @param payment-token: The token to receive payment in.
    ;; @returns (response uint uint): The amount redeemed, or an error code.
    (redeem-at-maturity (principal) (response uint uint))
  )
)
