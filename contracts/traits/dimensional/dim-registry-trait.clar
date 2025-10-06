(define-trait dim-registry-trait
  (
    (register-dimension (name (string-ascii 64)) (description (string-utf8 256)) (response uint (err uint)))
    (get-dimension (dim-id uint) (response (tuple (name (string-ascii 64)) (description (string-utf8 256)) (active bool)) (err uint)))
    (update-dimension-status (dim-id uint) (active bool) (response bool (err uint)))
    (get-dimension-count () (response uint (err uint)))
  )
)
