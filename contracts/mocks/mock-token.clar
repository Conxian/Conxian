;; mock-token.clar
;; Mock ERC-20 token for testing

(impl-trait .sip-standards.sip-010-ft-trait)

;; ===== Constants =====
(define-constant TOKEN_NAME "Mock Token")
(define-constant TOKEN_SYMBOL "MOCK")
(define-constant TOKEN_DECIMALS 6)
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1001))
(define-constant ERR_INVALID_AMOUNT (err u1002))

;; ===== Data Variables =====
(define-data-var name (string-ascii 32) TOKEN_NAME)
(define-data-var symbol (string-ascii 10) TOKEN_SYMBOL)
(define-data-var decimals uint (to-uint TOKEN_DECIMALS))
(define-data-var total-supply uint u0)
(define-data-var admin principal tx-sender)
(define-data-var token-uri (optional (string-utf8 256)) none)

;; Balances
(define-map balances
  principal
  uint
)

;; Allowances
(define-map allowances
  {
    owner: principal,
    spender: principal,
  }
  uint
)

;; ===== Public Functions =====
(define-public (transfer
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts!
      (or (is-eq tx-sender sender) (is-eq tx-sender (as-contract tx-sender)))
      ERR_UNAUTHORIZED
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let (
        (sender-balance (default-to u0 (map-get? balances sender)))
        (recipient-balance (default-to u0 (map-get? balances recipient)))
      )
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)

      (map-set balances sender (- sender-balance amount))
      (map-set balances recipient (+ recipient-balance amount))

      (match memo
        m (begin
          (print m)
          (ok true)
        )
        (ok true)
      )
    )
  )
)

(define-public (get-name)
  (ok (var-get name))
)

(define-public (get-symbol)
  (ok (var-get symbol))
)

(define-public (get-decimals)
  (ok (var-get decimals))
)

(define-public (get-balance (who principal))
  (ok (default-to u0 (map-get? balances who)))
)

(define-public (get-total-supply)
  (ok (var-get total-supply))
)

(define-public (get-token-uri)
  (ok (var-get token-uri))
)

(define-public (transfer-from
    (amount uint)
    (sender principal)
    (recipient principal)
    (memo (optional (buff 34)))
  )
  (let (
      (allowance (default-to u0
        (map-get? allowances {
          owner: sender,
          spender: tx-sender,
        })
      ))
      (new-allowance (- allowance amount))
    )
    (asserts! (>= allowance amount) ERR_UNAUTHORIZED)

    (if (<= new-allowance u0)
      (map-delete allowances {
        owner: sender,
        spender: tx-sender,
      })
      (map-set allowances {
        owner: sender,
        spender: tx-sender,
      }
        new-allowance
      )
    )
    ;; Perform transfer logic directly (bypass transfer's tx-sender check)
    (let (
        (sender-balance (default-to u0 (map-get? balances sender)))
        (recipient-balance (default-to u0 (map-get? balances recipient)))
      )
      (asserts! (>= sender-balance amount) ERR_INSUFFICIENT_BALANCE)
      (map-set balances sender (- sender-balance amount))
      (map-set balances recipient (+ recipient-balance amount))
      (match memo
        m (begin
          (print m)
          true
        )
        true
      )
      (ok true)
    )
  )
)

(define-public (approve
    (spender principal)
    (amount uint)
    (memo (optional (buff 34)))
  )
  (begin
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (map-set allowances {
      owner: tx-sender,
      spender: spender,
    }
      amount
    )

    (match memo
      m (begin
        (print m)
        true
      )
      true
    )

    (ok true)
  )
)

(define-public (get-allowance
    (owner principal)
    (spender principal)
  )
  (ok (default-to u0
    (map-get? allowances {
      owner: owner,
      spender: spender,
    })
  ))
)

;; ===== Admin Functions =====
(define-public (mint
    (amount uint)
    (recipient principal)
  )
  (begin
    ;; REMOVED AUTH CHECK FOR TEST MOCK
    ;; (asserts!
    ;;   (or (is-eq tx-sender (var-get admin)) (is-eq tx-sender (as-contract tx-sender)))
    ;;   ERR_UNAUTHORIZED
    ;; )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let (
        (current-supply (var-get total-supply))
        (recipient-balance (default-to u0 (map-get? balances recipient)))
      )
      (var-set total-supply (+ current-supply amount))
      (map-set balances recipient (+ recipient-balance amount))
      (ok true)
    )
  )
)

(define-public (burn (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let (
        (balance (default-to u0 (map-get? balances tx-sender)))
        (current-supply (var-get total-supply))
      )
      (asserts! (>= balance amount) ERR_INSUFFICIENT_BALANCE)

      (var-set total-supply (- current-supply amount))
      (map-set balances tx-sender (- balance amount))
      (ok true)
    )
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

;; ===== Initialize =====
(define-public (initialize (initial-account principal))
  (begin
    (asserts! (is-eq tx-sender (as-contract tx-sender)) ERR_UNAUTHORIZED)
    (var-set admin initial-account)
    (ok true)
  )
)
