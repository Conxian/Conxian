;; standard-constants-trait.clar
;; Defines standard constants and interfaces for the Conxian protocol

(define-trait standard-constants-trait
  (
    ;; Precision and mathematical constants (18 decimals)
    (get-precision) (response uint uint)
    (get-basis-points) (response uint uint)
    
    ;; Common time constants (in blocks, assuming ~1 block per minute)
    (get-blocks-per-minute) (response uint uint)
    (get-blocks-per-hour) (response uint uint)
    (get-blocks-per-day) (response uint uint)
    (get-blocks-per-week) (response uint uint)
    (get-blocks-per-year) (response uint uint)
    
    ;; Common percentage values (in basis points)
    (get-max-bps) (response uint uint)
    (get-one-hundred-percent) (response uint uint)
    (get-fifty-percent) (response uint uint)
    (get-zero) (response uint uint)
    
    ;; Common precision values
    (get-precision-18) (response uint uint)
    (get-precision-8) (response uint uint)
    (get-precision-6) (response uint uint)
  )
)
