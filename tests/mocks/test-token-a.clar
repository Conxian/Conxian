;; Test Token A - Mock ERC20-like token for testing

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(impl-trait sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1001))
(define-constant ERR_NOT_ENOUGH_BALANCE (err u1002))
(define-constant ERR_OVERFLOW (err u1003))
;; --- Data Variables ---
(define-data-var symbol (string-ascii 10) "TTA")
(define-data-var decimals uint u6)
(define-data-var total-supply uint u0)
(define-data-var contract-owner principal tx-sender)

(define-map balances { who: principal } { balance: uint })

;; --- Public Functions ---
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err ERR_UNAUTHORIZED))
    
    (let (
      (sender-bal (default-to u0 (get balance (map-get? balances { who: sender }))))
      (recipient-bal (default-to u0 (get balance (map-get? balances { who: recipient }))))
    )
      (asserts! (>= sender-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      (map-set balances { who: sender } { balance: (- sender-bal amount) })
      (map-set balances { who: recipient } { balance: (+ recipient-bal amount) })
      
      (ok true)
    )
  )
)

(define-read-only (get-name)
  (ok (var-get name))
)

(define-read-only (get-symbol)
  (ok (var-get symbol))
)

(define-read-only (get-decimals)
  (ok (var-get decimals))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-balance (who principal))
  (ok (default-to u0 (get balance (map-get? balances { who: who }))))
)

;; --- Admin Functions ---
(define-public (mint (to principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_NOT_ENOUGH_BALANCE))
    
    (let ((current-bal (default-to u0 (get balance (map-get? balances { who: to })))))
      (map-set balances { who: to } { balance: (+ current-bal amount) })
      (var-set total-supply (+ (var-get total-supply) amount))
      (ok true)
    )
  )
)

(define-public (burn (from principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR_UNAUTHORIZED))
    (asserts! (> amount u0) (err ERR_NOT_ENOUGH_BALANCE))
    
    (let ((current-bal (default-to u0 (get balance (map-get? balances { who: from })))))
      (asserts! (>= current-bal amount) (err ERR_NOT_ENOUGH_BALANCE))
      
      (map-set balances { who: from } { balance: (- current-bal amount) })
      (var-set total-supply (- (var-get total-supply) amount))
      (ok true)
    )
  )
)

;; --- Initialization ---
(define-public (initialize (owner principal) (initial-supply uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR_UNAUTHORIZED))
    (map-set balances { who: owner } { balance: initial-supply })
    (var-set total-supply initial-supply)
    (ok true)
  )
)
