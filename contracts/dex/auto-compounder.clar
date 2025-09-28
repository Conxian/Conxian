; auto-compounder.clar
;; This contract automatically compounds rewards for users.

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait yield-optimizer-trait .all-traits.yield-optimizer-trait)
(use-trait strategy-trait .all-traits.strategy-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u8000))
(define-constant ERR_NOTHING_TO_COMPOUND (err u8001))
(define-constant ERR_STRATEGY_ALREADY_EXISTS (err u8002))
(define-constant ERR_STRATEGY_NOT_FOUND (err u8003))
(define-constant ERR_CIRCUIT_OPEN (err u8004))

(define-data-var contract-owner principal tx-sender)
(define-data-var yield-optimizer-contract principal .yield-optimizer)
(define-data-var compounding-fee-bps uint u10) ;; 0.1% fee
(define-data-var circuit-breaker (optional principal) none)

(define-map user-positions { user: principal, token: principal } { amount: uint, last-compounded: uint })
(define-map strategies (principal) principal)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    cb
    (asserts! (not (unwrap-panic (contract-call? cb is-circuit-open))) ERR_CIRCUIT_OPEN)
    (ok true)
  )
)

(define-public (add-strategy (token principal) (strategy principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? strategies token)) ERR_STRATEGY_ALREADY_EXISTS)
    (map-set strategies token strategy)
    (ok true)
  )
)

(define-public (remove-strategy (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? strategies token)) ERR_STRATEGY_NOT_FOUND)
    (map-delete strategies token)
    (ok true)
  )
)

(define-public (set-circuit-breaker (cb principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

(define-public (deposit (token principal) (amount uint))
  (begin
    (try! (check-circuit-breaker))
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender)))
    (let ((position (unwrap! (map-get? user-positions { user: tx-sender, token: token }) { amount: u0, last-compounded: block-height })))
      (map-set user-positions { user: tx-sender, token: token } (merge position { amount: (+ (get amount position) amount) }))
      (ok true)
    )
  )
)

(define-public (withdraw (token principal) (amount uint))
  (let ((position (unwrap! (map-get? user-positions { user: tx-sender, token: token }) (err ERR_NOTHING_TO_COMPOUND))))
    (asserts! (>= (get amount position) amount) (err ERR_NOTHING_TO_COMPOUND))
    (try! (as-contract (contract-call? token transfer amount tx-sender)))
    (map-set user-positions { user: tx-sender, token: token } (merge position { amount: (- (get amount position) amount) }))
    (ok true)
  )
)

(define-public (compound (user principal) (token principal))
  (begin
    (try! (check-circuit-breaker))
    (let ((strategy (unwrap! (map-get? strategies token) (err ERR_STRATEGY_NOT_FOUND))))
      (let ((position (unwrap! (map-get? user-positions { user: user, token: token }) (err ERR_NOTHING_TO_COMPOUND))))
        (let ((rewards (try! (contract-call? strategy harvest-rewards))))
          (asserts! (> rewards u0) ERR_NOTHING_TO_COMPOUND)
          (let ((fee (* rewards (var-get compounding-fee-bps) u10000)))
            (try! (as-contract (contract-call? token transfer fee tx-sender)))
            (let ((net-rewards (- rewards fee)))
              (let ((new-amount (+ (get amount position) net-rewards)))
                (map-set user-positions { user: user, token: token } { amount: new-amount, last-compounded: block-height })
                (ok new-amount)
              )
            )
          )
        )
      )
    )
  )
)

(define-public (compound-all (users (list 100 principal)) (token principal))
    (let ((strategy (unwrap! (map-get? strategies token) (err ERR_STRATEGY_NOT_FOUND))))
        (let ((total-rewards (try! (contract-call? strategy harvest-rewards))))
            (asserts! (> total-rewards u0) ERR_NOTHING_TO_COMPOUND)
            (let ((fee (* total-rewards (var-get compounding-fee-bps) u10000)))
                (try! (as-contract (contract-call? token transfer fee tx-sender)))
                (let ((net-rewards (- total-rewards fee)))
                    (fold (lambda (user-principal (current-net-rewards uint))
                        (let ((position (unwrap! (map-get? user-positions { user: user-principal, token: token }) (err ERR_NOTHING_TO_COMPOUND))))
                            (let ((user-share (/ (* (get amount position) net-rewards) (get-total-deployed)))
                                (new-amount (+ (get amount position) user-share)))
                                (map-set user-positions { user: user-principal, token: token } { amount: new-amount, last-compounded: block-height })
                                (- current-net-rewards user-share)
                            )
                        )
                    ) users net-rewards)
                    (ok true)
                )
            )
        )
    )
)

(define-read-only (get-position (user principal) (token principal))
  (map-get? user-positions { user: user, token: token })
)

(define-private (get-total-deployed))
    (let ((total-deployed u0))
        ;; This is a placeholder. In a real implementation, you would iterate over all users and sum their positions.
        ;; Iterating over a map is not directly possible in Clarity, so you would need to maintain a separate list of users.
        total-deployed
    )
)
