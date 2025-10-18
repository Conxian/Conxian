;; Conxian Protocol - Utils Contract (Stub)
;; Purpose: Provide utils-trait implementation to satisfy compilation dependencies.
;; Note: principal-to-buff is not supported in standard Clarity. This stub returns an error.


(use-trait utils-trait .all-traits.utils-trait)
(impl-trait utils-trait)
(define-public (principal-to-buff (p principal))
  (err u999)
)