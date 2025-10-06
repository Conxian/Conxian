;; test-access.clar
;; Test contract to verify access control trait resolution

(use-trait access-control-trait .access-control-trait.access-control-trait)

(define-constant contract-owner tx-sender)
(define-constant ERR_NOT_AUTHORIZED u100)

(define-map roles principal (string-ascii 32))

;; Implement the access control trait
(define-public (has-role (who principal) (role (string-ascii 32)))
  (ok (is-eq (default-to "" (map-get? roles { who: who })) role))
)

(define-public (grant-role (who principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR_NOT_AUTHORIZED))
    (map-set roles { who: who } role)
    (ok true)
  )
)

(define-public (revoke-role (who principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err ERR_NOT_AUTHORIZED))
    (map-delete roles { who: who })
    (ok true)
  )
)

(define-public (only-role (role (string-ascii 32)))
  (match (contract-call? .access-control-trait has-role tx-sender role)
    has-role (ok has-role)
    error (err ERR_NOT_AUTHORIZED)
  )
)

(define-public (only-roles (roles-list (list 10 (string-ascii 32))))
  (let ((has-any-role 
    (filter not (map 
      (lambda ((role (string-ascii 32))) 
        (is-ok (contract-call? .access-control-trait has-role tx-sender role))
      ) 
      roles-list
    ))
  ))
  (ok (not (is-eq (len has-any-role) u0)))
  )
)

