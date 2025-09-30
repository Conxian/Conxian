;; migration-manager.clar
;; Manages contract migrations and upgrades

(use-trait sip-010-ft-trait .all-traits.sip-010-ft-trait)
(use-trait migration-manager-trait .all-traits.migration-manager-trait)

(impl-trait migration-manager-trait)

;; ===== Constants =====
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_MIGRATION_ALREADY_STARTED (err u101))
(define-constant ERR_MIGRATION_NOT_ACTIVE (err u102))
(define-constant ERR_INVALID_MIGRATION_STATE (err u103))

;; ===== Data Variables =====
(define-data-var contract-owner principal tx-sender)
(define-data-var migration-active bool false)
(define-data-var current-migration-id uint u0)

;; migration-plans: {migration-id: uint} {old-contract: principal, new-contract: principal, status: (string-ascii 32)}
(define-map migration-plans {
  migration-id: uint
} {
  old-contract: principal,
  new-contract: principal,
  status: (string-ascii 32) ;; "pending", "in-progress", "completed", "rolled-back"
})

;; ===== Public Functions =====

(define-public (start-migration (old-contract principal) (new-contract principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (var-get migration-active)) ERR_MIGRATION_ALREADY_STARTED)

    (var-set migration-active true)
    (var-set current-migration-id (+ (var-get current-migration-id) u1))

    (map-set migration-plans {migration-id: (var-get current-migration-id)} {
      old-contract: old-contract,
      new-contract: new-contract,
      status: "in-progress"
    })
    (ok (var-get current-migration-id))
  )
)

(define-public (complete-migration (migration-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (var-get migration-active) ERR_MIGRATION_NOT_ACTIVE)
    (asserts! (is-eq migration-id (var-get current-migration-id)) ERR_INVALID_MIGRATION_STATE)

    (map-set migration-plans {migration-id: migration-id} (merge (unwrap-panic (map-get? migration-plans {migration-id: migration-id})) {status: "completed"}))
    (var-set migration-active false)
    (ok true)
  )
)

(define-public (rollback-migration (migration-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (var-get migration-active) ERR_MIGRATION_NOT_ACTIVE)
    (asserts! (is-eq migration-id (var-get current-migration-id)) ERR_INVALID_MIGRATION_STATE)

    (map-set migration-plans {migration-id: migration-id} (merge (unwrap-panic (map-get? migration-plans {migration-id: migration-id})) {status: "rolled-back"}))
    (var-set migration-active false)
    (ok true)
  )
)

;; ===== Read-Only Functions =====

(define-read-only (get-migration-status (migration-id uint))
  (ok (map-get? migration-plans {migration-id: migration-id}))
)

(define-read-only (is-migration-active)
  (ok (var-get migration-active))
)

(define-read-only (get-current-migration-id)
  (ok (var-get current-migration-id))
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
