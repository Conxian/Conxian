;; price-impact-calculator.clar
;; Calculates price impact for trades in DEX liquidity pools

(use-trait ft-trait .all-traits.sip-010-ft-trait)

;; Error codes
(define-constant ERR-POOL-NOT-FOUND (err u2000))
(define-constant ERR-INVALID-AMOUNT (err u2001))
(define-constant ERR-INSufficient-LIQUIDITY (err u2002))

;; Data Maps
;; Stores pool reserves (token-x, token-y)
(define-map pool-reserves { pool-id: uint } { token-x: uint, token-y: uint })

;; Data Variables
(define-data-var governance principal tx-sender)

;; Events
(define-event price-impact-calculated
  (tuple
    (event (string-ascii 16))
    (pool-id uint)
    (trade-amount uint)
    (impact-bps uint)
    (sender principal)
    (block-height uint)
  )
)

;; Private Helpers
(define-private (get-reserves (pool-id uint))
  (unwrap! (map-get? pool-reserves { pool-id: pool-id }) ERR-POOL-NOT-FOUND)
)

;; Public Functions
;; @desc Updates reserves for a pool (called by liquidity pool contracts)
(define-public (update-reserves (pool-id uint) (token-x uint) (token-y uint))
  (begin
    (asserts! (is-eq tx-sender (var-get governance)) ERR-NOT-AUTHORIZED)
    (map-set pool-reserves { pool-id: pool-id } { token-x: token-x, token-y: token-y })
    (ok true)
  )
)

;; @desc Calculates price impact for a token-x buy (uses token-y as payment)
;; @param pool-id: ID of the liquidity pool
;; @param amount-x: Amount of token-x to buy
;; @returns Price impact in basis points (1/100 of 1%)
(define-public (calculate-impact-buy-x (pool-id uint) (amount-x uint))
  (begin
    (asserts! (> amount-x u0) ERR-INVALID-AMOUNT)
    (let
      ((reserves (get-reserves pool-id))
       (token-x-reserve (get token-x reserves))
       (token-y-reserve (get token-y reserves))
      )
      (asserts! (> token-x-reserve amount-x) ERR-INSufficient-LIQUIDITY)
      
      ;; Price impact formula: [( (R_y * (R_x / (R_x - Δx)) ) - R_y ) / R_y ] * 10000
      (let
        ((new-y-reserve (* token-y-reserve (/ token-x-reserve (- token-x-reserve amount-x))))
         (delta-y (- new-y-reserve token-y-reserve))
         (impact-bps (* (/ delta-y token-y-reserve) u10000))
        )
        (print (tuple
          (event "price-impact-calculated")
          (pool-id pool-id)
          (trade-amount amount-x)
          (impact-bps impact-bps)
          (sender tx-sender)
          (block-height (get-block-info? block-height))
        ))
        (ok impact-bps)
      )
    )
  )
)

;; Read-only Functions
(define-read-only (get-price-impact (pool-id uint) (amount-x uint))
  (calculate-impact-buy-x pool-id amount-x)
)

(define-read-only (get-governance)
  (ok (var-get governance))
)