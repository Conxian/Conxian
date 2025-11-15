;; Test Token A - Mock ERC20-like token for testing
(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)
(impl-trait .sip-010-ft-trait.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NOT_ENOUGH_BALANCE (err u1002))
(define-constant ERR_OVERFLOW (err u1003))
(define-constant ERR_INVALID_AMOUNT (err u1004))

;; --- Data Variables ---
(define-data-var token-name (string-ascii 32) "Test Token A")
(define-data-var token-symbol (string-ascii 10) "TTA")
(define-data-var token-decimals uint u6)
(define-data-var token-total-supply uint u0)
(define-data-var contract-owner principal tx-sender)

;; --- Data Maps ---
(define-map balances principal uint)

;; --- Private Helper Functions ---
(define-private (get-balance-or-default (account principal))
  (default-to u0 (map-get? balances account))
)

(define-private (set-balance (account principal) (amount uint))
  (map-set balances account amount)
)

;; --- SIP-010 Standard Functions ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (sender-balance (get-balance-or-default sender))
      (recipient-balance (get-balance-or-default recipient))
    )
      (asserts! (>= sender-balance amount) ERR_NOT_ENOUGH_BALANCE)
      
      (set-balance sender (- sender-balance amount))
      (set-balance recipient (+ recipient-balance amount))
      
      (print {
        action: "transfer",
        sender: sender,
        recipient: recipient,
        amount: amount,
        memo: memo
      })
      
      (ok true)
    )
  )
)

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
  (ok (var-get token-total-supply))
)

(define-read-only (get-balance (account principal))
  (ok (get-balance-or-default account))
)

;; --- Admin Functions ---
(define-public (mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (get-balance-or-default recipient))
      (new-balance (+ current-balance amount))
      (new-supply (+ (var-get token-total-supply) amount))
    )
      (set-balance recipient new-balance)
      (var-set token-total-supply new-supply)
      
      (print {
        action: "mint",
        recipient: recipient,
        amount: amount,
        new-supply: new-supply
      })
      
      (ok true)
    )
  )
)

(define-public (burn (account principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (get-balance-or-default account))
      (new-balance (- current-balance amount))
      (new-supply (- (var-get token-total-supply) amount))
    )
      (asserts! (>= current-balance amount) ERR_NOT_ENOUGH_BALANCE)
      
      (set-balance account new-balance)
      (var-set token-total-supply new-supply)
      
      (print {
        action: "burn",
        account: account,
        amount: amount,
        new-supply: new-supply
      })
      
      (ok true)
    )
  )
)

;; --- Initialization ---
(define-public (initialize (owner principal) (initial-supply uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get token-total-supply) u0) ERR_UNAUTHORIZED)
    
    (set-balance owner initial-supply)
    (var-set token-total-supply initial-supply)
    
    (print {
      action: "initialize",
      owner: owner,
      initial-supply: initial-supply
    })
    
    (ok true)
  )
)
