(define-trait math-trait
  (
    ;; Basic arithmetic operations
    (add (a uint) (b uint) (response uint (err uint)))
    (sub (a uint) (b uint) (response uint (err uint)))
    (mul (a uint) (b uint) (response uint (err uint)))
    (div (a uint) (b uint) (response uint (err uint)))
    (pow (base uint) (exp uint) (response uint (err uint)))
    (sqrt (a uint) (response uint (err uint)))

    ;; Percentage and ratio calculations
    (get-percentage (value uint) (percentage uint) (response uint (err uint)))
    (get-ratio (numerator uint) (denominator uint) (response uint (err uint)))

    ;; Min/Max functions
    (min (a uint) (b uint) (response uint (err uint)))
    (max (a uint) (b uint) (response uint (err uint)))

    ;; Absolute value (for int)
    (abs (a int) (response uint (err uint)))

    ;; Rounding functions
    (ceil (a uint) (b uint) (response uint (err uint)))
    (floor (a uint) (b uint) (response uint (err uint)))

    ;; Logarithms
    (log2 (a uint) (response uint (err uint)))
    (log10 (a uint) (response uint (err uint)))
    (ln (a uint) (response uint (err uint)))

    ;; Exponentials
    (exp (a uint) (response uint (err uint)))

    ;; Average
    (average (a uint) (b uint) (response uint (err uint)))

    ;; Weighted Average
    (weighted-average (value1 uint) (weight1 uint) (value2 uint) (weight2 uint) (response uint (err uint)))

    ;; Geometric Mean
    (geometric-mean (a uint) (b uint) (response uint (err uint)))

    ;; Standard Deviation
    (std-dev (values (list 100 uint)) (response uint (err uint)))

    ;; Interpolation
    (linear-interpolate (x uint) (x0 uint) (y0 uint) (x1 uint) (y1 uint) (response uint (err uint)))

    ;; Fixed-point arithmetic (assuming 1e8 or 1e18 precision)
    (fpow (base uint) (exp uint) (precision uint) (response uint (err uint)))
    (fsqrt (a uint) (precision uint) (response uint (err uint)))
    (fmul (a uint) (b uint) (precision uint) (response uint (err uint)))
    (fdiv (a uint) (b uint) (precision uint) (response uint (err uint)))
  )
)
