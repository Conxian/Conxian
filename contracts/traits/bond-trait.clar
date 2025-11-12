;; ===========================================
;; BOND TRAIT
;; ===========================================
;; Interface for fixed-income bond instruments
;;
;; This trait provides functions to issue bonds, claim coupon payments,
;; and redeem bonds at maturity.
;;
;; Example usage:
;;   (use-trait bond .bond-trait.bond-trait)
(define-trait bond-trait
  (
    ;; Issue a new bond
    ;; @param name: bond name
    ;; @param symbol: bond symbol
    ;; @param decimals: number of decimals
    ;; @param initial-supply: initial supply of bonds
    ;; @param maturity-in-blocks: blocks until maturity
    ;; @param coupon-rate-scaled: coupon rate (scaled by 10^6)
    ;; @param frequency-in-blocks: blocks between coupon payments
    ;; @param payment-token-address: token used for payments
    ;; @return (response bool uint): success flag and error code
    (issue-bond ((string-ascii 32) (string-ascii 10) uint uint uint uint uint principal) (response bool uint))
    
    ;; Claim a coupon payment
    ;; @return (response uint uint): amount claimed and error code
    (claim-coupon () (response uint uint))
    
    ;; Redeem bond at maturity
    ;; @param payment-token: token to receive payment in
    ;; @return (response uint uint): amount redeemed and error code
    (redeem-at-maturity (principal) (response uint uint))
  )
)
