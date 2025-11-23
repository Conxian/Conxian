;; @desc Core contract for the dimensional engine.
;; This contract serves as a facade, delegating calls to the appropriate
;; specialized contracts for position management, funding rate calculation,
;; collateral management, and risk management.

(use-trait dimensional-trait .trait-dimensional.dimensional-trait)
(use-trait funding-rate-calculator-trait .trait-dimensional.funding-rate-calculator-trait)
(use-trait collateral-manager-trait .trait-dimensional.collateral-manager-trait)
(use-trait risk-manager-trait .trait-risk-management.risk-manager-trait)
(use-trait rbac-trait .trait-core-protocol.02-core-protocol.rbac-trait-trait)

;; @data-vars
(define-data-var position-manager principal .position-manager)
(define-data-var funding-rate-calculator principal .funding-rate-calculator)
(define-data-var collateral-manager principal .collateral-manager)
(define-data-var risk-manager principal .risk-manager)

;; --- Position Management ---
(define-public (open-position (asset principal) (collateral uint) (leverage uint) (is-long bool) (stop-loss (optional uint)) (take-profit (optional uint)))
  (let (
    (collateral-balance (try! (contract-call? .collateral-manager get-balance tx-sender)))
    (fee-rate (try! (contract-call? (var-get collateral-manager) get-protocol-fee-rate)))(fee (* collateral fee-rate))
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
    (try! (as-contract (contract-call? .collateral-manager deposit-funds collateral-returned asset)))
    (ok result)
  )
)

;; --- Funding Rate Calculation ---
(define-public (update-funding-rate (asset principal))
  (contract-call? .funding-rate-calculator update-funding-rate asset)
)

(define-public (apply-funding-to-position (position-owner principal) (position-id uint))
  (contract-call? .funding-rate-calculator apply-funding-to-position
    position-owner position-id
  )
)

;; --- Collateral Management ---
(define-public (deposit-funds (amount uint) (token principal))
  (contract-call? .collateral-manager deposit-funds amount token)
)

(define-public (withdraw-funds (amount uint) (token principal))
  (contract-call? .collateral-manager withdraw-funds amount token)
)

;; --- Risk Management ---
(define-public (set-risk-parameters (new-max-leverage uint) (new-maintenance-margin uint) (new-liquidation-threshold uint))
  (contract-call? .risk-manager set-risk-parameters new-max-leverage
    new-maintenance-margin new-liquidation-threshold
  )
)

(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (contract-call? .risk-manager set-liquidation-rewards min-reward max-reward)
)

(define-public (set-insurance-fund (fund principal))
  (contract-call? .risk-manager set-insurance-fund fund)
)

;; --- Read-Only Functions ---
(define-read-only (get-protocol-fee-rate)
  (ok u30) ;; 0.3%
)
