;; Conxian DEX Router - Securely routes trades across DEX pools.
;; Provides a user-facing interface for single-hop and multi-hop swaps.
;; Refactored for correctness and security.

;; --- Traits ---
(use-trait sip10-trait 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.sip-010-trait)

(define-trait pool-trait
  (
    (swap-exact-in (uint uint bool uint) (response (tuple (amount-out uint) (fee uint)) uint))
    (get-reserves () (response (tuple (reserve-a uint) (reserve-b uint)) uint))
    (get-token-a () (response principal uint))
    (get-token-b () (response principal uint))
  )
)

;; --- Constants ---
(define-constant ERR_UNAUTHORIZED (err u4000))
(define-constant ERR_INVALID_PATH (err u4002))
(define-constant ERR_INSUFFICIENT_OUTPUT (err u4003))
(define-constant ERR_DEADLINE_PASSED (err u4004))
(define-constant ERR_POOL_NOT_FOUND (err u4005))
(define-constant ERR_TRANSFER_FAILED (err u4006))
(define-constant ERR_RECURSION_DEPTH (err u4007))

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)
(define-data-var factory-address principal .dex-factory)

;; --- Private Functions ---

;; Recursively performs swaps along the specified path.
(define-private (swap-recursive (path (list 5 principal)) (amount-in uint) (min-amount-out uint) (deadline uint))
  (let ((token-in (unwrap-panic (element-at path u0)))
        (token-out (unwrap-panic (element-at path u1)))
        (factory (var-get factory-address)))
    
    (let ((pool-principal (unwrap! (contract-call? factory get-pool token-in token-out) ERR_POOL_NOT_FOUND)))
      (let ((token-a (unwrap! (contract-call? pool-principal get-token-a) ERR_POOL_NOT_FOUND)))
        (let ((x-to-y (is-eq token-in token-a)))

          ;; For intermediate hops, min-out is 0. For the final hop, it's the user-specified minimum.
          (let ((current-min-out (if (is-eq (len path) u2) min-amount-out u0)))

            ;; Execute the swap on the pool contract. The router contract itself holds the tokens.
            (let ((swap-result (unwrap! (as-contract (contract-call? pool-principal swap-exact-in amount-in current-min-out x-to-y deadline)) ERR_INSUFFICIENT_OUTPUT)))
              (let ((amount-out (get amount-out swap-result)))
                (if (is-eq (len path) u2)
                  ;; This was the last hop, return the final output amount.
                  (ok amount-out)
                  ;; More hops remain, recurse.
                  (swap-recursive (unwrap-panic (slice? path u1 u5)) amount-out min-amount-out deadline)
                )
              )
            )
          )
        )
      )
    )
  )
)

;; --- Public Functions ---

;; The main entry point for swaps.
(define-public (swap-exact-tokens-for-tokens (amount-in uint) (min-amount-out uint) (path (list 5 principal)) (deadline uint))
  (begin
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)

    ;; Transfer the input tokens from the user to this router contract.
    (let ((token-in-trait (unwrap-panic (element-at path u0))))
      (try! (contract-call? token-in-trait transfer amount-in tx-sender (as-contract tx-sender) none))
    )

    ;; Execute the recursive swap.
    (let ((final-amount-out (try! (swap-recursive path amount-in min-amount-out deadline))))
      
      ;; Transfer the final output tokens from this router contract to the user.
      (let ((token-out-trait (unwrap-panic (element-at path (- (len path) u1)))))
        (try! (as-contract (contract-call? token-out-trait transfer final-amount-out (as-contract tx-sender) tx-sender none)))
      )

      (ok final-amount-out)
    )
  )
)

;; --- Admin Functions ---

(define-public (set-factory (new-factory principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set factory-address new-factory)
    (ok true)
  )
)
