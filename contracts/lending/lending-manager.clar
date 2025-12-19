;; lending-manager.clar
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_ZERO_AMOUNT (err u1004))
(define-constant ERR_INTEREST_ACCRUAL_FAILED (err u1007))
(define-constant PRECISION u1000000000000000000)

;; Data Maps - Moved from comprehensive-lending-system
(define-map user-supplies
  {
    user: principal,
    asset: principal,
  }
  {
    amount: uint,
    index: uint,
  }
)
(define-map user-total-supplies
  principal
  uint
)

(define-trait lending-manager-trait
  (
    (deposit (asset-principal principal) (amount uint) (sender principal) (response bool uint))
  )
)

(define-public (deposit (asset-principal principal) (amount uint) (sender principal))
  (begin
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)

    ;; Accrue Interest - This is a call to another contract
    (let ((market (unwrap!
        (contract-call? .interest-rate-model accrue-interest asset-principal)
        ERR_INTEREST_ACCRUAL_FAILED
      )))
      (let (
          (supply-index (get supply-index market))
          (current-supply (default-to {
            amount: u0,
            index: supply-index,
          }
            (map-get? user-supplies {
              user: sender,
              asset: asset-principal,
            })
          ))
          (old-amount (get amount current-supply))
          (delta-principal (/ (* amount PRECISION) supply-index))
          (new-principal (+ old-amount delta-principal))
        )
        (map-set user-supplies {
          user: sender,
          asset: asset-principal,
        } {
          amount: new-principal,
          index: supply-index,
        })
        (map-set user-total-supplies sender
          (+ (default-to u0 (map-get? user-total-supplies sender)) amount)
        )
        (try! (contract-call? .interest-rate-model update-market-state asset-principal
          (to-int amount) 0
        ))
        (ok true)
      )
    )
  )
)
