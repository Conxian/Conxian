;; Yield Optimizer
;; Automated strategy selection and allocation
;; Manages yield strategies and allocates funds to the highest yielding safe strategy.

(use-trait vault-trait .defi-traits.vault-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)
(use-trait strategy-trait .defi-traits.strategy-trait)

(define-constant ERR_UNAUTHORIZED (err u6000))
(define-constant ERR_INVALID_STRATEGY (err u6001))
(define-constant ERR_NO_STRATEGY (err u6002))
(define-constant ERR_LOW_YIELD (err u6003))
(define-constant ERR_CIRCUIT_OPEN (err u6004))
(define-constant ERR_SLIPPAGE (err u6005))

(define-data-var contract-owner principal tx-sender)
(define-data-var best-strategy principal tx-sender)
(define-data-var max-risk-score uint u50) ;; Max allowed risk (0-100)
(define-data-var circuit-breaker-principal (optional principal) none)

(define-map strategies
  { strategy: principal }
  {
    active: bool,
    apy: uint,
    risk-score: uint,
    total-allocated: uint,
  }
)

;; --- Private Helper ---
(define-private (check-circuit-breaker (cb <circuit-breaker-trait>))
  (let ((cb-principal (contract-of cb)))
    (asserts! (is-eq (some cb-principal) (var-get circuit-breaker-principal))
      ERR_UNAUTHORIZED
    )
    (match (contract-call? cb is-circuit-open)
      is-open (if is-open
        ERR_CIRCUIT_OPEN
        (ok true)
      )
      error (err error)
    )
  )
)

;; --- Public Functions ---

(define-public (set-circuit-breaker (cb principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker-principal (some cb))
    (ok true)
  )
)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (set-max-risk (risk uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set max-risk-score risk)
    (ok true)
  )
)

(define-public (add-strategy
    (strategy principal)
    (apy uint)
    (risk uint)
  )
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set strategies { strategy: strategy } {
      active: true,
      apy: apy,
      risk-score: risk,
      total-allocated: u0,
    })

    ;; Check if this is the new best strategy
    (unwrap-panic (check-and-update-best strategy apy risk))
    (ok true)
  )
)

(define-public (update-metrics
    (strategy principal)
    (apy uint)
    (risk uint)
  )
  (let ((current (unwrap! (map-get? strategies { strategy: strategy }) ERR_INVALID_STRATEGY)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    ;; Only owner/keeper can update metrics
    (map-set strategies { strategy: strategy }
      (merge current {
        apy: apy,
        risk-score: risk,
      })
    )

    (unwrap-panic (check-and-update-best strategy apy risk))
    (ok true)
  )
)

(define-public (refresh-strategy (strategy <strategy-trait>))
  (let (
      (strategy-principal (contract-of strategy))
      (apy (unwrap! (contract-call? strategy get-apy) ERR_INVALID_STRATEGY))
      (risk (unwrap! (contract-call? strategy get-risk-score) ERR_INVALID_STRATEGY))
    )
    ;; Update metrics internally (this will also update best-strategy if needed)
    (try! (update-metrics strategy-principal apy risk))
    (ok true)
  )
)

(define-public (optimize-allocation
    (vault <vault-trait>)
    (amount uint)
    (cb <circuit-breaker-trait>)
  )
  (let (
      (target-strategy (var-get best-strategy))
      (current-alloc (unwrap! (map-get? strategies { strategy: target-strategy })
        ERR_NO_STRATEGY
      ))
    )
    (try! (check-circuit-breaker cb))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (get active current-alloc) ERR_INVALID_STRATEGY)

    ;; Allocate funds to the best strategy via the vault
    ;; The vault must support `allocate-to-strategy`
    (try! (contract-call? vault allocate-to-strategy target-strategy amount))

    ;; Update tracking
    (map-set strategies { strategy: target-strategy }
      (merge current-alloc { total-allocated: (+ (get total-allocated current-alloc) amount) })
    )

    (ok true)
  )
)

;; --- Private Functions ---

(define-private (check-and-update-best
    (candidate principal)
    (apy uint)
    (risk uint)
  )
  (let (
      (current-best (var-get best-strategy))
      (current-stats (default-to {
        active: false,
        apy: u0,
        risk-score: u0,
        total-allocated: u0,
      }
        (map-get? strategies { strategy: current-best })
      ))
    )
    ;; If candidate has better APY and acceptable risk, update best
    (if (and
        (<= risk (var-get max-risk-score))
        (> apy (get apy current-stats))
      )
      (begin
        (var-set best-strategy candidate)
        (ok true)
      )
      (ok false)
    )
  )
)

;; --- Read-Only ---

(define-read-only (get-strategy (strategy principal))
  (map-get? strategies { strategy: strategy })
)

(define-read-only (get-best-strategy)
  (ok (var-get best-strategy))
)
