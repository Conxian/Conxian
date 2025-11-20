;; migration-manager.clar
;; Manages the migration from the old DEX to the new one.

(define-constant ERR_UNAUTHORIZED (err u15000))
(define-constant ERR_MIGRATION_NOT_STARTED (err u15001))
(define-constant ERR_MIGRATION_ALREADY_STARTED (err u15002))
(define-constant ERR_MIGRATION_COMPLETE (err u15003))

(define-data-var migration-status uint u0) ;; 0: not started, 1: in progress, 2: complete
(define-data-var admin principal tx-sender)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)

(define-public (start-migration)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get migration-status) u0) ERR_MIGRATION_ALREADY_STARTED)
    (var-set migration-status u1)
    (ok true)
  )
)

(define-public (complete-migration)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (var-get migration-status) u1) ERR_MIGRATION_NOT_STARTED)
    (var-set migration-status u2)
    (ok true)
  )
)

(define-read-only (get-migration-status)
  (ok (var-get migration-status))
)
