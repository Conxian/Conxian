
;; Conxian Protocol - Utils Contract
;; Purpose: Provide utils-trait implementation using standard Clarity functions

(use-trait utils-trait .all-traits.utils-trait)
(use-trait utils_trait .all-traits.utils-trait)
 .all-traits.utils-trait)

(define-public (principal-to-buff (p principal))
  ;; Convert principal to buffer using standard Clarity functions
  ;; Principals can be converted to string and then to buffer
  (let ((principal-str (unwrap! (as-max-len? (to-string p) u42) (err u999))))
    (ok (unwrap! (string-to-utf8 principal-str) (err u999)))
  )
)