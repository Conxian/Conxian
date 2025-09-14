;; Access Control Trait - Role-based access control interface
;; Alias for standard access-control-trait in standard-traits.clar
;; This file is maintained for backward compatibility

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
    
    ;; Pausable Operations
    (pause () (response bool uint))
    (unpause () (response bool uint))
    
    ;; Emergency Operations
    (emergency-withdraw (principal uint) (response bool uint))
    (emergency-halt () (response bool uint))
    
    ;; Multi-sig Operations
    (submit-proposal ((string-ascii 32) (string-utf8 500) (optional (buff 34))) (response uint uint))
    (approve-proposal (uint) (response bool uint))
    (revoke-approval (uint) (response bool uint))
    (execute-proposal (uint) (response bool uint))
    
    ;; Role-based Events
    (role-granted ((string-ascii 32) principal principal) (response bool uint))
    (role-revoked ((string-ascii 32) principal principal) (response bool uint))
    
    ;; System Events
    (paused (principal) (response bool uint))
    (unpaused (principal) (response bool uint))
    
    ;; Governance Events
    (proposal-created (uint principal (string-ascii 32) (string-utf8 500) (optional (buff 34))) (response bool uint))
    (proposal-approved (uint principal) (response bool uint))
    (proposal-revoked (uint principal) (response bool uint))
    (proposal-executed (uint principal) (response bool uint))
    
    ;; Emergency Events
    (emergency-withdrawn (principal principal uint) (response bool uint))
    (emergency-halted (principal) (response bool uint))
  )
)

;; Re-export standard constants for backward compatibility
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ALREADY_INITIALIZED (err u101))
(define-constant ERR_NOT_INITIALIZED (err u102))
(define-constant ROLE_ADMIN 0x41444d494e)        ;; ADMIN in hex
(define-constant ROLE_OPERATOR 0x4f50455241544f52)  ;; OPERATOR in hex
(define-constant ROLE_EMERGENCY 0x454d455247454e4359)  ;; EMERGENCY in hex

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; Implementation of standard roles
(define-public (is-admin (who principal) (role (buff 5)))
  (ok (or 
    (is-eq role ROLE_ADMIN)
    (is-eq (var-get contract-owner) who)
  ))
)

(define-public (is-emergency-admin (who principal) (role (buff 5)))
  (ok (is-eq role ROLE_EMERGENCY))
)





