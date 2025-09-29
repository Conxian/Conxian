;; mock-token.clar
;; Minimal SIP-010-compliant mock for testing

;; --- Traits ---
(use-trait sip-010-ft-trait '.all-traits.sip-010-ft-trait)
(impl-trait ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)

;; Constants
(define-constant TRAIT_REGISTRY 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.trait-registry)

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))

;; Basic token metadata and accounting (lightweight mock)
(define-data-var total-supply uint u0)
(define-data-var decimals uint u6)
(define-data-var name (string-ascii 32) "Mock Token")
(define-data-var symbol (string-ascii 10) "MOCK")
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-owner principal tx-sender)
(define-map balances { who: principal } { bal: uint })

;; --- SIP-010 functions ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_INVALID_AMOUNT))
    
    (let ((sender-bal (default-to u0 (get bal (map-get? balances {who: sender})))))
      (asserts! (>= sender-bal amount) (err ERR_INSUFFICIENT_BALANCE))
      
      (let ((recipient-bal (default-to u0 (get bal (map-get? balances {who: recipient})))))
        (map-set balances {who: sender} {bal: (- sender-bal amount)})
        (map-set balances {who: recipient} {bal: (+ recipient-bal amount)})
        (ok true)
      )
    )
  )
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (get bal (map-get? balances {who: who}))))
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
