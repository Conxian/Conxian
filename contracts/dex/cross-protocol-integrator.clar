;; cross-protocol-integrator.clar

;; This contract facilitates cross-protocol integration for maximum yield opportunities.

(use-trait yield-optimizer-trait .traits.yield-optimizer-trait.yield-optimizer-trait)
(use-trait sip-010-ft-trait .requirements.sip-010-trait-ft-standard.sip-010-trait-ft-standard)
(use-trait circuit-breaker-trait .traits.circuit-breaker-trait.circuit-breaker-trait)
(use-trait rbac-trait .decentralized-trait-registry.decentralized-trait-registry)

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_STRATEGY_ALREADY_EXISTS (err u1001))
(define-constant ERR_STRATEGY_NOT_FOUND (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_CIRCUIT_OPEN (err u1004))
(define-constant ERR_NO_ACTIVE_STRATEGY (err u1005))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var strategy-counter uint u0)
(define-data-var yield-optimizer (contract-of yield-optimizer-trait) (as-contract tx-sender))
(define-data-var circuit-breaker-contract (optional <circuit-breaker-trait>) none)

;; Maps
;; strategies: maps strategy-id to strategy-details (principal, token, protocol-id)
(define-map strategies uint {
    strategy-principal: principal,
    token: principal,
    protocol-id: uint
})
;; user-deposits: maps (user, strategy-id) to amount
(define-map user-deposits {user: principal, strategy-id: uint} uint)

;; Private helper function to check circuit breaker status
(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker-contract)
    cb
    (asserts! (not (unwrap-panic (contract-call? cb is-circuit-open))) ERR_CIRCUIT_OPEN)
    (ok true)
  )
)

;; @desc Registers a new cross-protocol yield strategy.
;; @param strategy-principal The principal of the strategy contract.
;; @param token The token used in the strategy (e.g., STX, USDA).
;; @param protocol-id A unique identifier for the external protocol.
;; @returns An `ok` response with the new strategy ID or an error.
(define-public (register-strategy (strategy-principal principal) (token principal) (protocol-id uint))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) ERR_UNAUTHORIZED)
    (let ((new-strategy-id (+ (var-get strategy-counter) u1)))
      (map-set strategies new-strategy-id {
          strategy-principal: strategy-principal,
          token: token,
          protocol-id: protocol-id
      })
      (var-set strategy-counter new-strategy-id)
      (ok new-strategy-id)
    )
  )
)

;; @desc Deposits funds into a registered cross-protocol strategy.
;; @param strategy-id The ID of the strategy to deposit into.
;; @param token The token to deposit.
;; @param amount The amount to deposit.
;; @returns An `ok` response or an error.
(define-public (deposit (strategy-id uint) (token <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let ((strategy-details (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
      ;; Transfer tokens to the strategy contract
      (try! (contract-call? token transfer amount tx-sender (get strategy-principal strategy-details)))
      ;; Update user deposits
      (map-set user-deposits {user: tx-sender, strategy-id: strategy-id}
               (+ (default-to u0 (map-get? user-deposits {user: tx-sender, strategy-id: strategy-id})) amount))
      (ok true)
    )
  )
)

;; @desc Withdraws funds from a registered cross-protocol strategy.
;; @param strategy-id The ID of the strategy to withdraw from.
;; @param token The token to withdraw.
;; @param amount The amount to withdraw.
;; @returns An `ok` response or an error.
(define-public (withdraw (strategy-id uint) (token <sip-010-ft-trait>) (amount uint))
  (begin
    (try! (check-circuit-breaker))
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (let ((current-deposit (unwrap! (map-get? user-deposits {user: tx-sender, strategy-id: strategy-id}) ERR_STRATEGY_NOT_FOUND)))
      (asserts! (>= current-deposit amount) ERR_INVALID_AMOUNT)
      (let ((strategy-details (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
        ;; Transfer tokens from the strategy contract back to the user
        (try! (as-contract (contract-call? token transfer amount (get strategy-principal strategy-details) tx-sender)))
        ;; Update user deposits
        (map-set user-deposits {user: tx-sender, strategy-id: strategy-id} (- current-deposit amount))
        (ok true)
      )
    )
  )
)

;; @desc Executes a cross-protocol strategy (e.g., rebalance, compound).
;; This function would typically call into the yield-optimizer or directly to the strategy contract.
;; @param strategy-id The ID of the strategy to execute.
;; @returns An `ok` response or an error.
(define-public (execute-strategy (strategy-id uint))
  (begin
    (try! (check-circuit-breaker))
    (let ((strategy-details (unwrap! (map-get? strategies strategy-id) ERR_STRATEGY_NOT_FOUND)))
      ;; Example: Call a rebalance function on the yield optimizer
      ;; In a real scenario, this would be more complex, potentially calling a specific function
      ;; on the strategy-principal based on protocol-id.
      (try! (contract-call? (var-get yield-optimizer) rebalance-strategy (get strategy-principal strategy-details)))
      (ok true)
    )
  )
)

;; @desc Sets the yield-optimizer contract.
;; @param optimizer The principal of the yield-optimizer contract.
;; @returns An `ok` response or an error.
(define-public (set-yield-optimizer-contract (optimizer (contract-of yield-optimizer-trait)))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) ERR_UNAUTHORIZED)
    (var-set yield-optimizer optimizer)
    (ok true)
  )
)

;; @desc Sets the circuit breaker contract.
;; @param cb The circuit breaker trait object.
;; @returns An `ok` response or an error.
(define-public (set-circuit-breaker (cb <circuit-breaker-trait>))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) ERR_UNAUTHORIZED)
    (var-set circuit-breaker-contract (some cb))
    (ok true)
  )
)

;; @desc Transfers ownership of the contract.
;; @param new-owner The principal of the new owner.
;; @returns An `ok` response or an error.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-ok (contract-call? .rbac-contract has-role "contract-owner")) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Read-only functions

;; @desc Gets the details of a registered strategy.
;; @param strategy-id The ID of the strategy.
;; @returns An `ok` response with the strategy details or an error.
(define-read-only (get-strategy-details (strategy-id uint))
  (ok (map-get? strategies strategy-id))
)

;; @desc Gets the deposit amount for a user in a specific strategy.
;; @param user The principal of the user.
;; @param strategy-id The ID of the strategy.
;; @returns An `ok` response with the deposit amount or `none`.
(define-read-only (get-user-deposit (user principal) (strategy-id uint))
  (ok (map-get? user-deposits {user: user, strategy-id: strategy-id}))
)

;; @desc Gets the current strategy counter.
;; @returns An `ok` response with the strategy counter.
(define-read-only (get-strategy-count)
  (ok (var-get strategy-counter))
)
