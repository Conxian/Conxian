(define-trait error-codes-trait
  (
    (get-error-message (error-code uint) (response (string-ascii 256) (err uint)))
    (is-valid-error (error-code uint) (response bool (err uint)))
  )
)
