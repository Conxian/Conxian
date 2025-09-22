;; multi-hop-router-v3.clar

(use-trait ft-trait .sip-010-ft-trait)
(use-trait circuit-breaker-trait .circuit-breaker-trait)

(define-constant ERR_UNAUTHORIZED (err u3000))
(define-constant ERR_INVALID_PATH (err u3001))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u3002))
(define-constant ERR_CIRCUIT_OPEN (err u3003))

(define-data-var contract-owner principal tx-sender)
(define-data-var circuit-breaker (optional principal) none)

(define-private (check-circuit-breaker)
  (match (var-get circuit-breaker)
    (cb (contract-call? cb is-tripped))
    (ok false)
  )
)

(define-public (set-circuit-breaker (cb principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set circuit-breaker (some cb))
        (ok true)
    )
)

(define-public (swap-exact-in (path (list 20 principal)) (amount-in uint) (min-amount-out (optional uint)) (recipient principal))
  (begin
    (try! (check-circuit-breaker))
    (let ((out (try! (fold (lambda (pair (val uint))
      (let ((token-in (get-x pair)) (token-out (get-y pair)))
        (contract-call? .dex swap-exact-in token-in token-out val (unwrap-panic (get-min-amount-out-for-pair token-in token-out))))
      )
    ) (to-pairs path) amount-in))))
      (match min-amount-out
        (min (asserts! (>= out min) ERR_INSUFFICIENT_OUTPUT))
        (ok true)
      )
      (ok out)
    )
  )
)

(define-private (to-pairs (path (list 20 principal))) 
    (map (lambda (i) {{x: (unwrap-panic (element-at path i)), y: (unwrap-panic (element-at path (+ i u1)))}}) (range u0 (- (len path) u1)))
)

(define-private (get-min-amount-out-for-pair (token-in principal) (token-out principal)) 
    (some u0)
)