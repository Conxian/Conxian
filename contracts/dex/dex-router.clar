;; dex-router.clar
;; Conxian DEX Router - Routes trades across DEX pools
;; Non-custodial, immutable design

;; --- Traits ---
(use-trait sip010-trait .sip-010-trait)
(use-trait pool-trait .pool-trait)

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

;; --- Public Functions ---

;; Main entry point for token swaps
(define-public (swap-exact-tokens-for-tokens 
    (amount-in uint)
    (min-amount-out uint)
    (path (list 5 principal))
    (deadline uint))
  (begin
    (asserts! (>= (len path) u2) ERR_INVALID_PATH)
    (asserts! (<= block-height deadline) ERR_DEADLINE_PASSED)
    (let ((token-in (unwrap-panic (element-at path u0)))
          (token-out (unwrap-panic (element-at path u1))))
      ;; Transfer input tokens to router
      (try! (contract-call? token-in transfer amount-in tx-sender (as-contract tx-sender) none))
      ;; Perform initial swap
      (match (perform-single-swap token-in token-out amount-in (if (is-eq (len path) u2) min-amount-out u0) deadline)
        initial-amount-out
        (let ((final-amount (if (> (len path) u2)
                             (unwrap! (process-next-hop
                               (unwrap-panic (slice? path u1 u5))
                               initial-amount-out
                               min-amount-out
                               deadline)
                             ERR_RECURSION_DEPTH)
                             initial-amount-out)))
          ;; Transfer final output tokens to user
          (try! (as-contract (contract-call? token-out transfer final-amount (as-contract tx-sender) tx-sender none)))
          (ok final-amount))
        error error)))
  ))

;; Core swap logic for a single hop
(define-private (perform-single-swap
    (token-in principal)
    (token-out principal)
    (amount-in uint)
    (min-amount-out uint)
    (deadline uint))
  (let ((factory (var-get factory-address)))
    (let ((pool-principal (unwrap! (contract-call? factory get-pool token-in token-out) ERR_POOL_NOT_FOUND)))
      (let ((token-a (unwrap! (contract-call? pool-principal get-token-a) ERR_POOL_NOT_FOUND)))
        (let ((x-to-y (is-eq token-in token-a)))
          (let ((swap-result (unwrap! (as-contract (contract-call? pool-principal swap-exact-in amount-in min-amount-out x-to-y deadline)) ERR_INSUFFICIENT_OUTPUT)))
            (ok (get amount-out swap-result))))))))

;; Helper function for remaining hops
(define-private (process-next-hop
    (remaining-path (list 4 principal))
    (amount-in uint)
    (min-amount-out uint)
    (deadline uint))
  (if (< (len remaining-path) u2)
    (ok amount-in)
    (let ((token-in (unwrap-panic (element-at remaining-path u0)))
          (token-out (unwrap-panic (element-at remaining-path u1))))
      (let ((current-min-out (if (is-eq (len remaining-path) u2) min-amount-out u0)))
        (match (perform-single-swap token-in token-out amount-in current-min-out deadline)
          amount-out
          (if (> (len remaining-path) u2)
            (process-next-hop
              (unwrap-panic (slice? remaining-path u1 u4))
              amount-out
              min-amount-out
              deadline)
            (ok amount-out))
          error error)))))

;; --- Admin Functions ---
(define-public (set-factory (new-factory principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set factory-address new-factory)
    (ok true)))