(use-trait asset-vault .all-traits.asset-vault-trait)
(use-trait asset-vault-trait .all-traits.asset-vault-trait)
(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)

;; Asset Vault Contract
;; Implements a simple asset vault for the Conxian protocol
(impl-trait .all-traits.asset-vault-trait)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-TOKEN (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))
(define-constant ERR-VAULT-PAUSED (err u104))
(define-constant ERR-ZERO-AMOUNT (err u105))
(define-constant ERR-UNEXPECTED-ERROR (err u106))

(define-data-var contract-owner principal tx-sender)
(define-data-var paused bool false)

(define-map allowed-tokens principal bool)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (toggle-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set paused (not (var-get paused))))
  )
)

(define-public (add-allowed-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set allowed-tokens token true)
    (ok true)
  )
)

(define-public (remove-allowed-token (token principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-delete allowed-tokens token)
    (ok true)
  )
)

(define-public (deposit (token <sip-010-ft-trait>) (amount uint))
  (begin
    (asserts! (not (var-get paused)) ERR-VAULT-PAUSED)
    (asserts! (is-allowed-token (contract-of token)) ERR-INVALID-TOKEN)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    (ok true)
  )
)

(define-public (withdraw (token <sip-010-ft-trait>) (amount uint))
  (let (
    (token-principal (contract-of token))
  )
    (asserts! (not (var-get paused)) ERR-VAULT-PAUSED)
    (asserts! (is-allowed-token token-principal) ERR-INVALID-TOKEN)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= (unwrap-panic (contract-call? token get-balance (as-contract tx-sender))) amount) ERR-INSUFFICIENT-BALANCE)
    (try! (as-contract (contract-call? token transfer amount tx-sender tx-sender none)))
    (ok true)
  )
)

(define-read-only (get-balance (token <sip-010-ft-trait>) (owner principal))
  (contract-call? token get-balance owner)
)

(define-read-only (is-allowed-token (token principal))
  (default-to false (map-get? allowed-tokens token))
)

