;; utils.clar
;; Common utility functions

(define-private (principal-to-buff (p principal))
  (sha256 (as-max-buff (tuple (p p))))
)