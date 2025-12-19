;; operational-treasury.clar
;; Central Operational Treasury for Conxian Protocol
;; Manages OpEx funds (Keepers, Oracles, Gas Stipends)
;; Tracks burn rate and runway

(use-trait sip-010-trait .defi-traits.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INSUFFICIENT_FUNDS (err u1001))
(define-constant ERR_LIMIT_EXCEEDED (err u1002))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var economic-policy-engine principal tx-sender)

;; Track expenses
(define-data-var total-stx-spent uint u0)
(define-data-var total-tokens-spent uint u0)
(define-data-var last-spend-block uint u0)
(define-data-var rolling-burn-rate uint u0) ;; Avg spend per 100 blocks

;; Allowances for Keepers/Oracles
(define-map authorized-spenders
  principal
  uint
)
;; spender -> daily limit

;; --- Authorization ---
(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (is-authorized)
  (or (is-owner) (is-eq tx-sender (var-get economic-policy-engine)))
)

;; --- Admin ---
(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-policy-engine (engine principal))
  (begin
    (asserts! (is-owner) ERR_UNAUTHORIZED)
    (var-set economic-policy-engine engine)
    (ok true)
  )
)

(define-public (set-spender-limit
    (spender principal)
    (limit uint)
  )
  (begin
    (asserts! (is-authorized) ERR_UNAUTHORIZED)
    (map-set authorized-spenders spender limit)
    (ok true)
  )
)

;; --- Operational Functions ---

;; @desc Fund the treasury
(define-public (deposit-stx (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

;; @desc Withdraw funds for operations (Keepers/Oracles)
(define-public (withdraw-stx (amount uint))
  (let ((limit (default-to u0 (map-get? authorized-spenders tx-sender))))
    (asserts! (> limit u0) ERR_UNAUTHORIZED)
    (asserts! (<= amount limit) ERR_LIMIT_EXCEEDED)

    ;; Update burn tracking (Simplified moving average)
    (let (
        (current-burn (var-get rolling-burn-rate))
        (blocks-diff (- block-height (var-get last-spend-block)))
      )
      (if (> blocks-diff u0)
        (var-set rolling-burn-rate (/ (+ current-burn amount) u2)) ;; Simple smoothing
        true
      )
    )

    (var-set last-spend-block block-height)
    (var-set total-stx-spent (+ (var-get total-stx-spent) amount))

    (as-contract (stx-transfer? amount tx-sender tx-sender))
  )
)

;; --- Read Only ---

(define-read-only (get-burn-rate)
  (ok (var-get rolling-burn-rate))
)

(define-read-only (get-runway)
  (let (
      (balance (stx-get-balance (as-contract tx-sender)))
      (burn (var-get rolling-burn-rate))
    )
    (if (> burn u0)
      (ok (/ balance burn))
      (ok u999999) ;; Infinite runway
    )
  )
)
