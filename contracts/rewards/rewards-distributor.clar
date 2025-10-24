;; rewards-distributor.clar
;; Distributes rewards to users based on their holdings or activities

;; ===== Constants =====
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u4000))
(define-constant ERR_INVALID_AMOUNT (err u4001))
(define-constant ERR_CIRCUIT_OPEN (err u5000))
(define-constant ERR_NO_REWARDS (err u4002))

;; ===== Data Variables =====
(define-data-var reward-token principal tx-sender)
(define-data-var circuit-breaker principal tx-sender)

;; ===== Data Maps =====
(define-map rewards-balance {user: principal} {balance: uint})
(define-map total-rewards-claimed {user: principal} {amount: uint})

;; ===== Private Functions =====
(define-private (check-circuit-breaker)
  (contract-call? .circuit-breaker is-circuit-open)
)

;; ===== Owner Functions =====
(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

(define-public (set-reward-token (new-token principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set reward-token new-token)
    (ok true)
  )
)

;; ===== Public Functions =====
(define-public (deposit-rewards (amount uint) (recipient principal))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    
    (let (
      (current-balance (default-to u0 (get balance (map-get? rewards-balance {user: recipient}))))
    )
      (map-set rewards-balance {user: recipient} {balance: (+ current-balance amount)})
      (print {event: "rewards-deposited", amount: amount, recipient: recipient})
      (ok true)
    )
  )
)

(define-public (claim-rewards)
  (let (
    (user tx-sender)
  )
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    
    (match (map-get? rewards-balance {user: user})
      reward-info
      (let (
        (amount-to-claim (get balance reward-info))
      )
        (asserts! (> amount-to-claim u0) ERR_NO_REWARDS)
        
        ;; Reset rewards balance
        (map-set rewards-balance {user: user} {balance: u0})
        
        ;; Update total claimed
        (let (
          (total-claimed (default-to u0 (get amount (map-get? total-rewards-claimed {user: user}))))
        )
          (map-set total-rewards-claimed {user: user} {amount: (+ total-claimed amount-to-claim)})
        )
        
        ;; Transfer rewards
        (try! (as-contract (contract-call? .age000-governance-token transfer amount-to-claim tx-sender user none)))
        
        (print {event: "rewards-claimed", user: user, amount: amount-to-claim})
        (ok amount-to-claim)
      )
      ERR_NO_REWARDS
    )
  )
)

;; ===== Read-Only Functions =====
(define-read-only (get-rewards-balance (user principal))
  (default-to u0 (get balance (map-get? rewards-balance {user: user})))
)

(define-read-only (get-total-claimed (user principal))
  (default-to u0 (get amount (map-get? total-rewards-claimed {user: user})))
)