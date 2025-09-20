;; Oracle Trait
;; Defines the standard interface for price oracles in the Conxian protocol

(define-trait oracle-trait
  (
    ;; Get the current price of an asset
    (get-price (token principal) (response uint uint))
    
    ;; Update the price of an asset (restricted to oracle admin)
    (update-price (token principal) (price uint) (response bool uint))
    
    ;; Get the last update time for an asset
    (get-last-updated (token principal) (response uint uint))
    
    ;; Add a new price feed (admin only)
    (add-price-feed (token principal) (feed principal) (response bool uint))
    
    ;; Remove a price feed (admin only)
    (remove-price-feed (token principal) (response bool uint))
    
    ;; Set the heartbeat interval (admin only)
    (set-heartbeat (token principal) (interval uint) (response bool uint))
    
    ;; Set the maximum price deviation (admin only)
    (set-max-deviation (token principal) (deviation uint) (response bool uint))
    
    ;; Get the current deviation threshold for a token
    (get-deviation-threshold (token principal) (response uint uint))
    
    ;; Emergency price override (admin only)
    (emergency-price-override (token principal) (price uint) (response bool uint))
    
    ;; Check if a price is stale
    (is-price-stale (token principal) (response bool uint))
    
    ;; Get the number of feeds for a token
    (get-feed-count (token principal) (response uint uint))
    
    ;; Get the admin address
    (get-admin () (response principal uint))
    
    ;; Transfer admin rights
    (set-admin (new-admin principal) (response bool uint))
  )
)
