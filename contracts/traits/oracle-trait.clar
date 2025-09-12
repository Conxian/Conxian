;; oracle-trait.clar
;; Standard interface for price oracles in the Conxian protocol

(define-trait oracle-trait
  (
    ;; Get the current price of an asset in USD with 18 decimals
    (get-price (asset principal)) (response uint uint)
    
    ;; Get the last update time of an asset's price
    (get-last-update (asset principal)) (response uint uint)
    
    ;; Check if an asset's price is fresh (not stale)
    (is-price-fresh (asset principal)) (response bool uint)
    
    ;; Get the price with freshness check
    (get-price-fresh (asset principal)) (response uint uint)
    
    ;; Set the price of an asset (admin only)
    (set-price (asset principal) (price uint)) (response bool uint)
    
    ;; Set the oracle contract address (admin only)
    (set-oracle-contract (contract principal)) (response bool uint)
    
    ;; Get the oracle contract address
    (get-oracle-contract) (response (optional principal) uint)
  )
)
