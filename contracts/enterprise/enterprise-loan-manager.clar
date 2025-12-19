;; enterprise-loan-manager.clar

(define-constant ERR_UNAUTHORIZED u7001)
(define-constant ERR_INSUFFICIENT_COLLATERAL u7003)

(define-data-var contract-owner principal tx-sender)
(define-data-var liquidity-available uint u0)
(define-data-var total-loan-volume uint u0)
(define-data-var total-active-loans uint u0)
(define-data-var next-loan-id uint u1)
(define-data-var next-bond-id uint u1)
(define-data-var emergency-reserve uint u0)

(define-map credit-scores
  principal
  uint
)
(define-map loans
  uint
  {
    borrower: principal,
    principal-amount: uint,
    status: (string-ascii 16),
    total-interest-paid: uint,
  }
)

(define-private (is-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (add-liquidity (amount uint))
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (var-set liquidity-available (+ (var-get liquidity-available) amount))
    (ok true)
  )
)

(define-read-only (get-system-stats)
  (ok {
    total-active-loans: (var-get total-active-loans),
    total-loan-volume: (var-get total-loan-volume),
    liquidity-available: (var-get liquidity-available),
    emergency-reserve: (var-get emergency-reserve),
    next-loan-id: (var-get next-loan-id),
    next-bond-id: (var-get next-bond-id),
  })
)

(define-read-only (calculate-loan-terms
    (borrower principal)
    (requested uint)
  )
  (ok {
    eligible: true,
    interest-rate: u500,
    max-amount: u10000000000000000000000000,
    bond-eligible: (>= requested u100000000000000000000000),
  })
)

(define-public (update-credit-score
    (borrower principal)
    (score uint)
  )
  (begin
    (asserts! (is-owner) (err ERR_UNAUTHORIZED))
    (map-set credit-scores borrower score)
    (ok score)
  )
)

(define-public (create-enterprise-loan
    (amount uint)
    (collateral uint)
    (collateral-asset principal)
    (loan-asset principal)
    (duration uint)
  )
  (begin
    (asserts! (>= collateral (/ (* amount u12000) u10000))
      (err ERR_INSUFFICIENT_COLLATERAL)
    )
    (asserts! (>= (var-get liquidity-available) amount) (err ERR_UNAUTHORIZED))
    (let ((loan-id (var-get next-loan-id)))
      (var-set next-loan-id (+ loan-id u1))
      (var-set total-active-loans (+ (var-get total-active-loans) u1))
      (var-set total-loan-volume (+ (var-get total-loan-volume) amount))
      (var-set liquidity-available (- (var-get liquidity-available) amount))
      (map-set loans loan-id {
        borrower: tx-sender,
        principal-amount: amount,
        status: "active",
        total-interest-paid: u0,
      })
      (ok loan-id)
    )
  )
)

(define-public (make-loan-payment
    (loan-id uint)
    (payment uint)
  )
  (begin
    (match (map-get? loans loan-id)
      loan (begin
        (map-set loans loan-id
          (merge loan { total-interest-paid: (+ (get total-interest-paid loan) payment) })
        )
        (ok true)
      )
      (err u0)
    )
  )
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans loan-id)
)
