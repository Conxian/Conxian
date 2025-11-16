;; oracle-adapter-stub.clar
;; Minimal stub contract used while the full external-oracle-adapter is being redesigned.

(define-data-var oracle-adapter-initialized bool true)

(define-read-only (is-initialized)
  (ok (var-get oracle-adapter-initialized))
)
