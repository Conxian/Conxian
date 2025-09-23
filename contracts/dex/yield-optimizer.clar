;; Conxian Yield Optimizer - Automated yield strategies
(use-trait sip-010-ft-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.sip-010-ft-trait)
(use-trait strategy-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.strategy-trait)
(use-trait circuit-breaker-trait 'ST3PPMPR7SAY4CAKQ4ZMYC2Q9FAVBE813YWNJ4JE6.all-traits.circuit-breaker-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u601))
(define-constant ERR_STRATEGY_NOT_FOUND (err u602))
(define-constant ERR_INVALID_STRATEGY (err u603))
(define-constant ERR_CIRCUIT_OPEN (err u604))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var strategy-counter uint u0)
(define-data-var circuit-breaker (optional principal) none)

;; --- Maps ---
;; Maps a strategy ID to its details
(define-map strategies uint {
  name: (string-ascii 64),
  contract: principal,
  risk-level: uint,
  yield-target: uint,
  created-at: uint
})

;; Maps a user and strategy ID to their deposit information
(define-map user-deposits { user: principal, strategy-id: uint } { amount: uint, deposited-at: uint })

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (cb (contract-call? cb is-tripped))
    (ok false)
  )
)

(define-public (register-strategy (name (string-ascii 64)) (contract principal) (risk-level uint) (yield-target uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (let ((strategy-id (+ u1 (var-get strategy-counter))))
            (map-set strategies strategy-id {
                name: name,
                contract: contract,
                risk-level: risk-level,
                yield-target: yield-target,
                created-at: block-height
            })
            (var-set strategy-counter strategy-id)
            (ok strategy-id)
        )
    )
)

(define-public (deposit (strategy-id uint) (token principal) (amount uint))
    (begin
        (try! (check-circuit-breaker))
        (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
            (try! (contract-call? token transfer amount tx-sender (get contract strategy)))
            (let ((deposit (default-to { amount: u0, deposited-at: block-height } (map-get? user-deposits { user: tx-sender, strategy-id: strategy-id }))))
                (map-set user-deposits { user: tx-sender, strategy-id: strategy-id } {
                    amount: (+ (get amount deposit) amount),
                    deposited-at: block-height
                })
                (ok true)
            )
        )
    )
)

(define-public (withdraw (strategy-id uint) (token principal) (amount uint))
    (begin
        (try! (check-circuit-breaker))
        (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
            (let ((deposit (unwrap! (map-get? user-deposits { user: tx-sender, strategy-id: strategy-id }) (err u0))))
                (asserts! (>= (get amount deposit) amount) (err u0))
                (try! (as-contract (contract-call? (get contract strategy) withdraw token amount tx-sender)))
                (map-set user-deposits { user: tx-sender, strategy-id: strategy-id } {
                    amount: (- (get amount deposit) amount),
                    deposited-at: block-height
                })
                (ok true)
            )
        )
    )
)

(define-public (rebalance (strategy-id uint))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (let ((strategy (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
            (try! (as-contract (contract-call? (get contract strategy) rebalance)))
            (ok true)
        )
    )
)

;; --- Admin Functions ---
(define-public (set-circuit-breaker (cb principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; --- Read-Only Functions ---
(define-read-only (get-strategy-details (strategy-id uint))
  (map-get? strategies strategy-id)
)

(define-read-only (get-user-deposit (user principal) (strategy-id uint))
    (map-get? user-deposits { user: user, strategy-id: strategy-id })
)

(define-read-only (get-strategy-count)
    (ok (var-get strategy-counter))
)