(define-trait compliance-hooks-trait
  (
    (before-transfer (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))) (response bool (err uint)))
    (after-transfer (sender principal) (recipient principal) (amount uint) (memo (optional (buff 34))) (response bool (err uint)))
  )
)
