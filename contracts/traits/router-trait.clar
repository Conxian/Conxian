;; router-trait.clar
;; This file is deprecated. Please use all-traits.clar instead.
;; The router-trait is now defined in all-traits.clar

;; router-trait.clar
;; Defines the interface for the DEX Router contract

(define-trait router-trait
  (
    ;; Get the factory contract address
    (get-factory-address () (response principal principal))
    
    ;; Set the factory contract address (admin only)
    (set-factory (principal) (response bool principal))
    
    ;; Transfer contract ownership (admin only)
    (transfer-ownership (principal) (response bool principal))
    
    ;; Swap exact tokens for tokens along a specified path
    (swap-exact-tokens-for-tokens 
      (uint uint (list 5 principal) uint)  ; amount-in, min-amount-out, path, deadline
      (response uint principal)            ; returns amount-out or error
    )
  )
)
