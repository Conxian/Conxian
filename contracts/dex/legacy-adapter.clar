;; legacy-adapter.clar
;; This contract provides a backward-compatible interface for older versions of the protocol.

(define-constant ERR_UNAUTHORIZED (err u9200))
(define-constant ERR_ADAPTER_DEPRECATED (err u9201))
(define-constant ERR_TOKEN_NOT_MAPPED (err u9202))

(define-data-var contract-owner principal tx-sender)
(define-data-var new-dex-contract principal .dex-v2)

(define-map token-map principal principal)

(define-public (set-token-mapping (old-token principal) (new-token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set token-map old-token new-token)
    (ok true)
  )
)

(define-public (swap (token-in principal) (token-out principal) (amount-in uint))
  (let ((new-token-in (unwrap! (map-get? token-map token-in) (err ERR_TOKEN_NOT_MAPPED)))
        (new-token-out (unwrap! (map-get? token-map token-out) (err ERR_TOKEN_NOT_MAPPED))))
    (print { message: "Legacy swap function called, forwarding to new DEX", token-in: new-token-in, token-out: new-token-out, amount-in: amount-in })
    (contract-call? (var-get new-dex-contract) swap new-token-in new-token-out amount-in)
  )
)

(define-public (add-liquidity (token-a principal) (token-b principal) (amount-a uint) (amount-b uint))
  (let ((new-token-a (unwrap! (map-get? token-map token-a) (err ERR_TOKEN_NOT_MAPPED)))
        (new-token-b (unwrap! (map-get? token-map token-b) (err ERR_TOKEN_NOT_MAPPED))))
    (print { message: "Legacy add-liquidity function called, forwarding to new DEX", token-a: new-token-a, token-b: new-token-b, amount-a: amount-a, amount-b: amount-b })
    (contract-call? (var-get new-dex-contract) add-liquidity new-token-a new-token-b amount-a amount-b)
  )
)

(define-public (remove-liquidity (token-a principal) (token-b principal) (percentage uint))
  (let ((new-token-a (unwrap! (map-get? token-map token-a) (err ERR_TOKEN_NOT_MAPPED)))
        (new-token-b (unwrap! (map-get? token-map token-b) (err ERR_TOKEN_NOT_MAPPED))))
    (print { message: "Legacy remove-liquidity function called, forwarding to new DEX", token-a: new-token-a, token-b: new-token-b, percentage: percentage })
    (contract-call? (var-get new-dex-contract) remove-liquidity new-token-a new-token-b percentage)
  )
)