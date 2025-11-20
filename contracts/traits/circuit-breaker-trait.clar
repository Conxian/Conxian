;; circuit-breaker-trait.clar

(define-trait circuit-breaker-trait
  (
    (is-circuit-open () (response bool uint))
    (open-circuit () (response bool uint))
    (close-circuit () (response bool uint))
  )
)
