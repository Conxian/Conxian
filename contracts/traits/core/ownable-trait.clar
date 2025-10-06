(define-trait ownable-trait
  (
    (get-owner () (response principal (err uint)))
    (transfer-ownership (new-owner principal) (response bool (err uint)))
    (renounce-ownership () (response bool (err uint)))
  )
)
