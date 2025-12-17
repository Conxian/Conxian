;;
;; @title Dimensional Engine (Facade)
;; @author Conxian Protocol
;; @desc This contract is the central facade for the Core Module, built on a
;; modular facade pattern. It acts as the single, secure entry point for all

;; user-facing calls related to position management, collateral, and risk.
;; It contains no business logic itself; instead, it delegates all calls to
;; specialized manager contracts.
;;

(use-trait dimensional-trait .dimensional-traits.dimensional-trait)
(use-trait funding-rate-calculator-trait .dimensional-traits.funding-rate-calculator-trait)
(use-trait collateral-manager-trait .dimensional-traits.collateral-manager-trait)
(use-trait risk-manager-trait .dimensional-traits.risk-manager-trait)
(use-trait rbac-trait .core-traits.rbac-trait)
(use-trait protocol-support-trait .core-traits.protocol-support-trait)

(define-constant ERR_PROTOCOL_PAUSED (err u5001))

(define-data-var position-manager principal tx-sender)
(define-data-var funding-rate-calculator principal tx-sender)
(define-data-var collateral-manager principal tx-sender)
(define-data-var risk-manager principal tx-sender)
(define-data-var protocol-coordinator principal tx-sender)

(define-private (is-protocol-paused)
  (contract-call? (var-get protocol-coordinator) is-protocol-paused)
)

;;
;; @desc Opens a new trading position by delegating the call to the Position
;; Manager. It first verifies sufficient collateral and deducts fees.
;; @param asset The principal of the asset being traded.
;; @param collateral The amount of collateral to back the position.
;; @param leverage The leverage level for the position.
;; @param is-long A boolean indicating if the position is long (true) or short (false).
;; @param stop-loss An optional trigger price to automatically close the position
;; to limit losses.
;; @param take-profit An optional trigger price to automatically close the
;; position to secure gains.
;; @returns A response indicating success or an error code.
;;
(define-public (open-position (asset principal) (collateral uint) (leverage uint) (is-long bool) (stop-loss (optional uint)) (take-profit (optional uint)))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get position-manager) open-position asset collateral leverage is-long stop-loss take-profit)
  )
)

;;
;; @desc Closes an existing position and handles the return of collateral.
;; @param position-id The unique identifier of the position to close.
;; @param asset The principal of the asset being traded.
;; @param slippage An optional slippage tolerance for the closing price.
;; @returns The result of the close operation, including collateral returned.
;;
(define-public (close-position (position-id uint) (asset principal) (slippage (optional uint)))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get position-manager) close-position position-id asset slippage)
  )
)

;;
;; @desc Triggers an update of the funding rate for a given asset.
;; @param asset The principal of the asset to update.
;; @returns A response indicating success or failure.
;;
(define-public (update-funding-rate (asset principal))
  (contract-call? (var-get funding-rate-calculator) update-funding-rate asset)
)

;;
;; @desc Applies the current funding rate to a specific position.
;; @param position-owner The principal of the position owner.
;; @param position-id The unique identifier of the position.
;; @returns A response indicating success or failure.
;;
(define-public (apply-funding-to-position (position-owner principal) (position-id uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get funding-rate-calculator) apply-funding-to-position
      position-owner position-id
    )
  )
)

;;
;; @desc Deposits funds into the Collateral Manager.
;; @param amount The amount to deposit.
;; @param token The principal of the token being deposited.
;; @returns A response indicating success or failure.
;;
(define-public (deposit-funds (amount uint) (token principal))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get collateral-manager) deposit-funds amount token)
  )
)

;;
;; @desc Withdraws funds from the Collateral Manager.
;; @param amount The amount to withdraw.
;; @param token The principal of the token being withdrawn.
;; @returns A response indicating success or failure.
;;
(define-public (withdraw-funds (amount uint) (token principal))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get collateral-manager) withdraw-funds amount token)
  )
)

;;
;; @desc Checks the health of a position to determine if it is near liquidation.
;; @param position-id The unique identifier of the position.
;; @returns A response detailing the position's health status.
;;
(define-public (check-position-health (position-id uint))
  (contract-call? (var-get risk-manager) assess-position-risk position-id)
)

;;
;; @desc Initiates the liquidation of an unhealthy position.
;; @param position-id The unique identifier of the position to liquidate.
;; @param liquidator The principal of the entity performing the liquidation.
;; @returns A response indicating the outcome of the liquidation.
;;
(define-public (liquidate-position (position-id uint) (liquidator principal))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (contract-call? (var-get risk-manager) liquidate-position position-id liquidator)
  )
)

;;
;; @desc Sets the risk parameters for the protocol.
;; @param new-max-leverage The new maximum leverage allowed.
;; @param new-maintenance-margin The new maintenance margin requirement.
;; @param new-liquidation-threshold The new threshold for liquidation.
;; @returns A response indicating success or failure.
;;
(define-public (set-risk-parameters (new-max-leverage uint) (new-maintenance-margin uint) (new-liquidation-threshold uint))
  (contract-call? (var-get risk-manager) set-risk-parameters new-max-leverage new-maintenance-margin new-liquidation-threshold)
)

;;
;; @desc Configures the rewards for liquidators.
;; @param min-reward The minimum reward for a successful liquidation.
;; @param max-reward The maximum reward for a successful liquidation.
;; @returns A response indicating success or failure.
;;
(define-public (set-liquidation-rewards (min-reward uint) (max-reward uint))
  (contract-call? (var-get risk-manager) set-liquidation-rewards min-reward max-reward)
)

;;
;; @desc Sets the insurance fund contract address.
;; @param fund The principal of the insurance fund.
;; @returns A response indicating success or failure.
;;
(define-public (set-insurance-fund (fund principal))
  (contract-call? (var-get risk-manager) set-insurance-fund fund)
)

;;
;; @desc Retrieves the current protocol fee rate.
;; @returns The protocol fee rate as a uint.
;;
(define-read-only (get-protocol-fee-rate)
  (ok u30)
)

(define-data-var contract-owner principal tx-sender)

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-public (set-protocol-coordinator (new-coordinator principal))
  (begin
    (asserts! (is-contract-owner) (err u1000))
    (var-set protocol-coordinator new-coordinator)
    (ok true)
  )
)
