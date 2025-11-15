;; rbac.clar - Role-Based Access Control

(define-constant ERR_UNAUTHORIZED (err u1000))
(define-constant ERR_ROLE_ALREADY_ASSIGNED (err u1001))
(define-constant ERR_ROLE_NOT_ASSIGNED (err u1002))

;; --- Data Maps ---
;; Maps a role to a principal that holds that role
(define-map roles { role-name: (string-ascii 32) } { authorized-principal: principal })

;; --- Data Variables ---
(define-data-var contract-owner principal tx-sender)

;; --- Private Functions ---
(define-private (is-contract-owner-p)
  (is-eq tx-sender (var-get contract-owner)))

;; --- Public Functions ---

;; @desc Initializes the RBAC contract by setting the initial contract owner.
;; @param initial-owner The principal to be set as the initial contract owner.
;; @returns (response bool uint) True if successful, or an error.
(define-public (initialize-rbac (initial-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (var-set contract-owner initial-owner)
    (ok true)
  )
)

;; @desc Assigns a role to a principal.
;; @param role-name The name of the role to assign.
;; @param authorized-principal The principal to assign the role to.
;; @returns (response bool uint) True if successful, or an error.
(define-public (assign-role (role-name (string-ascii 32)) (authorized-principal principal))
  (begin
    (asserts! (is-contract-owner-p) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? roles { role-name: role-name })) ERR_ROLE_ALREADY_ASSIGNED)
    (map-set roles { role-name: role-name } { authorized-principal: authorized-principal })
    (ok true)
  )
)

;; @desc Revokes a role from a principal.
;; @param role-name The name of the role to revoke.
;; @returns (response bool uint) True if successful, or an error.
(define-public (revoke-role (role-name (string-ascii 32)))
  (begin
    (asserts! (is-contract-owner-p) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? roles { role-name: role-name })) ERR_ROLE_NOT_ASSIGNED)
    (map-delete roles { role-name: role-name })
    (ok true)
  )
)

;; @desc Checks if the transaction sender has a specific role.
;; @param role-name The name of the role to check.
;; @returns (response bool uint) True if the sender has the role, or an error.
(define-read-only (has-role (role-name (string-ascii 32)))
  (ok (is-eq tx-sender (get authorized-principal (unwrap! (map-get? roles { role-name: role-name }) ERR_ROLE_NOT_ASSIGNED))))
)

;; @desc Returns the principal assigned to a specific role.
;; @param role-name The name of the role to query.
;; @returns (response (optional principal) uint) The principal if found, or none.
(define-read-only (get-role-principal (role-name (string-ascii 32)))
  (ok (map-get? roles { role-name: role-name })))

;; @desc Transfers the contract ownership to a new principal.
;; @param new-owner The principal to transfer ownership to.
;; @returns (response bool uint) True if successful, or an error.
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-contract-owner-p) ERR_UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
