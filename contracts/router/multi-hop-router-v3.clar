;; multi-hop-router-v3.clar
;; Conxian Multi-Hop Routing Engine V3

;; SIP-010: Fungible Token Standard
use-trait ft-trait 'SP3FBR2AGK5H9QBDV3K5SK2TKAH8Q6H5X2F8X5PJK.sip-010-trait-ft-standard.sip-010-trait'
(use-trait circuit-breaker-trait .circuit-breaker-trait.circuit-breaker-trait)

(define-trait dex-factory-v2-trait
  (
    (get-pool (principal principal) (response (optional principal) uint))
  )
)

(define-trait pool-trait
  (
    (swap-trait-adapter (trait_reference <ft-trait>) (trait_reference <ft-trait>) uint uint principal) (response uint uint))
  )
)

;; Error codes
(define-public err-unauthorized (err u100))
(define-public err-invalid-pair (err u101))
(define-public err-invalid-amount (err u102))
(define-public err-no-route-found (err u103))
(define-public err-swap-failed (err u104))
(define-public err-slippage-exceeded (err u105))
(define-public err-circuit-open (err u106))

(define-data-var circuit-breaker principal .circuit-breaker)
(define-data-var admin principal tx-sender)

;; Data maps
(define-map routes
  {
    token-in: principal,
    token-out: principal,
    amount-in: uint
  }
  {
    path: (list 10 {pool: principal, token-in: principal, token-out: principal}),
    amount-out: uint
  }
)

(define-private (check-circuit-breaker)
  (contract-call? (var-get circuit-breaker) is-circuit-open)
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) err-unauthorized)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (set-circuit-breaker (new-circuit-breaker principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) err-unauthorized)
    (var-set circuit-breaker new-circuit-breaker)
    (ok true)
  )
)

;; @desc Finds the optimal route for a token swap.
;; @param token-in (principal) The principal of the input token.
;; @param token-out (principal) The principal of the output token.
;; @param amount-in (uint) The amount of the input token.
;; @returns (response {path: (list 10 {pool: principal, token-in: principal, token-out: principal}), amount-out: uint} (err uint)) The optimal route and output amount, or an error.
(define-read-only (find-best-route (token-in principal) (token-out principal) (amount-in uint))
  (let ((factory <dex-factory-v2-trait> 'SP3FBR2AGK5H9QBDV3K5SK2TKAH8Q6H5X2F8X5PJK.dex-factory-v2))
    (match (contract-call? factory get-pool token-in token-out)
      (ok (some pool)) (ok {path: (list {pool: pool, token-in: token-in, token-out: token-out}), amount-out: u0})
      (ok none) (err err-no-route-found)
      (err e) (err e)
    )
  )
)

;; @desc Executes a token swap along a given route.
;; @param path (list 10 {pool: principal, token-in: principal, token-out: principal}) The path to execute the swap.
;; @param amount-in (uint) The amount of the input token.
;; @param min-amount-out (uint) The minimum acceptable amount of the output token.
;; @returns (response uint (err uint)) The actual amount of the output token received, or an error.
(define-public (execute-swap (path (list 10 {pool: principal, token-in: principal, token-out: principal})) (amount-in uint) (min-amount-out uint))
  (begin
    (asserts! (not (try! (check-circuit-breaker))) err-circuit-open)
    (fold
      (lambda (hop prev-amount-out)
        (let ((pool <pool-trait> (get pool hop))
              (token-in-trait (contract-of (get token-in hop)))
              (token-out-trait (contract-of (get token-out hop))))
          (unwrap-panic (contract-call? pool swap-trait-adapter token-in-trait token-out-trait prev-amount-out min-amount-out tx-sender))
        )
      )
      path
      amount-in
    )
  )
)
