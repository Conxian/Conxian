;; dimensional-oracle-trait.clar
;; This file is deprecated. Please use all-traits.clar instead.
;; The dimensional-oracle-trait is now defined in all-traits.clar

;; dimensional-oracle-trait.clar
;;
;; Trait for the dimensional oracle.
;;
(define-trait dimensional-oracle-trait
  (
    (update-weights ((list 10 {dim-id: uint, new-wt: uint})) (response bool uint))
  )
)





