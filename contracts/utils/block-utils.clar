;; block-utils.clar
;; Centralized wrappers for Nakamoto primitives for BTC finality and tenure

(define-read-only (burn-info)
  ;; TODO: replace stub with proper get-burn-block-info? call and structure
  none)

(define-read-only (tenure-info)
  ;; TODO: replace stub with proper get-tenure-info? call and structure
  none)

;; Minimal wrappers for Nakamoto primitives (placeholders for now)

(define-read-only (get-burn-height)
  u0)

(define-read-only (get-burn-timestamp)
  u0)

(define-read-only (get-tenure-id)
  u0)

(define-read-only (get-tenure-start)
  u0)
