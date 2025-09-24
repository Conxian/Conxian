;; vault.clar
;; This contract serves as a secure ledger for managing user deposits and shares.
;; It is controlled by the yield-optimizer contract.

;; --- Traits ---
(use-trait sip-010-ft-trait .sip-010-trait)
(use-trait vault-trait .vault-trait)
(use-trait vault-admin-trait .vault-admin-trait)
(use-trait strategy-trait .strategy-trait)

(impl-trait .vault-trait)
(impl-trait .vault-admin-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u6001))
(define-constant ERR_PAUSED (err u6002))
(define-constant ERR_INSUFFICIENT_BALANCE (err u6003))
(define-constant ERR_INVALID_AMOUNT (err u6004))
(define-constant ERR_CAP_EXCEEDED (err u6005))
(define-constant ERR_INVALID_ASSET (err u6006))
(define-constant ERR_OPTIMIZER_ONLY (err u6013))

;; --- Data Variables ---
(define-data-var admin principal tx-sender)
(define-data-var paused bool false)
(define-data-var yield-optimizer-contract principal tx-sender)

;; --- Maps ---
(define-map total-balances principal uint)
(define-map vault-shares principal uint)
(define-map user-shares (tuple (user principal) (asset principal)) uint)
(define-map supported-assets principal bool)
(define-map asset-caps principal uint)

;; === ADMIN FUNCTIONS ===
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-paused (pause bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set paused pause)
    (ok true)))

(define-public (set-yield-optimizer (optimizer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set yield-optimizer-contract optimizer)
    (ok true)))

(define-public (add-supported-asset (asset principal) (cap uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (map-set supported-assets asset true)
    (map-set asset-caps asset cap)
    (ok true)))

;; === CORE VAULT FUNCTIONS ===
(define-public (deposit (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (default-to false (map-get? supported-assets (contract-of asset))) ERR_INVALID_ASSET)

    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))

    (let ((total-balance (default-to u0 (map-get? total-balances (contract-of asset))))
          (total-shares (default-to u0 (map-get? vault-shares (contract-of asset))))
          (new-shares (calculate-shares-for-amount total-balance total-shares amount)))

      (map-set total-balances (contract-of asset) (+ total-balance amount))
      (map-set vault-shares (contract-of asset) (+ total-shares new-shares))
      (map-set user-shares (tuple (user tx-sender) (asset (contract-of asset))) (+ (default-to u0 (map-get? user-shares (tuple (user tx-sender) (asset (contract-of asset))))) new-shares))

      (print { event: "deposit", user: tx-sender, asset: (contract-of asset), amount: amount, shares: new-shares })
      (ok new-shares))))

(define-public (withdraw (asset <sip-010-ft-trait>) (shares uint))
  (begin
    (asserts! (not (var-get paused)) ERR_PAUSED)
    (asserts! (> shares u0) ERR_INVALID_AMOUNT)
    (let ((user-current-shares (default-to u0 (map-get? user-shares (tuple (user tx-sender) (asset (contract-of asset)))))))
      (asserts! (>= user-current-shares shares) ERR_INSUFFICIENT_BALANCE)

      (let ((total-balance (default-to u0 (map-get? total-balances (contract-of asset))))
            (total-shares (default-to u0 (map-get? vault-shares (contract-of asset))))
            (amount-to-withdraw (calculate-amount-for-shares total-balance total-shares shares)))

        (asserts! (>= (unwrap-panic (contract-call? asset get-balance (as-contract tx-sender))) amount-to-withdraw) ERR_INSUFFICIENT_BALANCE)

        (try! (as-contract (contract-call? asset transfer amount-to-withdraw (as-contract tx-sender) tx-sender none)))

        (map-set total-balances (contract-of asset) (- total-balance amount-to-withdraw))
        (map-set vault-shares (contract-of asset) (- total-shares shares))
        (map-set user-shares (tuple (user tx-sender) (asset (contract-of asset))) (- user-current-shares shares))

        (print { event: "withdraw", user: tx-sender, asset: (contract-of asset), amount: amount-to-withdraw, shares: shares })
        (ok amount-to-withdraw)))))

;; === OPTIMIZER-ONLY FUNCTIONS ===
(define-public (deposit-to-strategy (asset <sip-010-ft-trait>) (amount uint) (strategy <strategy-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get yield-optimizer-contract)) ERR_OPTIMIZER_ONLY)
    (try! (as-contract (contract-call? asset transfer amount (as-contract tx-sender) (contract-of strategy) none)))
    (try! (contract-call? strategy deposit (contract-of asset) amount))
    (ok true)))

(define-public (withdraw-from-strategy (asset <sip-010-ft-trait>) (amount uint) (strategy <strategy-trait>))
  (begin
    (asserts! (is-eq tx-sender (var-get yield-optimizer-contract)) ERR_OPTIMIZER_ONLY)
    (try! (contract-call? strategy withdraw (contract-of asset) amount))
    (ok true)))

;; === UTILITY AND ACCOUNTING FUNCTIONS ===
(define-private (calculate-shares-for-amount (total-balance uint) (total-shares uint) (amount uint))
  (if (is-eq total-shares u0)
    amount
    (/ (* amount total-shares) total-balance)))

(define-private (calculate-amount-for-shares (total-balance uint) (total-shares uint) (shares uint))
  (if (is-eq total-shares u0)
    u0
    (/ (* shares total-balance) total-shares)))

;; === READ-ONLY FUNCTIONS ===
(define-read-only (get-total-balance (asset principal))
  (ok (default-to u0 (map-get? total-balances asset))))
