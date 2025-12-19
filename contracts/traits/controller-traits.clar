;; Controller Trait
;; Defines interface for token minting control and authorization

(define-trait controller (
  (can-emit
    (uint)
    (response bool uint)
  )
  (can-burn
    (uint)
    (response bool uint)
  )
  (is-authorized
    (principal)
    (response bool uint)
  )
))

(define-trait keeper-job-trait (
  (execute
    ()
    (response bool uint)
  )
))
