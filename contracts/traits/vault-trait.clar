;; Vault Trait - Core vault interface for Conxian DeFi system
;; Supports SIP-010 tokens and enhanced tokenomics integration

(define-trait vault-trait
  (
    ;; Core vault operations
    (deposit (principal uint) (response (tuple (shares uint) (fee uint)) uint))
    (withdraw (principal uint) (response (tuple (amount uint) (fee uint)) uint))
    (flash-loan (uint principal) (response bool uint))
    
    ;; Asset management  
    (get-total-balance (principal) (response uint uint))
    (get-total-shares (principal) (response uint uint))
    (get-user-shares (principal principal) (response uint uint))
    
    ;; Vault configuration
    (get-deposit-fee () (response uint uint))
    (get-withdrawal-fee () (response uint uint))
    (get-vault-cap (principal) (response uint uint))
    (is-paused () (response bool uint))
    
    ;; Enhanced tokenomics integration
    (get-revenue-share () (response uint uint))
    (collect-protocol-fees (principal) (response uint uint))
  )
)




