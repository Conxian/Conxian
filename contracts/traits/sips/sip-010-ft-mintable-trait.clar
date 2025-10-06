(define-trait sip-010-ft-mintable-trait
  (
    (mint (amount uint) (recipient principal) (response bool (err uint)))
    (burn (amount uint) (owner principal) (response bool (err uint)))
    (get-token-uri () (response (optional (string-utf8 256)) (err uint)))
  )
)
