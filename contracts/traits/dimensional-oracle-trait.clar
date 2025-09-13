;; dimensional-oracle-trait.clar
;;
;; Trait for the dimensional oracle.
;;
(define-trait dimensional-oracle-trait
  (
    (update-weights ((list 10 {dim-id: uint, new-wt: uint})) (response bool uint))
  )
)



