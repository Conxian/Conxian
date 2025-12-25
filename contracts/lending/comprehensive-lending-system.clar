;;
;; @title Comprehensive Lending System (Facade)
;; @author Conxian Protocol
;; @desc This contract is the primary facade for the lending module. It provides a
;; single, secure entry point for all lending and borrowing operations,
;; delegating the core logic to the `lending-manager` contract. This modular
;; design enhances security, simplifies user interaction, and improves
;; maintainability.
;;

;; Traits
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)
(use-trait circuit-breaker-trait .security-monitoring.circuit-breaker-trait)
(use-trait hook-trait .defi-traits.hook-trait)
(use-trait fee-manager-trait .defi-traits.fee-manager-trait)
(use-trait lending-manager-trait .lending-manager-trait.lending-manager-trait)
(use-trait protocol-support-trait .core-traits.protocol-support-trait)

;; Constants
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_HEALTH_CHECK_FAILED (err u1005))
(define-constant ERR_CIRCUIT_BREAKER_OPEN (err u1006))
(define-constant ERR_PROTOCOL_PAUSED (err u5001))
(define-constant LENDING_SERVICE "lending-core")

;; Data Variables
(define-data-var contract-owner principal tx-sender)
(define-data-var lending-manager-contract principal .lending-manager)
(define-data-var min-health-factor uint u10000)
(define-data-var protocol-coordinator principal tx-sender)

(define-private (is-protocol-paused)
  (unwrap! (contract-call? .conxian-protocol is-protocol-paused) true)
)

;; Circuit Breaker
(define-private (check-circuit-breaker)
  (match (contract-call? .circuit-breaker check-circuit-state LENDING_SERVICE)
    success (ok true)
    error ERR_CIRCUIT_BREAKER_OPEN
  )
)

;; --- Internal Core Logic ---

(define-private (do-supply (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (try! (check-circuit-breaker))
    (contract-call? .lending-manager-trait (var-get lending-manager-contract) supply asset amount)
  )
)

(define-private (do-withdraw (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (try! (check-circuit-breaker))
    (contract-call? .lending-manager-trait (var-get lending-manager-contract) withdraw asset amount)
  )
)

(define-private (do-borrow (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (try! (check-circuit-breaker))
    (contract-call? .lending-manager-trait (var-get lending-manager-contract) borrow asset amount)
  )
)

(define-private (do-repay (asset <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (not (is-protocol-paused)) ERR_PROTOCOL_PAUSED)
    (try! (check-circuit-breaker))
    (contract-call? .lending-manager-trait (var-get lending-manager-contract) repay asset amount)
  )
)

;; --- Public API (Facade Functions) ---

(define-public (supply (asset <sip-010-ft-trait>) (amount uint))
  (do-supply asset amount)
)

(define-public (withdraw (asset <sip-010-ft-trait>) (amount uint))
  (do-withdraw asset amount)
)

(define-public (borrow (asset <sip-010-ft-trait>) (amount uint))
  (do-borrow asset amount)
)

(define-public (repay (asset <sip-010-ft-trait>) (amount uint))
  (do-repay asset amount)
)

;; --- Hook Enabled Functions ---

(define-public (supply-with-hook (asset <sip-010-ft-trait>) (amount uint) (hook <hook-trait>))
  (let ((asset-principal (contract-of asset)))
    (begin
      (try! (contract-call? hook on-action "SUPPLY_PRE" tx-sender amount asset-principal none))
      (let ((res (do-supply asset amount)))
        (try! (contract-call? hook on-action "SUPPLY_POST" tx-sender amount asset-principal none))
        res
      )
    )
  )
)

(define-public (withdraw-with-hook (asset <sip-010-ft-trait>) (amount uint) (hook <hook-trait>))
  (let ((asset-principal (contract-of asset)))
    (begin
      (try! (contract-call? hook on-action "WITHDRAW_PRE" tx-sender amount asset-principal none))
      (let ((res (do-withdraw asset amount)))
        (try! (contract-call? hook on-action "WITHDRAW_POST" tx-sender amount asset-principal none))
        res
      )
    )
  )
)

(define-public (borrow-with-hook (asset <sip-010-ft-trait>) (amount uint) (hook <hook-trait>))
  (let ((asset-principal (contract-of asset)))
    (begin
      (try! (contract-call? hook on-action "BORROW_PRE" tx-sender amount asset-principal none))
      (let ((res (do-borrow asset amount)))
        (try! (contract-call? hook on-action "BORROW_POST" tx-sender amount asset-principal none))
        res
      )
    )
  )
)

(define-public (repay-with-hook (asset <sip-010-ft-trait>) (amount uint) (hook <hook-trait>))
  (let ((asset-principal (contract-of asset)))
    (begin
      (try! (contract-call? hook on-action "REPAY_PRE" tx-sender amount asset-principal none))
      (let ((res (do-repay asset amount)))
        (try! (contract-call? hook on-action "REPAY_POST" tx-sender amount asset-principal none))
        res
      )
    )
  )
)


;; --- Health Factor Checks ---

(define-read-only (get-health-factor (user principal))
  (let ((total-supply (unwrap-panic (contract-call? .lending-manager get-user-supply-balance user tx-sender)))
        (total-borrow (unwrap-panic (contract-call? .lending-manager get-user-borrow-balance user tx-sender))))
    (if (is-eq (unwrap-panic total-borrow) u0)
      (ok u20000)
      (ok (/ (* (unwrap-panic total-supply) u10000) (unwrap-panic total-borrow)))
    )
  )
)

(define-public (borrow-checked (asset <sip-010-ft-trait>) (amount uint))
  (let ((caller tx-sender))
    (let ((current-hf (unwrap! (get-health-factor caller) ERR_HEALTH_CHECK_FAILED)))
      (asserts! (>= current-hf (var-get min-health-factor)) ERR_HEALTH_CHECK_FAILED)
      (do-borrow asset amount)
    )
  )
)

(define-public (withdraw-checked (asset <sip-010-ft-trait>) (amount uint))
  (let ((caller tx-sender))
    (let ((current-hf (unwrap! (get-health-factor caller) ERR_HEALTH_CHECK_FAILED)))
      (asserts! (>= current-hf (var-get min-health-factor)) ERR_HEALTH_CHECK_FAILED)
      (do-withdraw asset amount)
    )
  )
)


;; --- Admin Functions ---

(define-public (set-lending-manager (manager-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set lending-manager-contract manager-address)
    (ok true)
  )
)

(define-public (set-min-health-factor (new-min uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set min-health-factor new-min)
    (ok true)
  )
)

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
