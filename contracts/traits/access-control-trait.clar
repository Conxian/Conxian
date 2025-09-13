;; Access Control Trait - Role-based access control interface
;; This file is now DEPRECATED - Use standard-traits.clar instead
;; Keeping for backward compatibility

(define-trait access-control-trait
  (
    ;; Role Management
    (has-role (principal (string-ascii 32)) (response bool uint))
    (grant-role (principal (string-ascii 32)) (response bool uint))
    (revoke-role (principal (string-ascii 32)) (response bool uint))
    
    ;; Role-based Access Control
    (only-role ((string-ascii 32)) (response bool uint))
    (only-roles ((list 10 (string-ascii 32))) (response bool uint))
    
    ;; Time-locked Operations
    (schedule ((string-ascii 32) (optional (string-utf8 500)) uint) (response uint uint))
    (execute (uint) (response bool uint))
    (cancel (uint) (response bool uint))
    
    ;; Emergency Controls
    (pause () (response bool uint))
    (unpause () (response bool uint))
    (is-paused () (response bool uint))
    
    ;; Multi-sig Operations
    (propose ((string-ascii 32) (string-utf8 500)) (response uint uint))
    (approve (uint) (response bool uint))
    (execute-proposal (uint) (response bool uint))
    
    ;; Events
    (role-granted ((string-ascii 32) principal principal) (response bool uint))
    (role-revoked ((string-ascii 32) principal) (response bool uint))
    (operation-scheduled (uint (string-ascii 32) uint) (response bool uint))
    (operation-executed (uint) (response bool uint))
    (paused-changed (bool) (response bool uint))
  )
)

;; Re-export standard constants for backward compatibility
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_INITIALIZED (err u101))
(define-constant ERR_NOT_INITIALIZED (err u102))
(define-constant ROLE_ADMIN 0x41444d494e)        ;; ADMIN in hex
(define-constant ROLE_OPERATOR 0x4f50455241544f52)  ;; OPERATOR in hex
(define-constant ROLE_EMERGENCY 0x454d455247454e4359)  ;; EMERGENCY in hex

;; Implementation of standard roles
(define-public (is-admin (who principal) (role (string-ascii 32)))
  (ok (or 
    (is-eq role ROLE_ADMIN)
    (is-eq (var-get owner) who)
  ))
)

(define-public (is-emergency-admin (who principal) (role (string-ascii 32)))
  (ok (is-eq role ROLE_EMERGENCY))
)





