;; ===========================================
;; BTC ADAPTER TRAIT
;; ===========================================
;; Interface for Bitcoin integration functionality
;;
;; This trait provides functions to wrap and unwrap Bitcoin
;; for use within the Stacks ecosystem.
;;
;; Example usage:
;;   (use-trait btc-adapter .btc-adapter-trait.btc-adapter-trait)
(define-trait btc-adapter-trait
  (
    ;; Wrap Bitcoin into a Stacks token
    ;; @param amount: amount of BTC to wrap
    ;; @param btc-tx-id: Bitcoin transaction ID
    ;; @return (response uint uint): wrapped amount and error code
    (wrap-btc (uint (buff 32)) (response uint uint))
    
    ;; Unwrap Stacks token back to Bitcoin
    ;; @param amount: amount to unwrap
    ;; @param btc-address: Bitcoin address to send to
    ;; @return (response bool uint): success flag and error code
    (unwrap-btc (uint (buff 64)) (response bool uint))
    
    ;; Get wrapped Bitcoin balance for a user
    ;; @param user: user principal
    ;; @return (response uint uint): wrapped balance and error code
    (get-wrapped-balance (principal) (response uint uint))
  )
)
