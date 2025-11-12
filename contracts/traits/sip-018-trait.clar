;; ===========================================
;; SIP-018 TRAIT
;; ===========================================
;; Standard interface for fungible token metadata (SIP-018).
;;
;; This trait defines a function to retrieve the URI for token metadata.
;;
;; Example usage:
;;   (use-trait ft-metadata .sip-018-trait)
(define-trait sip-018-trait
  (
    ;; Get the URI for the token metadata.
    ;; @return (response (optional (string-utf8 256)) uint): URI string and error code
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
