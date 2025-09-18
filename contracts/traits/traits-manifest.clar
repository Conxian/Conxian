(define-trait sip-010-ft-trait
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-decimals () (response uint uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

(define-trait access-control-trait
  (
    (has-role (principal (string-ascii 32)) (response bool uint))
    (grant-role (principal (string-ascii 32)) (response bool uint))
    (revoke-role (principal (string-ascii 32)) (response bool uint))
  )
)

;; This file intentionally left blank as all traits are now defined in their respective files.
;; Use direct trait references in your contracts instead.
