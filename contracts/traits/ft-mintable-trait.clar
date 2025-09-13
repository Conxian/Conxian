;; ft-mintable-trait.clar
;; Minimal trait for FT contracts that expose a mint function

(define-trait ft-mintable-trait
  (
    ;; Mint amount to recipient. Returns (ok true) or (err <code>)
    (mint (principal uint) (response bool uint))
  )
)



