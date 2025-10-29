(define-private (sqrt-iter (n uint) (x uint))
  (let ((next-x (/ (+ x (/ n x)) u2)))
    (if (>= next-x x)
      x
      (sqrt-iter n next-x)
    )
  )
)
