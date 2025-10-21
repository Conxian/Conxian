;; Access Control Interface
;; Defines the standard interface for access control functionality

;; Role management trait
(define-trait access-control-trait
  (
    ;; Role checking
    (has-role (principal (string-ascii 32)) (response bool uint))
    
    ;; Role management
    (grant-role (principal (string-ascii 32)) (response bool uint))
    (revoke-role (principal (string-ascii 32)) (response bool uint))
    
    ;; Access control checks
    (only-role ((string-ascii 32)) (response bool uint))
    (only-roles ((list 10 (string-ascii 32))) (response bool uint))
    
    ;; Emergency controls
    (pause () (response bool uint))
    (unpause () (response bool uint))
    (is-paused () (response bool uint))
    
    ;; Multi-sig operations
    (propose (principal uint (buff 1024) (string-utf8 500)) (response uint uint))
    (approve (uint) (response bool uint))
    (execute-proposal (uint) (response bool uint))
  )
)

;; Constants for standard roles
(define-constant ROLE_ADMIN 0x41444d494e) ;; ADMIN in hex
(define-constant ROLE_OPERATOR 0x4f50455241544f52) ;; OPERATOR in hex
(define-constant ROLE_EMERGENCY 0x454d455247454e4359) ;; EMERGENCY in hex

;; Error codes
(define-constant ERR_NOT_ADMIN (err u1001))
(define-constant ERR_MISSING_ROLE (err u1002))
(define-constant ERR_NOT_EMERGENCY_ADMIN (err u1003))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u1004))
(define-constant ERR_ALREADY_APPROVED (err u1005))
(define-constant ERR_ALREADY_EXECUTED (err u1006))
(define-constant ERR_NOT_ENOUGH_APPROVALS (err u1007))
(define-constant ERR_DELAY_NOT_PASSED (err u1008))
(define-constant ERR_CIRCUIT_OPEN (err u5000))