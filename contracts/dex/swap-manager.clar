;;
;; @title Swap Manager
;; @author Conxian Protocol
;; @desc This contract manages the execution of swaps.
;;

(use-trait pool-trait .defi-traits.pool-trait)
(use-trait sip-010-trait .sip-standards.sip-010-ft-trait)

(define-constant ERR_SLIPPAGE (err u4002))

(define-data-var contract-owner principal tx-sender)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u100))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

(define-public (swap-direct
    (amount-in uint)
    (min-amount-out uint)
    (pool <pool-trait>)
    (token-in <sip-010-trait>)
    (token-out <sip-010-trait>)
  )
  (let ((amount-out (try! (contract-call? pool swap amount-in token-in token-out))))
    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE)
    (ok amount-out)
  )
)

(define-public (swap-2-hop
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token-in <sip-010-trait>)
    (token-base <sip-010-trait>)
    (pool2 <pool-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
      (amt1 (try! (contract-call? pool1 swap amount-in token-in token-base)))
      (amt2 (try! (contract-call? pool2 swap amt1 token-base token-out)))
    )
    (asserts! (>= amt2 min-amount-out) ERR_SLIPPAGE)
    (ok amt2)
  )
)

(define-public (swap-3-hop
    (amount-in uint)
    (min-amount-out uint)
    (pool1 <pool-trait>)
    (token-in <sip-010-trait>)
    (token-base1 <sip-010-trait>)
    (pool2 <pool-trait>)
    (token-base2 <sip-010-trait>)
    (pool3 <pool-trait>)
    (token-out <sip-010-trait>)
  )
  (let (
      (amt1 (try! (contract-call? pool1 swap amount-in token-in token-base1)))
      (amt2 (try! (contract-call? pool2 swap amt1 token-base1 token-base2)))
      (amt3 (try! (contract-call? pool3 swap amt2 token-base2 token-out)))
    )
    (asserts! (>= amt3 min-amount-out) ERR_SLIPPAGE)
    (ok amt3)
  )
)
