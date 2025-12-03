;; comprehensive-lending-system.clar
;; Core lending protocol contract with interest accrual and hooks

;; Traits
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)
(use-trait hook-trait .defi-traits.hook-trait)
(use-trait fee-manager-trait .defi-traits.fee-manager-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_ASSET (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u1003))
(define-constant ERR_ZERO_AMOUNT (err u1004))
(define-constant ERR_HEALTH_CHECK_FAILED (err u1005))
(define-constant ERR_CIRCUIT_BREAKER_OPEN (err u1006))
(define-constant ERR_INTEREST_ACCRUAL_FAILED (err u1007))
(define-constant LENDING_SERVICE "lending-core")
(define-constant PRECISION u1000000000000000000)

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var protocol-fee-switch principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.protocol-fee-switch)

;; Maps
;; amount: Principal balance (scaled)
;; index: Index at last update (informational, strictly we just need principal)
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
(define-map user-borrows
  {
    user: principal,
    asset: principal,
  }
  {
    amount: uint,
    index: uint,
  }
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
  (let (
      (asset-principal (contract-of asset))
      (sender tx-sender)
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))

    ;; Accrue Interest
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
          ;; Calculate delta principal: amount / index
          (delta-principal (/ (* amount PRECISION) supply-index))
          (new-principal (+ old-amount delta-principal))
        )
        (try! (contract-call? asset transfer amount sender (as-contract tx-sender) none))
        (map-set user-supplies {
          user: sender,
          asset: asset-principal,
        } {
          amount: new-principal,
          index: supply-index,
        })

        ;; Update Global State
        (try! (contract-call? .interest-rate-model update-market-state asset-principal
          (to-int amount) 0
        ))
        (ok true)
      )
    )
  )
)

(define-public (withdraw
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let (
      (asset-principal (contract-of asset))
      (caller tx-sender)
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))

    (let ((market (unwrap!
        (contract-call? .interest-rate-model accrue-interest asset-principal)
        ERR_INTEREST_ACCRUAL_FAILED
      )))
      (let (
          (supply-index (get supply-index market))
          (current-supply (unwrap!
            (map-get? user-supplies {
              user: caller,
              asset: asset-principal,
            })
            ERR_INSUFFICIENT_BALANCE
          ))
          (current-principal (get amount current-supply))
          ;; Calculate principal to remove: amount / index
          (remove-principal (/ (* amount PRECISION) supply-index))
        )
        (asserts! (>= current-principal remove-principal)
          ERR_INSUFFICIENT_BALANCE
        )

        (try! (as-contract (contract-call? asset transfer amount tx-sender caller none)))
        (map-set user-supplies {
          user: caller,
          asset: asset-principal,
        } {
          amount: (- current-principal remove-principal),
          index: supply-index,
        })

        (try! (contract-call? .interest-rate-model update-market-state asset-principal
          (- 0 (to-int amount)) 0
        ))
        (ok true)
      )
    )
  )
)

(define-public (borrow
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let (
      (asset-principal (contract-of asset))
      (caller tx-sender)
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))

    ;; Health Check
    (let ((health (unwrap! (get-health-factor caller) ERR_HEALTH_CHECK_FAILED)))
      (asserts! (>= health u10000) ERR_INSUFFICIENT_COLLATERAL)
    )

    (let ((market (unwrap!
        (contract-call? .interest-rate-model accrue-interest asset-principal)
        ERR_INTEREST_ACCRUAL_FAILED
      )))
      (let (
          (borrow-index (get borrow-index market))
          (current-borrow (default-to {
            amount: u0,
            index: borrow-index,
          }
            (map-get? user-borrows {
              user: caller,
              asset: asset-principal,
            })
          ))
          (old-principal (get amount current-borrow))
          ;; New principal = amount / index
          (delta-principal (/ (* amount PRECISION) borrow-index))
          (new-principal (+ old-principal delta-principal))
        )
        (try! (as-contract (contract-call? asset transfer amount tx-sender caller none)))
        (map-set user-borrows {
          user: caller,
          asset: asset-principal,
        } {
          amount: new-principal,
          index: borrow-index,
        })

        ;; Update Market: Cash -amount, Borrows +amount
        (try! (contract-call? .interest-rate-model update-market-state asset-principal
          (- 0 (to-int amount)) (to-int amount)
        ))
        (ok true)
      )
    )
  )
)

(define-public (repay
    (asset <sip-010-ft-trait>)
    (amount uint)
  )
  (let (
      (asset-principal (contract-of asset))
      (sender tx-sender)
    )
    (asserts! (> amount u0) ERR_ZERO_AMOUNT)
    (try! (check-circuit-breaker))

    (let ((market (unwrap!
        (contract-call? .interest-rate-model accrue-interest asset-principal)
        ERR_INTEREST_ACCRUAL_FAILED
      )))
      (let (
          (borrow-index (get borrow-index market))
          (current-borrow (unwrap!
            (map-get? user-borrows {
              user: sender,
              asset: asset-principal,
            })
            ERR_INSUFFICIENT_BALANCE
          ))
          (current-principal (get amount current-borrow))
          ;; Principal to repay = amount / index
          (repay-principal (/ (* amount PRECISION) borrow-index))
        )
        ;; Cap repayment to max debt
        (let (
            (actual-repay-principal (if (> repay-principal current-principal)
              current-principal
              repay-principal
            ))
            (actual-amount (/ (* actual-repay-principal borrow-index) PRECISION)) ;; convert back to token amount
          )
          (try! (contract-call? asset transfer actual-amount sender
            (as-contract tx-sender) none
          ))
          (map-set user-borrows {
            user: sender,
            asset: asset-principal,
          } {
            amount: (- current-principal actual-repay-principal),
            index: borrow-index,
          })

          ;; Update Market: Cash +amount, Borrows -amount
          (try! (contract-call? .interest-rate-model update-market-state
            asset-principal (to-int actual-amount)
            (- 0 (to-int actual-amount))
          ))
          (ok true)
        )
      )
    )
  )
)

;; --- Hook Enabled Functions ---

(define-public (supply-with-hook
    (asset <sip-010-ft-trait>)
    (amount uint)
    (hook <hook-trait>)
  )
  (begin
    (try! (contract-call? hook on-action "SUPPLY_PRE" tx-sender amount
      (contract-of asset) none
    ))
    (let ((res (supply asset amount)))
      (try! (contract-call? hook on-action "SUPPLY_POST" tx-sender amount
        (contract-of asset) none
      ))
      res
    )
  )
)

(define-public (withdraw-with-hook
    (asset <sip-010-ft-trait>)
    (amount uint)
    (hook <hook-trait>)
  )
  (begin
    (try! (contract-call? hook on-action "WITHDRAW_PRE" tx-sender amount
      (contract-of asset) none
    ))
    (let ((res (withdraw asset amount)))
      (try! (contract-call? hook on-action "WITHDRAW_POST" tx-sender amount
        (contract-of asset) none
      ))
      res
    )
  )
)

(define-public (borrow-with-hook
    (asset <sip-010-ft-trait>)
    (amount uint)
    (hook <hook-trait>)
  )
  (begin
    (try! (contract-call? hook on-action "BORROW_PRE" tx-sender amount
      (contract-of asset) none
    ))
    (let ((res (borrow asset amount)))
      (try! (contract-call? hook on-action "BORROW_POST" tx-sender amount
        (contract-of asset) none
      ))
      res
    )
  )
)

(define-public (repay-with-hook
    (asset <sip-010-ft-trait>)
    (amount uint)
    (hook <hook-trait>)
  )
  (begin
    (try! (contract-call? hook on-action "REPAY_PRE" tx-sender amount
      (contract-of asset) none
    ))
    (let ((res (repay asset amount)))
      (try! (contract-call? hook on-action "REPAY_POST" tx-sender amount
        (contract-of asset) none
      ))
      res
    )
  )
)

(define-public (withdraw-reserves
    (asset <sip-010-ft-trait>)
    (switch <fee-manager-trait>)
  )
  (let (
      (asset-principal (contract-of asset))
      (switch-principal (contract-of switch))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-eq switch-principal (var-get protocol-fee-switch))
      ERR_UNAUTHORIZED
    )
    (let ((market (unwrap!
        (contract-call? .interest-rate-model get-market-info asset-principal)
        ERR_INVALID_ASSET
      )))
      (let ((reserves (get total-reserves market)))
        (if (> reserves u0)
          (begin
            ;; 1. Reduce reserves in model (accounting)
            (try! (contract-call? .interest-rate-model reduce-reserves asset-principal
              reserves
            ))
            ;; 2. Transfer tokens to switch
            (try! (as-contract (contract-call? asset transfer reserves tx-sender switch-principal
              none
            )))
            ;; 3. Route fees (switch calculates splits)
            (try! (contract-call? switch route-fees asset reserves false "LENDING"))

            (print {
              event: "reserves-withdrawn",
              asset: asset-principal,
              amount: reserves,
            })
            (ok reserves)
          )
          (ok u0)
        )
      )
    )
  )
)

;; Read Only

(define-read-only (get-user-borrow-balance
    (user principal)
    (asset principal)
  )
  (let ((borrow-data (default-to {
      amount: u0,
      index: u0,
    }
      (map-get? user-borrows {
        user: user,
        asset: asset,
      })
    )))
    (if (is-eq (get amount borrow-data) u0)
      (ok u0)
      (match (contract-call? .interest-rate-model get-market-info asset)
        market-info
        (ok (/ (* (get amount borrow-data) (get borrow-index market-info)) PRECISION))
        (ok (/ (* (get amount borrow-data) (get index borrow-data)) PRECISION)) ;; Fallback if none
      )
    )
  )
)

(define-read-only (get-user-supply-balance
    (user principal)
    (asset principal)
  )
  (let ((supply-data (default-to {
      amount: u0,
      index: u0,
    }
      (map-get? user-supplies {
        user: user,
        asset: asset,
      })
    )))
    (if (is-eq (get amount supply-data) u0)
      (ok u0)
      (match (contract-call? .interest-rate-model get-market-info asset)
        market-info
        (ok (/ (* (get amount supply-data) (get supply-index market-info)) PRECISION))
        (ok (/ (* (get amount supply-data) (get index supply-data)) PRECISION)) ;; Fallback
      )
    )
  )
)

(define-read-only (get-health-factor (user principal))
  ;; Placeholder implementation returning a high health factor
  (ok u20000)
)
