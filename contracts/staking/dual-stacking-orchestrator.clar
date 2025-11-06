(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait dual-stacking-trait .all-traits.dual-stacking-trait)

(impl-trait .all-traits.dual-stacking-trait)

(define-constant ERR_UNAUTHORIZED (err u9100))
(define-constant ERR_INVALID_TOKEN (err u9101))
(define-constant ERR_NOT_INITIALIZED (err u9102))
(define-constant ERR_NO_DELEGATIONS (err u9103))

(define-data-var owner principal tx-sender)
(define-data-var operator principal tx-sender)
(define-data-var fee-bps uint u0)
(define-data-var fee-recipient principal tx-sender)
(define-data-var sbtc principal tx-sender)

(define-map cycle-totals {cycle-id: uint} { total-delegated: uint, reward: uint })
(define-map user-delegations {cycle-id: uint, user: principal} uint)
(define-map claimable {user: principal} uint)

(define-public (initialize (sbtc-token principal) (new-operator principal) (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set sbtc sbtc-token)
    (var-set operator new-operator)
    (var-set fee-bps new-fee-bps)
    (var-set fee-recipient new-operator)
    (ok true)
  )
)

(define-public (record-delegations (cycle-id uint) (entries (list 200 (tuple (user principal) (amount uint)))))
  (begin
    (asserts! (is-eq tx-sender (var-get operator)) ERR_UNAUTHORIZED)
    ;; Simplified stub: accept entries, no iteration (compile-safe)
    (let ((totals (default-to { total-delegated: u0, reward: u0 } (map-get? cycle-totals {cycle-id: cycle-id}))))
      (map-set cycle-totals {cycle-id: cycle-id} { total-delegated: (get total-delegated totals), reward: (get reward totals) })
      (ok true)))
)

(define-public (deposit-reward (cycle-id uint) (token <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get operator)) ERR_UNAUTHORIZED)
    (asserts! (is-eq token (var-get sbtc)) ERR_INVALID_TOKEN)
    (let (
      (totals (default-to { total-delegated: u0, reward: u0 } (map-get? cycle-totals {cycle-id: cycle-id})))
      (total (get total-delegated totals))
    )
      (asserts! (> total u0) ERR_NO_DELEGATIONS)
      ;; Simplified allocation: update reward only
      (map-set cycle-totals {cycle-id: cycle-id} { total-delegated: total, reward: (+ (get reward totals) amount) })
      (ok true)
    )
  )
)

(define-public (claim (token <sip-010-ft-trait>))
  (let (
    (recipient tx-sender)
    (amount (default-to u0 (map-get? claimable {user: tx-sender})))
  )
    (if (is-eq amount u0)
      (ok u0)
      (begin
        (asserts! (is-eq token (var-get sbtc)) ERR_INVALID_TOKEN)
        (map-set claimable {user: recipient} u0)
        (match (as-contract (contract-call? token transfer amount tx-sender recipient none))
          result (ok amount)
          error (begin
            (map-set claimable {user: recipient} amount)
            error
          )
        )
      )
    )
  )
)

(define-read-only (get-user-claimable (user principal))
  (ok (default-to u0 (map-get? claimable {user: user})))
)

(define-read-only (get-cycle-stats (cycle-id uint))
  (let ((totals (default-to { total-delegated: u0, reward: u0 } (map-get? cycle-totals {cycle-id: cycle-id}))))
    (ok { total-delegated: (get total-delegated totals), reward: (get reward totals) })
  )
)

(define-public (set-operator (new-operator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set operator new-operator)
    (ok true)
  )
)

(define-public (set-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set fee-bps new-fee-bps)
    (ok true)
  )
)

(define-public (set-fee-recipient (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_UNAUTHORIZED)
    (var-set fee-recipient recipient)
    (ok true)
  )
)
