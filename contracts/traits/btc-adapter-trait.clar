;; ===========================================
;; BTC ADAPTER TRAIT
;; ===========================================
;; @desc Interface for Bitcoin integration functionality.
;; This trait provides functions to wrap and unwrap Bitcoin
;; for use within the Stacks ecosystem.
;;
;; @example
;; (use-trait btc-adapter .btc-adapter-trait.btc-adapter-trait)
(define-trait btc-adapter-trait
  (
    ;; @desc Wrap Bitcoin into a Stacks token.
    ;; @param amount: The amount of BTC to wrap.
    ;; @param btc-tx-id: The Bitcoin transaction ID.
    ;; @returns (response uint uint): The amount of the wrapped token, or an error code.
    (wrap-btc (uint (buff 32)) (response uint uint))
    
    ;; @desc Unwrap a Stacks token back to Bitcoin.
    ;; @param amount: The amount to unwrap.
    ;; @param btc-address: The Bitcoin address to send the unwrapped BTC to.
    ;; @returns (response bool uint): A boolean indicating success or failure, or an error code.
    (unwrap-btc (uint (buff 64)) (response bool uint))
    
    ;; @desc Get the wrapped Bitcoin balance for a user.
    ;; @param user: The principal of the user to query.
    ;; @returns (response uint uint): The wrapped balance of the user, or an error code.
    (get-wrapped-balance (principal) (response uint uint))
  )
)
