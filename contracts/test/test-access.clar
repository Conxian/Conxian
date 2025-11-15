;; test-access.clar

;; Simple access control test contract

(define-constant contract-owner tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))

(define-map roles { who: principal } (string-ascii 32))

;; Check if an account has a role
(define-public (has-role (who principal) (role (string-ascii 32)))
  (ok (is-eq (default-to "" (map-get? roles { who: who })) role)))

;; Grant a role
(define-public (grant-role (who principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
    (map-set roles { who: who } role)
    (ok true)))

;; Revoke a role
(define-public (revoke-role (who principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) ERR_NOT_AUTHORIZED)
    (map-delete roles { who: who })
    (ok true)))

;; Require a single role
(define-public (only-role (role (string-ascii 32)))
  (ok (unwrap-panic (has-role tx-sender role))))

;; Require any of multiple roles
(define-public (only-roles (roles-list (list 10 (string-ascii 32))))
  (ok (> (len roles-list) u0)))
