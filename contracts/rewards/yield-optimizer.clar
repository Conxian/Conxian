;; yield-optimizer.clar
;; The central brain of the Conxian yield system.
;; This contract dynamically analyzes and allocates funds across various yield-generating
;; strategies to maximize returns for the protocol.

;; --- Traits ---
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait vault-trait .all-traits.vault-trait)
(use-trait strategy-trait .all-traits.strategy-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u8001))
(define-constant ERR_STRATEGY_ALREADY_EXISTS (err u8002))
(define-constant ERR_STRATEGY_NOT_FOUND (err u8003))
(define-constant ERR_REBALANCE_FAILED (err u8006))
(define-constant ERR_INVALID_CONTRACT (err u8007))
(define-constant ERR_METRICS_CALL_FAILED (err u8008))

;; --- Data Variables ---
(define-data-var admin principal tx-sender)
(define-data-var vault-contract principal tx-sender)
(define-data-var metrics-contract principal tx-sender)
(define-data-var strategy-count uint u0)

;; --- Maps ---
(define-map strategies uint {
  contract: principal,
  is-active: bool
})

(define-map asset-allocation principal {
  strategy: principal,
  amount: uint
})

;; === ADMIN FUNCTIONS ===
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)))

(define-public (set-contracts (vault principal) (metrics principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-some (contract-of? vault)) ERR_INVALID_CONTRACT)
    (asserts! (is-some (contract-of? metrics)) ERR_INVALID_CONTRACT)
    (var-set vault-contract vault)
    (var-set metrics-contract metrics)
    (ok true)))

(define-public (add-strategy (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((id (var-get strategy-count)))
      (map-set strategies id {
        contract: contract,
        is-active: true
      })
      (var-set strategy-count (+ id u1))
      (ok id))))

(define-public (toggle-strategy-status (id uint) (is-active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (let ((strategy-data (unwrap! (map-get? strategies id) (err ERR_STRATEGY_NOT_FOUND))))
      (map-set strategies id (merge strategy-data { is-active: is-active }))
      (ok true))))

;; === CORE OPTIMIZER LOGIC ===
(define-public (optimize-and-rebalance (asset <sip-010-ft-trait>))
  (let ((current-allocation (default-to { strategy: (as-contract tx-sender), amount: u0 } (map-get? asset-allocation (contract-of asset))))
        (current-strategy (get strategy current-allocation))
        (best-strategy-info (find-best-strategy)))

    (if (not (is-eq current-strategy (get contract best-strategy-info)))
      (begin
        (let ((vault (var-get vault-contract))
              (total-balance (try! (contract-call? vault get-total-balance (contract-of asset)))))

          ;; Withdraw from old strategy
          (if (not (is-eq current-strategy (as-contract tx-sender)))
            (try! (contract-call? vault withdraw-from-strategy (contract-of asset) (get amount current-allocation) current-strategy))
            (print "No current strategy to withdraw from.")
          )

          ;; Deposit to new best strategy
          (try! (contract-call? vault deposit-to-strategy (contract-of asset) total-balance (get contract best-strategy-info)))

          ;; Update allocation map
          (map-set asset-allocation (contract-of asset) {
            strategy: (get contract best-strategy-info),
            amount: total-balance
          })

          (print { event: "rebalanced", from: current-strategy, to: (get contract best-strategy-info), amount: total-balance })
          (ok true)
        )
      )
      (ok false) ;; No rebalance needed
    )
  )
)

;; === PRIVATE HELPERS ===
(define-private (find-best-strategy)
  (let ((metrics (var-get metrics-contract))
        (count (var-get strategy-count)))
    (fold
      (lambda (id memo)
        (match (map-get? strategies id)
          strategy-data
          (if (get is-active strategy-data)
            (let ((apy (unwrap! (contract-call? metrics get-apy (get contract strategy-data)) ERR_METRICS_CALL_FAILED)))
              (if (> apy (get apy memo))
                { contract: (get contract strategy-data), apy: apy }
                memo
              )
            )
            memo
          )
          memo
        )
      )
      (range u0 count)
      { contract: (as-contract tx-sender), apy: u0 }
    )
  )
)
