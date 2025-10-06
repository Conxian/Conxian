(define-trait standard-constants-trait
  (
    ;; Precision and mathematical constants (18 decimals)
    (get-precision () (response uint (err uint)))
    (get-basis-points () (response uint (err uint)))

    ;; Common time constants (in blocks, assuming ~1 block per minute)
    (get-blocks-per-minute () (response uint (err uint)))
    (get-blocks-per-hour () (response uint (err uint)))
    (get-blocks-per-day () (response uint (err uint)))
    (get-blocks-per-week () (response uint (err uint)))
    (get-blocks-per-year () (response uint (err uint)))

    ;; Common percentage values (in basis points)
    (get-max-bps () (response uint (err uint)))
    (get-one-hundred-percent () (response uint (err uint)))
    (get-fifty-percent () (response uint (err uint)))
    (get-zero () (response uint (err uint)))

    ;; Common precision values
    (get-precision-18 () (response uint (err uint)))
    (get-precision-8 () (response uint (err uint)))
    (get-precision-6 () (response uint (err uint)))
  )
)
