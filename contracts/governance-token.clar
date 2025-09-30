;; governance-token.clar
;; Implements a SIP-010 fungible token for governance purposes

;; Traits
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_FUNDS (err u101))

;; Data Variables
(define-data-var token-name (string-ascii 32) "GovernanceToken")
(define-data-var token-symbol (string-ascii 10) "GOV")
(define-data-var token-decimals uint u6)
(define-data-var token-supply uint u100000000000000) ;; 100 million tokens with 6 decimals
(define-data-var contract-owner principal tx-sender)

;; Data Maps
(define-map token-balances {
  account: principal
} {
  amount: uint
})

;; SIP-010 Functions
(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-total-supply)
  (ok (var-get token-supply))
)

(define-read-only (get-balance (account principal))
  (ok (default-to u0 (get amount (map-get? token-balances { account: account })) ))
)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buffer 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (let (
      (sender-balance (get amount (map-get? token-balances { account: sender })))
      (recipient-balance (get amount (map-get? token-balances { account: recipient })))
    )
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_FUNDS)

      (map-set token-balances { account: sender } { amount: (- sender-balance amount) })
      (map-set token-balances { account: recipient } { amount: (+ recipient-balance amount) })

      (print (merge {
        event: "transfer",
        sender: sender,
        recipient: recipient,
        amount: amount
      } (if (is-some memo) { memo: (unwrap-panic memo) } { } )))
      (ok true)
    )
  )
)

;; Mint and Burn (for contract owner only)
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set token-supply (+ (var-get token-supply) amount))
    (map-set token-balances { account: recipient } { amount: (+ (get amount (map-get? token-balances { account: recipient })) amount) })
    (print { event: "mint", recipient: recipient, amount: amount })
    (ok true)
  )
)

(define-public (burn (amount uint) (sender principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((sender-balance (get amount (map-get? token-balances { account: sender })) ))
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_FUNDS)
      (var-set token-supply (- (var-get token-supply) amount))
      (map-set token-balances { account: sender } { amount: (- sender-balance amount) })
      (print { event: "burn", sender: sender, amount: amount })
      (ok true)
    )
  )
)