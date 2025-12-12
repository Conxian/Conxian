;; Weighted Swap Pool
;; This contract implements a weighted swap pool for assets with different weights.

(impl-trait .defi-traits.pool-trait)
(use-trait sip-010-ft-trait .sip-standards.sip-010-ft-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_INVALID_WEIGHTS (err u4001))
(define-constant ERR_INVALID_AMOUNTS (err u4002))
(define-constant ERR_INVALID_TOKEN (err u3003))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var token-x principal tx-sender)
(define-data-var token-y principal tx-sender)
(define-data-var balance-x uint u0)
(define-data-var balance-y uint u0)
(define-data-var weight-x uint u50000000) ;; 50%
(define-data-var weight-y uint u50000000) ;; 50%

;; --- Public Functions ---

(define-public (create-instance (token-a principal) (token-b principal) (params (buff 256)))
  (begin
    (var-set token-x token-a)
    (var-set token-y token-b)
    (let ((weights (unwrap! (get-weights-from-params params) (err ERR_INVALID_WEIGHTS))))
      (var-set weight-x (get weight-x weights))
      (var-set weight-y (get weight-y weights))
    )
    (ok (as-contract tx-sender))
  ))

(define-public (swap (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>))
  (let (
    (in-principal (contract-of token-in))
    (out-principal (contract-of token-out))
    (is-x-in (is-eq in-principal (var-get token-x)))
  )
    (asserts! (or is-x-in (is-eq in-principal (var-get token-y))) ERR_INVALID_TOKEN)
    (asserts! (is-eq out-principal (if is-x-in (var-get token-y) (var-get token-x))) ERR_INVALID_TOKEN)
    
    (if is-x-in
      (swap-internal amount-in token-in token-out true)
      (swap-internal amount-in token-in token-out false)
    )
  )
)

(define-private (swap-internal (amount-in uint) (token-in <sip-010-ft-trait>) (token-out <sip-010-ft-trait>) (x-to-y bool))
  (let (
    (bal-x (var-get balance-x))
    (bal-y (var-get balance-y))
    (w-x (var-get weight-x))
    (w-y (var-get weight-y))
  )
    (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
    
    (let ((amount-out (get-amount-out amount-in (if x-to-y bal-x bal-y) (if x-to-y bal-y bal-x) (if x-to-y w-x w-y) (if x-to-y w-y w-x))))
      (if x-to-y
        (begin (var-set balance-x (+ bal-x amount-in)) (var-set balance-y (- bal-y amount-out)))
        (begin (var-set balance-y (+ bal-y amount-in)) (var-set balance-x (- bal-x amount-out)))
      )
      (try! (as-contract (contract-call? token-out transfer amount-out tx-sender tx-sender none)))
      (ok amount-out)
    )
  )
)

(define-public (add-liquidity (amount-x uint) (amount-y uint) (token-x-trait <sip-010-ft-trait>) (token-y-trait <sip-010-ft-trait>))
  (let ((current-balance-x (var-get balance-x))
        (current-balance-y (var-get balance-y)))
    (asserts! (is-eq (contract-of token-x-trait) (var-get token-x)) ERR_INVALID_TOKEN)
    (asserts! (is-eq (contract-of token-y-trait) (var-get token-y)) ERR_INVALID_TOKEN)
    (asserts! (and (> amount-x u0) (> amount-y u0)) ERR_INVALID_AMOUNTS)
    
    (try! (contract-call? token-x-trait transfer amount-x tx-sender (as-contract tx-sender) none))
    (try! (contract-call? token-y-trait transfer amount-y tx-sender (as-contract tx-sender) none))
    
    (var-set balance-x (+ current-balance-x amount-x))
    (var-set balance-y (+ current-balance-y amount-y))
    (ok u1)
  )
)

(define-public (remove-liquidity (lp-amount uint) (token-x-trait <sip-010-ft-trait>) (token-y-trait <sip-010-ft-trait>))
  (let (
    (amount-x (/ (* lp-amount (var-get balance-x)) u100000000))
    (amount-y (/ (* lp-amount (var-get balance-y)) u100000000))
  )
    (asserts! (is-eq (contract-of token-x-trait) (var-get token-x)) ERR_INVALID_TOKEN)
    (asserts! (is-eq (contract-of token-y-trait) (var-get token-y)) ERR_INVALID_TOKEN)
    
    (try! (as-contract (contract-call? token-x-trait transfer amount-x tx-sender tx-sender none)))
    (try! (as-contract (contract-call? token-y-trait transfer amount-y tx-sender tx-sender none)))
    
    (var-set balance-x (- (var-get balance-x) amount-x))
    (var-set balance-y (- (var-get balance-y) amount-y))
    (ok { amount0: amount-x, amount1: amount-y })
  )
)

(define-read-only (get-reserves)
  (ok { reserve0: (var-get balance-x), reserve1: (var-get balance-y) })
)

;; --- Private Helper Functions ---
(define-private (get-amount-out (amount-in uint) (balance-in uint) (balance-out uint) (weight-in uint) (weight-out uint))
  ;; Simplified Constant Product Logic
  (let ((denominator (+ balance-in amount-in)))
    (if (is-eq denominator u0)
      u0
      (/ (* balance-out amount-in) denominator)
    )
  )
)

(define-private (get-weights-from-params (params (buff 256)))
  (if (>= (len params) u8)
    (let (
      (w-x-buff (unwrap! (slice? params u0 u4) (err ERR_INVALID_WEIGHTS)))
      (w-y-buff (unwrap! (slice? params u4 u8) (err ERR_INVALID_WEIGHTS)))
    )
      (ok {
        weight-x: (unwrap! (buff-to-uint-be w-x-buff) (err ERR_INVALID_WEIGHTS)),
        weight-y: (unwrap! (buff-to-uint-be w-y-buff) (err ERR_INVALID_WEIGHTS))
      })
    )
    (err ERR_INVALID_WEIGHTS)
  )
)
