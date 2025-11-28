;; block-utils.clar
;; Centralized wrappers for Nakamoto primitives for BTC finality and tenure

(define-constant ERR_INVALID_HEIGHT (err u10001))
(define-constant ERR_TENURE_INFO_FAILED (err u10002))

(define-read-only (get-burn-height)
  burn-block-height)

(define-read-only (get-burn-timestamp)
  (default-to u0 (get-block-info? time (- block-height u1))))

(define-read-only (get-tip-tenure-id)
  0x0000000000000000000000000000000000000000000000000000000000000000
)
