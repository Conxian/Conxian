;; comprehensive-lending-system.clar
;; Core lending protocol contract

;; Traits
(use-trait sip-010-ft-trait .defi-traits.sip-010-ft-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_ASSET (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1003))
(define-constant ERR_ZERO_AMOUNT (err u1004))
(define-constant ERR_HEALTH_CHECK_FAILED (err u1005))
(define-constant ERR_CIRCUIT_BREAKER_OPEN (err u1006))
(define-constant LENDING_SERVICE "lending-core")

;; Data Variables
(define-data-var contract-owner principal tx-sender)

;; Maps
(define-map user-supplies
  {
    user: principal,
    asset: principal,
  }
  { amount: uint }
)
(define-map user-borrows
  {
    user: principal,
    asset: principal,
  }
  { amount: uint }
)

;; Circuit Breaker
(define-private (check-circuit-breaker)
  (match (contract-call? .circuit-breaker check-circuit-state LENDING_SERVICE)
    success (ok true)
    error
    ERR_CIRCUIT_BREAKER_OPEN
  )
)

;; Public Functions

(define-public (supply
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let ((asset-principal (contract-of asset)))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))
    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
    (let ((current-supply (default-to { amount: u0 }
        (map-get? user-supplies {
          user: tx-sender,
          asset: asset-principal,
        })
      )))
      (map-set user-supplies {
        user: tx-sender,
        asset: asset-principal,
      } { amount: (+ (get amount current-supply) amount) }
      )
      (ok true)
    )
  )
)

(define-public (withdraw
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let ((asset-principal (contract-of asset)))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))
    (let ((current-supply (unwrap!
        (map-get? user-supplies {
          user: tx-sender,
          asset: asset-principal,
        })
        ERR_INSUFFICIENT_BALANCE
      )))
      (asserts! (>= (get amount current-supply) amount) ERR_INSUFFICIENT_BALANCE)
      (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
      (map-set user-supplies {
        user: tx-sender,
        asset: asset-principal,
      } { amount: (- (get amount current-supply) amount) }
      )
      (ok true)
    )
  )
)

(define-public (borrow
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let ((asset-principal (contract-of asset)))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))
    ;; Simplified health check - in production this would check LTV
    (let ((health (unwrap! (get-health-factor tx-sender) ERR_HEALTH_CHECK_FAILED)))
      (asserts! (>= health u10000) ERR_INSUFFICIENT_COLLATERAL)
    )
    (try! (as-contract (contract-call? asset transfer amount tx-sender tx-sender none)))
    (let ((current-borrow (default-to { amount: u0 }
        (map-get? user-borrows {
          user: tx-sender,
          asset: asset-principal,
        })
      )))
      (map-set user-borrows {
        user: tx-sender,
        asset: asset-principal,
      } { amount: (+ (get amount current-borrow) amount) }
      )
      (ok true)
    )
  )
)

(define-public (repay
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let ((asset-principal (contract-of asset)))
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))
    (try! (contract-call? asset transfer amount tx-sender (as-contract tx-sender) none))
    (let ((current-borrow (unwrap!
        (map-get? user-borrows {
          user: tx-sender,
          asset: asset-principal,
        })
        ERR_INSUFFICIENT_BALANCE
      )))
      (asserts! (>= (get amount current-borrow) amount) ERR_INSUFFICIENT_BALANCE)
      (map-set user-borrows {
        user: tx-sender,
        asset: asset-principal,
      } { amount: (- (get amount current-borrow) amount) }
      )
      (ok true)
    )
  )
)

;; Read Only

(define-read-only (get-user-borrow-balance
    (user principal)
    (asset principal)
  )
  (ok (get amount
    (default-to { amount: u0 }
      (map-get? user-borrows {
        user: user,
        asset: asset,
      })
    )))
)

(define-read-only (get-user-supply-balance
    (user principal)
    (asset principal)
  )
  (ok (get amount
    (default-to { amount: u0 }
      (map-get? user-supplies {
        user: user,
        asset: asset,
      })
    )))
)

(define-read-only (get-health-factor (user principal))
  ;; Placeholder implementation returning a high health factor
  (ok u20000)
)
