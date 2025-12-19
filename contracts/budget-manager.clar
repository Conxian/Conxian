;; budget-manager.clar
;; Manages treasury allocation and budget proposals for DAO governance

;; Constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_FUNDS (err u102))

;; Data Maps
(define-map budgets
  { budget-id: uint }
  {
    proposer: principal,
    amount: uint,
    token: principal,
    executed: bool,
  }
)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var next-budget-id uint u1)

;; Public Functions
(define-public (create-budget-proposal
    (amount uint)
    (token principal)
  )
  (begin
    (let ((budget-id (var-get next-budget-id)))
      (map-set budgets { budget-id: budget-id } {
        proposer: tx-sender,
        amount: amount,
        token: token,
        executed: false,
      })
      (var-set next-budget-id (+ budget-id u1))
      (print {
        event: "budget-proposal-created",
        budget-id: budget-id,
        proposer: tx-sender,
        amount: amount,
        token: token,
      })
      (ok budget-id)
    )
  )
)

(define-public (execute-budget-proposal (budget-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((budget (map-get? budgets { budget-id: budget-id })))
      (asserts! (is-some budget) ERR_PROPOSAL_NOT_FOUND)
      (asserts! (not (get executed (unwrap-panic budget))) ERR_PROPOSAL_NOT_FOUND)

      ;; Placeholder for actual fund transfer
      ;; This would involve transferring tokens from the treasury to the proposer
      (print {
        event: "budget-proposal-executed",
        budget-id: budget-id,
        amount: (get amount (unwrap-panic budget)),
        token: (get token (unwrap-panic budget)),
      })

      (map-set budgets { budget-id: budget-id }
        (merge (unwrap-panic budget) { executed: true })
      )
      (ok true)
    )
  )
)

;; Read-only Functions
(define-read-only (get-budget-proposal (budget-id uint))
  (ok (map-get? budgets { budget-id: budget-id }))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)
