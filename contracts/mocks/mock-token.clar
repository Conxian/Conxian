;; mock-token.clar
;; Minimal SIP-010-compliant mock for testing dynamic dispatch

(impl-trait sip-010-trait.sip-010-trait)

;; Basic token metadata and accounting (lightweight mock)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Mock Token")
(define-data-var symbol (string-ascii 10) "MOCK")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-map balances { who: principal } { bal: uint })

;; --- SIP-010 functions ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    ;; For testing, simply succeed when sender authorizes the call
    (asserts! (is-eq tx-sender sender) (err u1))
    (ok true)
  )
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (get bal (map-get? balances { who: who }))))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-decimals)
  (ok (var-get decimals))
)

(define-read-only (get-name)
  (ok (var-get name))
)

(define-read-only (get-symbol)
  (ok (var-get symbol))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (set-token-uri (value (optional (string-utf8 256))))
  (begin
    (var-set token-uri value)
    (ok true)
  )
)





