;; ===========================================
;; SIP-018 TRAIT
;; ===========================================
;; @desc Standard interface for fungible token metadata (SIP-018).
;; This trait defines a function to retrieve the URI for token metadata.
;;
;; @example
;; (use-trait ft-metadata .sip-018-trait)
(define-trait sip-018-trait
  (
    ;; @desc Get the URI for the token metadata.
    ;; @returns (response (optional (string-utf8 256)) uint): The URI string, or an error code.
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
