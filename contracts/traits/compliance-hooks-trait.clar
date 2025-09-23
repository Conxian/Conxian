;; compliance-hooks-trait.clar
;; Trait for compliance hooks in the enterprise API

(define-trait compliance-hooks-trait
  (
    (verify-account (principal) (response bool uint))
  )
)