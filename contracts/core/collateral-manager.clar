;; @desc This contract manages the internal ledger of user balances and handles all deposits and withdrawals.

(use-trait collateral-manager-trait .trait-dimensional.collateral-manager-trait)
(use-trait sip-010-ft-trait .trait-sip-standards.sip-010-ft-trait)
(use-trait rbac-trait .trait-core-protocol.rbac-trait)

(impl-trait .dimensional-traits.collateral-manager-trait)

;; @constants
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u8001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u2003))

;; @data-vars
(define-map internal-balances principal uint)

;; --- Public Functions ---
(define-public (deposit-funds (amount uint) (token principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let ((user tx-sender))
      (try! (contract-call? token transfer amount user (as-contract tx-sender) none))

      (let ((current-balance (default-to u0 (map-get? internal-balances user))))
        (map-set internal-balances user (+ current-balance amount))
      )

      (ok true)
    )
  )
)

(define-public (withdraw-funds (amount uint) (token principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let ((user tx-sender)
          (current-balance (default-to u0 (map-get? internal-balances user))))

      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)

      (map-set internal-balances user (- current-balance amount))

      (try! (as-contract (contract-call? token transfer amount tx-sender user none)))

      (ok true)
    )
  )
)

(define-read-only (get-balance (user principal))
  (ok (default-to u0 (map-get? internal-balances user)))
)
