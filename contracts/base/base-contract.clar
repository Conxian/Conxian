;; Base Contract
;; This contract serves as a foundational building block for other contracts in the Conxian ecosystem.
;; It provides common functionalities such as contract ownership, pausing mechanisms, and basic error handling.

(use-trait access-control-trait .base-traits.rbac-trait)
(use-trait pausable-trait .base-traits.pausable-trait)
(use-trait math-utils .base-traits.math-trait)

(impl-trait .base-traits.rbac-trait)
(impl-trait .base-traits.pausable-trait)
(impl-trait .base-traits.math-trait)

;; ===== Reentrancy Guard =====
(define-data-var reentrancy-guard bool false)

(define-private (non-reentrant)
  (asserts! (not (var-get reentrancy-guard)) (err u1000))
  (ok true)
)

(define-public (with-reentrancy-guard (inner (function () (response uint uint))))
  (let 
    (
      (check (try! (non-reentrant)))
      (var-set reentrancy-guard true)
      (result (try! (inner)))
    )
    (var-set reentrancy-guard false)
    (ok result)
  )
)

;; ===== Circuit Breaker =====
(define-data-var circuit-breaker-contract (optional principal) none)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker-contract)
    contract (contract-call? contract is-circuit-open)
    (ok false)
  )
)

(define-public (set-circuit-breaker-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u1001))
    (var-set circuit-breaker-contract (some contract))
    (ok true)
  )
)

;; ===== Common Error Codes =====
(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_INVALID_INPUT (err u1001))
(define-constant ERR_CONTRACT_PAUSED (err u1002))
(define-constant ERR_REENTRANCY (err u1003))
(define-constant ERR_CIRCUIT_OPEN (err u1004))

;; ===== Owner Functions =====
(define-data-var contract-owner principal tx-sender)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; ===== Pausable Functions =====
(define-data-var paused bool false)

(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

(define-private (check-not-paused)
  (asserts! (not (var-get paused)) ERR_CONTRACT_PAUSED)
  (ok true)
)

;; ===== Math Utilities =====
(define-private (safe-mul (a uint) (b uint))
  (let 
    ((result (* a b)))
    (asserts! (<= result u340282366920938463463374607431768211455) (err u2000)) ;; Max uint128
    (ok result)
  )
)

(define-private (safe-div (a uint) (b uint))
  (asserts! (not (is-eq b u0)) (err u2001)) ;; Division by zero
  (ok (/ a b))
)

;; ===== Initialization =====
(define-public (initialize (owner principal))
  (begin
    (var-set contract-owner owner)
    (ok true)
  )
)
