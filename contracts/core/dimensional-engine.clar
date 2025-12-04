;;
;; @title Dimensional Engine
;; @author Conxian Protocol
;; @desc This contract is the central facade for the dimensional engine, routing all
;; user-facing calls to the appropriate specialized contracts (e.g., Position
;; Manager, Collateral Manager). It enforces a modular architecture where this
;; contract acts as the single entry point, simplifying user interaction and
;; enhancing security by isolating logic.
;;

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
    (fee-rate (unwrap! (contract-call? .collateral-manager get-protocol-fee-rate) (err u2004)))
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
  (contract-call? .funding-rate-calculator update-funding-rate asset)
)

(define-public (apply-funding-to-position (position-owner principal) (position-id uint))
  (contract-call? .funding-rate-calculator apply-funding-to-position
    position-owner position-id
  )
)

(define-public (deposit-funds (amount uint) (token principal))
  (contract-call? .collateral-manager deposit-funds amount token)
)

(define-public (withdraw-funds (amount uint) (token principal))
  (contract-call? .collateral-manager withdraw-funds amount token)
)

(define-public (check-position-health (position-id uint))
  (contract-call? .risk-manager check-position-health position-id)
)

(define-public (liquidate-position (position-id uint) (liquidator principal))
  (contract-call? .risk-manager liquidate-position position-id liquidator)
)

(define-public (set-risk-parameters (new-max-leverage uint) (new-maintenance-margin uint) (new-liquidation-threshold uint))
  (contract-call? .risk-manager set-risk-parameters new-max-leverage new-maintenance-margin new-liquidation-threshold)
)

(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (contract-call? .risk-manager set-liquidation-rewards min-reward max-reward)
)

(define-public (set-insurance-fund (fund principal))
  (contract-call? .risk-manager set-insurance-fund fund)
)

(define-read-only (get-protocol-fee-rate)
  (ok u30)
)
