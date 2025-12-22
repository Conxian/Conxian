;; yield-token.clar
;; Implements a SIP-010 fungible token for yield-bearing purposes.
;; This token is non-transferable by users to act as a "loyalty point" or "status" metric.

;; Traits
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
(impl-trait .defi-traits.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))
(define-constant ERR_TRANSFER_NOT_PERMITTED (err u103))

;; Data Variables
(define-data-var token-name (string-ascii 32) "ConxianYield")
(define-data-var token-symbol (string-ascii 10) "CXY")
(define-data-var token-decimals uint u6)
(define-data-var token-supply uint u0)
(define-data-var token-uri (optional (string-utf8 256)) none)

(define-data-var contract-owner principal tx-sender)
(define-data-var minter-contract principal tx-sender)

;; Data Maps
(define-map token-balances
  { account: principal }
  { amount: uint }
)

;; --- SIP-010 Standard Functions ---

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (get amount (map-get? token-balances { account: account }))))
)

(define-read-only (get-total-supply)
  (ok (var-get token-supply))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    ;; The Shield: This token is non-transferable by users.
    ;; Only the minter contract (protocol-coordinator) can move these tokens.
    (asserts! (is-eq tx-sender (var-get minter-contract)) ERR_TRANSFER_NOT_PERMITTED)

    (let ((sender-balance (unwrap! (get-balance sender) ERR_INSUFFICIENT_FUNDS)))
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_FUNDS)

      (map-set token-balances { account: sender } { amount: (- sender-balance amount) })
      (map-set token-balances { account: recipient } { amount: (+ (unwrap! (get-balance recipient) (err u0)) amount) })

      (print {
        event: "transfer",
        sender: sender,
        recipient: recipient,
        amount: amount,
      })
      (ok true)
    )
  )
)

;; --- Administrative Functions ---

(define-public (set-minter (new-minter principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set minter-contract new-minter)
    (ok true)
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get minter-contract)) ERR_UNAUTHORIZED)
    (let ((recipient-balance (unwrap! (get-balance recipient) (err u0))))
      (var-set token-supply (+ (var-get token-supply) amount))
      (map-set token-balances { account: recipient } { amount: (+ recipient-balance amount) })

      (print {
        event: "mint",
        recipient: recipient,
        amount: amount,
      })
      (ok true)
    )
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get minter-contract)) ERR_UNAUTHORIZED)
    (let ((owner-balance (unwrap! (get-balance owner) ERR_INSUFFICIENT_FUNDS)))
      (asserts! (>= owner-balance amount) ERR_INSUFFICIENT_FUNDS)
      (var-set token-supply (- (var-get token-supply) amount))
      (map-set token-balances { account: owner } { amount: (- owner-balance amount) })

      (print {
        event: "burn",
        owner: owner,
        amount: amount,
      })
      (ok true)
    )
  )
)
