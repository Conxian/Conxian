;; rewards-distributor.clar
;; Distributes rewards to users based on their holdings or activities

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait circuit-breaker-trait .all-traits.circuit-breaker-trait)

;; =============================================================================
;; CONSTANTS AND ERROR CODES
;; =============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u4000))
(define-constant ERR_INVALID_AMOUNT (err u4001))
(define-constant ERR_CIRCUIT_OPEN (err u5000))

;; =============================================================================
;; DATA STRUCTURES
;; =============================================================================

(define-data-var reward-token principal .age000-governance-token)
(define-data-var circuit-breaker principal .circuit-breaker)

(define-map rewards-balance { user: principal } { balance: uint })
(define-map total-rewards-claimed { user: principal } { amount: uint })

;; =============================================================================
;; PRIVATE FUNCTIONS
;; =============================================================================

(define-private (check-circuit-breaker)
  (contract-call? .circuit-breaker is-circuit-open)
)

;; =============================================================================
;; PUBLIC FUNCTIONS
;; =============================================================================

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

(define-public (deposit-rewards (amount uint) (recipient principal))
  "Deposits rewards to be distributed to a specific user"
  (begin
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let ((current-balance (get balance (map-get? rewards-balance { user: recipient }))))
      (map-set rewards-balance { user: recipient } { balance: (+ current-balance amount) })
      (print { event: "rewards-deposited", amount: amount, recipient: recipient })
      (ok true)
    )
  )
)

(define-public (claim-rewards)
  "Claims available rewards for the calling user"
  (let ((user tx-sender))
    (asserts! (not (try! (check-circuit-breaker))) ERR_CIRCUIT_OPEN)
    (match (map-get? rewards-balance { user: user })
      reward-info
      (let ((amount-to-claim (get balance reward-info)))
        (asserts! (> amount-to-claim u0) ERR_INVALID_AMOUNT)
        
        (map-set rewards-balance { user: user } { balance: u0 })
        
        (let ((total-claimed (get amount (map-get? total-rewards-claimed { user: user }))))
          (map-set total-rewards-claimed { user: user } { amount: (+ total-claimed amount-to-claim) })
        )

        (as-contract (try! (contract-call? (var-get reward-token) transfer amount-to-claim user (some 0x))))
        
        (print { event: "rewards-claimed", user: user, amount: amount-to-claim })
        (ok amount-to-claim)
      )
      (err ERR_INVALID_AMOUNT)
    )
  )
)

;; =============================================================================
;; READ-ONLY FUNCTIONS
;; =============================================================================

(define-read-only (get-rewards-balance (user principal))
  (default-to u0 (get balance (map-get? rewards-balance { user: user })))
)

(define-read-only (get-total-claimed (user principal))
  (default-to u0 (get amount (map-get? total-rewards-claimed { user: user })))
)