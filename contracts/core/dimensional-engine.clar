;; @desc Core contract for the dimensional engine.

(use-trait dimensional-trait .dimensional-traits.dimensional-trait)
(use-trait funding-rate-calculator-trait .dimensional-traits.funding-rate-calculator-trait)
(use-trait collateral-manager-trait .dimensional-traits.collateral-manager-trait)
(use-trait risk-manager-trait .dimensional-traits.risk-manager-trait)
(use-trait rbac-trait .core-traits.rbac-trait)

(define-data-var position-manager principal tx-sender)
(define-data-var funding-rate-calculator principal tx-sender)
(define-data-var collateral-manager principal tx-sender)
(define-data-var risk-manager principal tx-sender)

(define-public (open-position (asset principal) (collateral uint) (leverage uint) (is-long bool) (stop-loss (optional uint)) (take-profit (optional uint)))
  (let (
    (collateral-balance (unwrap! (contract-call? .collateral-manager get-balance tx-sender) (err u2003)))
    (fee-rate (try! (contract-call? .collateral-manager get-protocol-fee-rate)))
    (fee (* collateral fee-rate))
    (total-cost (+ collateral fee))
  )
    (asserts! (>= collateral-balance total-cost) (err u2003))
    (try! (contract-call? .collateral-manager withdraw-funds total-cost asset))
    (contract-call? .position-manager open-position asset
      collateral leverage is-long stop-loss take-profit
    )
  )
)

(define-public (close-position (position-id uint) (asset principal) (slippage (optional uint)))
  (let (
    (result (try! (contract-call? .position-manager close-position position-id slippage)))
    (collateral-returned (get collateral-returned result))
  )
    (try! (as-contract (contract-call? .collateral-manager deposit-funds
      collateral-returned asset
    )))
    (ok result)
  )
)

(define-public (update-funding-rate (asset principal))
  (let ((funding-calculator-contract (var-get funding-rate-calculator)))
    (contract-call? funding-calculator-contract update-funding-rate asset)
  )
)

(define-public (apply-funding-to-position (position-owner principal) (position-id uint))
  (let ((funding-calculator-contract (var-get funding-rate-calculator)))
    (contract-call? funding-calculator-contract apply-funding-to-position
      position-owner position-id
    )
  )
)

(define-public (deposit-funds (amount uint) (token principal))
  (let ((collateral-manager-contract (var-get collateral-manager)))
    (contract-call? collateral-manager-contract deposit-funds amount token)
  )
)

(define-public (withdraw-funds (amount uint) (token principal))
  (let ((collateral-manager-contract (var-get collateral-manager)))
    (contract-call? collateral-manager-contract withdraw-funds amount token)
  )
)

(define-public (check-position-health (position-id uint))
  (let ((risk-manager-contract (var-get risk-manager)))
    (contract-call? risk-manager-contract check-position-health position-id)
  )
)

(define-public (liquidate-position (position-id uint) (liquidator principal))
  (let ((risk-manager-contract (var-get risk-manager)))
    (contract-call? risk-manager-contract liquidate-position position-id
      liquidator
    )
  )
)

(define-public (set-risk-parameters (new-max-leverage uint) (new-maintenance-margin uint) (new-liquidation-threshold uint))
  (let ((risk-manager-contract (var-get risk-manager)))
    (contract-call? risk-manager-contract set-risk-parameters new-max-leverage
      new-maintenance-margin new-liquidation-threshold
    )
  )
)

(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (let ((risk-manager-contract (var-get risk-manager)))
    (contract-call? risk-manager-contract set-liquidation-rewards min-reward
      max-reward
    )
  )
)

(define-public (set-insurance-fund (fund principal))
  (let ((risk-manager-contract (var-get risk-manager)))
    (contract-call? risk-manager-contract set-insurance-fund fund)
  )
)

(define-read-only (get-protocol-fee-rate)
  (ok u30)
)
