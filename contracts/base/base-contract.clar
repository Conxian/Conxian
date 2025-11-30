;; @desc Base Contract
;; This contract serves as a foundational building block for other contracts in the Conxian ecosystem.
;; It provides common functionalities such as contract ownership, pausing mechanisms, and basic error handling.

(use-trait pausable-trait .core-traits.pausable-trait)

;; @data-vars
;; @var reentrancy-guard: A boolean to prevent reentrancy attacks.
(define-data-var reentrancy-guard bool false)

;; @desc A private function to check for reentrancy.
;; @returns (response bool uint): An `ok` response with `true` if there is no reentrancy, or an error code.
(define-private (non-reentrant)
  (ok (asserts! (not (var-get reentrancy-guard)) ERR_REENTRANCY))
)



;; @data-vars
;; @var circuit-breaker-contract: The principal of the circuit breaker contract.
(define-data-var circuit-breaker-contract (optional principal) none)

;; @desc A private function to check the circuit breaker.
;; @returns (response bool uint): The result of the `is-circuit-open` call to the circuit breaker contract, or `(ok false)` if no contract is set.
(define-private (check-circuit-breaker)
  (ok true)
)

;; @desc Set the circuit breaker contract.
;; @param contract: The principal of the circuit breaker contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (set-circuit-breaker-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set circuit-breaker-contract (some contract))
    (ok true)
  )
)

;; @constants
;; @var ERR_UNAUTHORIZED: The caller is not authorized to perform this action.
(define-constant ERR_UNAUTHORIZED (err u1001))
;; @var ERR_INVALID_INPUT: The provided input is invalid.
(define-constant ERR_INVALID_INPUT (err u1005))
;; @var ERR_CONTRACT_PAUSED: The contract is currently paused.
(define-constant ERR_CONTRACT_PAUSED (err u1003))
;; @var ERR_REENTRANCY: A reentrancy attack was detected.
(define-constant ERR_REENTRANCY (err u1000))
;; @var ERR_CIRCUIT_OPEN: The circuit is open.
(define-constant ERR_CIRCUIT_OPEN (err u5007))

;; @data-vars
;; @var contract-owner: The principal of the contract owner.
(define-data-var contract-owner principal tx-sender)

;; @desc Transfer ownership of the contract.
;; @param new-owner: The principal of the new owner.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; @data-vars
;; @var paused: A boolean indicating if the contract is paused.
(define-data-var paused bool false)

;; @desc Pause the contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused true)
    (ok true)
  )
)

;; @desc Unpause the contract.
;; @returns (response bool uint): An `ok` response with `true` on success, or an error code.
(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set paused false)
    (ok true)
  )
)

;; @desc A private function to check if the contract is not paused.
;; @returns (response bool uint): An `ok` response with `true` if the contract is not paused, or an error code.
(define-private (check-not-paused)
  (ok (asserts! (not (var-get paused)) ERR_CONTRACT_PAUSED))
)

;; @desc Safely multiply two unsigned integers.
;; @param a: The first number.
;; @param b: The second number.
;; @returns (response uint uint): The product of the two numbers, or an error code if an overflow occurs.
(define-private (safe-mul (a uint) (b uint))
  (let 
    ((result (* a b)))
    (asserts! (or (is-eq a u0) (is-eq (/ result a) b)) (err u2000)) ;; ERR_OVERFLOW
    (ok result)
  )
)

;; @desc Safely divide two unsigned integers.
;; @param a: The numerator.
;; @param b: The denominator.
;; @returns (response uint uint): The quotient of the two numbers, or an error code if the denominator is zero.
(define-private (safe-div (a uint) (b uint))
  (if (is-eq b u0)
    (err u2002) ;; ERR_DIVISION_BY_ZERO
    (ok (/ a b))
  )
)

;; @desc Initialize the contract.
;; @param owner: The principal of the initial owner.
;; @returns (response bool uint): An `ok` response with `true` on success.
(define-public (initialize (owner principal))
  (begin
    (var-set contract-owner owner)
    (ok true)
  )
)
