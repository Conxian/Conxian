;; bond-trait.clar
;; Defines the interface for bond contracts in the Conxian protocol

(define-trait bond-trait
  (
    ;; Get bond information
    (get-bond-info () (response (tuple 
      (issuer principal)
      (underlying-asset principal)
      (face-value uint)
      (maturity-height uint)
      (is-mature bool)
      (total-issued uint)
      (total-redeemed uint)
    ) uint))

    ;; Get bond balance for a principal
    (get-balance (principal) (response uint uint))

    ;; Issue new bonds
    (issue (principal uint uint) (response uint uint))  ; (to amount maturity-height)

    ;; Redeem bonds for underlying asset
    (redeem (uint) (response uint uint))  ; (amount)

    ;; Check if bond is mature
    (is-bond-mature () (response bool uint))

    ;; Get bond price in underlying asset
    (get-bond-price () (response uint uint))

    ;; Get bond yield
    (get-yield () (response uint uint))
  )
)
