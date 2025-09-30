;; Weighted Swap Pool
;; This contract implements a weighted swap pool for assets with different weights.

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait pool-creation-trait .all-traits.pool-creation-trait)

(impl-trait .all-traits.pool-creation-trait)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u1003))
(define-constant ERR_INVALID_WEIGHTS (err u4001))
(define-constant ERR_INVALID_AMOUNTS (err u4002))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var token-x-trait principal .sip-010-ft-trait)
(define-data-var token-y-trait principal .sip-010-ft-trait)
(define-data-var balance-x uint u0)
(define-data-var balance-y uint u0)
(define-data-var weight-x uint u50000000) ;; 50%
(define-data-var weight-y uint u50000000) ;; 50%

;; --- Public Functions ---

(define-public (create-instance (token-a principal) (token-b principal) (params (buff 256)))
  (begin
    (var-set token-x-trait token-a)
    (var-set token-y-trait token-b)
    (let ((weights (unwrap! (get-weights-from-params params) (err ERR_INVALID_WEIGHTS))))
      (var-set weight-x (get weight-x weights))
      (var-set weight-y (get weight-y weights))
    )
    (ok (as-contract tx-sender))
  )
)

(define-public (add-liquidity (amount-x uint) (amount-y uint))
  (let ((current-balance-x (var-get balance-x))
        (current-balance-y (var-get balance-y)))
    (asserts! (and (> amount-x u0) (> amount-y u0)) ERR_INVALID_AMOUNTS)
    
    (try! (contract-call? (var-get token-x-trait) transfer amount-x tx-sender (as-contract tx-sender) none))
    (try! (contract-call? (var-get token-y-trait) transfer amount-y tx-sender (as-contract tx-sender) none))
    
    (var-set balance-x (+ current-balance-x amount-x))
    (var-set balance-y (+ current-balance-y amount-y))
    
    (ok true)
  )
)

(define-public (swap-x-for-y (amount-in uint))
  (let ((current-balance-x (var-get balance-x))
        (current-balance-y (var-get balance-y))
        (weight-x (var-get weight-x))
        (weight-y (var-get weight-y)))
    
    (try! (contract-call? (var-get token-x-trait) transfer amount-in tx-sender (as-contract tx-sender) none))
    
    (let* ((new-balance-x (+ current-balance-x amount-in))
           (amount-out (get-amount-out amount-in current-balance-x current-balance-y weight-x weight-y)))
      
      (var-set balance-x new-balance-x)
      (var-set balance-y (- current-balance-y amount-out))
      
      (try! (as-contract (contract-call? (var-get token-y-trait) transfer amount-out tx-sender tx-sender none)))
      
      (ok amount-out)
    )
  )
)

;; --- Private Helper Functions ---

(define-private (get-amount-out (amount-in uint) (balance-in uint) (balance-out uint) (weight-in uint) (weight-out uint))
  ;; out = balanceOut * (1 - (balanceIn / (balanceIn + amountIn))^(weightIn/weightOut))
  (let ((ratio (/ (* balance-in u100000000) (+ balance-in amount-in))))
    (let ((power (pow-approx ratio (/ (* weight-in u100000000) weight-out))))
      (* balance-out (- u100000000 power))
    )
  )
)

(define-private (get-weights-from-params (params (buff 256)))
  (if (>= (len params) u8)
    (ok { 
      weight-x: (buff-to-uint-be (slice params 0 4)),
      weight-y: (buff-to-uint-be (slice params 4 8))
    })
    (err ERR_INVALID_WEIGHTS)
  )
)

(define-private (pow-approx (base uint) (exp uint))
  ;; Simplified power function using integer math
  (if (is-eq exp u100000000) base
    (if (is-eq exp u0) u100000000
      (if (< exp u100000000)
        (/ (* base exp) u100000000)
        (* base (/ exp u100000000))
      )
    )
  )
)