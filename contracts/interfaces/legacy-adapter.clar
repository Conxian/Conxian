(use-trait legacy-adapter .all-traits.legacy-adapter-trait)
(use-trait legacy-adapter-trait .all-traits.legacy-adapter-trait)
;; legacy-adapter.clar
;; Provides backward compatibility for legacy contracts and interfaces

(impl-trait .all-traits.legacy-adapter-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LEGACY_CONTRACT_NOT_FOUND (err u101))
(define-constant ERR_UNSUPPORTED_LEGACY_FUNCTION (err u102))

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)

;; legacy-contract-map: {legacy-name: (string-ascii 64)} {contract-address: principal}
(define-map legacy-contract-map {
  legacy-name: (string-ascii 64)
} {
  contract-address: principal
})

;; ===== Public Functions =====

(define-public (register-legacy-contract (legacy-name (string-ascii 64)) (contract-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set legacy-contract-map {legacy-name: legacy-name} {contract-address: contract-address})
    (ok true)
  )
)

(define-public (deregister-legacy-contract (legacy-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-delete legacy-contract-map {legacy-name: legacy-name})
    (ok true)
  )
)

(define-public (call-legacy-function (legacy-name (string-ascii 64)) (function-name (string-ascii 64)) (args (list 10 (buff 128))))
  (begin
    (asserts! (is-some (map-get? legacy-contract-map {legacy-name: legacy-name})) ERR_LEGACY_CONTRACT_NOT_FOUND)
    ;; This is a placeholder for actual dynamic contract calls to legacy contracts.
    ;; In a real scenario, this would involve `contract-call?` with the legacy contract and function-name.
    (ok true)
  )
)

;; ===== Read-Only Functions =====

(define-read-only (get-legacy-contract (legacy-name (string-ascii 64)))
  (ok (map-get? legacy-contract-map {legacy-name: legacy-name}))
)

(define-read-only (get-contract-owner)
  (ok (var-get contract-owner))
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

