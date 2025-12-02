;; mev-protector.clar
;; Implements MEV protection mechanisms for the Conxian DEX.

 

(define-trait multi-hop-router-trait
  ((execute-swap (routes (list 10 (tuple (pool principal) (token-in principal) (token-out principal)))) (amount-in uint) (min-amount-out uint)) (response uint uint))
)

(define-trait crypto-lib-trait
  ((sha256 (data (buff 512))) (response (buff 32) uint))
)

(define-trait serializer-lib-trait
  ((serialize-trade-details (details (tuple (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))) (nonce (buff 16))) (response (buff 512) uint))
)

(define-constant REVEAL_WINDOW u10)

(define-constant ERR_COMMITMENT_NOT_FOUND (err u3000))
(define-constant ERR_COMMITMENT_ALREADY_REVEALED (err u3001))
(define-constant ERR_INVALID_COMMITMENT (err u3002))
(define-constant ERR_REVEAL_WINDOW_EXPIRED (err u3003))

(define-map commitments { commitment-hash: (buff 32) } {
  sender: principal,
  block-height: uint
})

(define-public (commit (commitment-hash (buff 32)))
  (begin
    (map-set commitments { commitment-hash: commitment-hash } { sender: tx-sender, block-height: block-height })
    (ok true)
  )
)

(define-public (reveal (trade-details (tuple (token-in principal) (token-out principal) (amount-in uint) (min-amount-out uint))) (nonce (buff 16)))
  (let ((serialized-trade (unwrap-panic (contract-call? .serializer-lib serialize-trade-details trade-details nonce)))
        (commitment-hash (unwrap-panic (contract-call? .crypto-lib sha256 serialized-trade)))
        (commitment (unwrap! (map-get? commitments { commitment-hash: commitment-hash }) ERR_COMMITMENT_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get sender commitment)) ERR_INVALID_COMMITMENT)
    (asserts! (<= (- block-height (get block-height commitment)) REVEAL_WINDOW) ERR_REVEAL_WINDOW_EXPIRED)
    (map-delete commitments { commitment-hash: commitment-hash })
    (let ((router <multi-hop-router-trait> .multi-hop-router-v3))
      (contract-call? router execute-swap
        (list {pool: (unwrap-panic (unwrap-panic (contract-call? .dex-factory get-pool (get token-in trade-details) (get token-out trade-details)))) , token-in: (get token-in trade-details), token-out: (get token-out trade-details)})
        (get amount-in trade-details)
        (get min-amount-out trade-details)
      )
    )
  )
)
