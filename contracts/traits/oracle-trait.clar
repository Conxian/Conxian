;; oracle-trait.clar
;; Minimal oracle trait stub to satisfy legacy imports.

(define-trait oracle-trait
  (
    ;; Get the latest price for an asset pair identified by a string symbol.
    (get-price ((string-ascii 32)) (response uint uint))
  )
)
