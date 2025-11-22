;; mock-strategy-a.clar
;; A simple mock strategy contract for testing the yield optimizer.

(use-trait sip-010-ft-trait .sip-010-ft-trait.sip-010-ft-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_AMOUNT (err u1001))
(define-constant ERR_TRANSFER_FAILED (err u1002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1003))

;; ===== Data Variables =====
(define-data-var total-deposited uint u0)

;; ===== Data Maps =====
(define-map asset-balances principal uint)

;; ===== Public Functions =====

(define-public (deposit (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer tokens from sender to contract
    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update internal balance tracking
    (let (
      (current-balance (default-to u0 (map-get? asset-balances (contract-of asset))))
    )
      (map-set asset-balances (contract-of asset) (+ current-balance amount))
      (var-set total-deposited (+ (var-get total-deposited) amount))
    )
    
    (print {
      event: "strategy-a-deposit",
      asset: (contract-of asset),
      amount: amount,
      block: block-height
    })
    
    (ok true)
  )
)

(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (default-to u0 (map-get? asset-balances (contract-of asset))))
    )
      (asserts! (>= current-balance amount) ERR_INSUFFICIENT_BALANCE)
      
      ;; Transfer tokens from contract to recipient
      (try! (as-contract 
        (contract-call? asset transfer amount tx-sender recipient none)
      ))
      
      ;; Update internal balance tracking
      (map-set asset-balances (contract-of asset) (- current-balance amount))
      (var-set total-deposited (- (var-get total-deposited) amount))
      
      (print {
        event: "strategy-a-withdraw",
        asset: (contract-of asset),
        amount: amount,
        recipient: recipient,
        block: block-height
      })
      
      (ok amount)
    )
  )
)

;; ===== Read-Only Functions =====

(define-read-only (get-balance (asset principal))
  (ok (default-to u0 (map-get? asset-balances asset)))
)

(define-read-only (get-total-deposited)
  (ok (var-get total-deposited))
)
