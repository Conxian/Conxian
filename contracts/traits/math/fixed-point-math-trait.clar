(define-trait fixed-point-math-trait
  (
    (mul-fixed (a uint) (b uint) (precision uint) (response uint (err uint)))
    (div-fixed (a uint) (b uint) (precision uint) (response uint (err uint)))
    (pow-fixed (base uint) (exp uint) (precision uint) (response uint (err uint)))
    (sqrt-fixed (a uint) (precision uint) (response uint (err uint)))
  )
)
