;; Access Control Contract
;; Implements the access control functionality specified in AIP-7

(use-trait access-control 'traits.access-control-trait.access-control-trait)
(use-trait ownable 'traits.ownable-trait.ownable-trait)
(use-trait std-constants 'traits.standard-constants-trait.standard-constants-trait)

;; Roles
(define-constant ROLE_ADMIN 0x41444d494e)        ;; 'ADMIN' in hex
(define-constant ROLE_OPERATOR 0x4f50455241544f52)  ;; 'OPERATOR' in hex
(define-constant ROLE_EMERGENCY 0x454d455247454e4359)  ;; 'EMERGENCY' in hex

;; Data storage
(define-data-var owner principal tx-sender)
(define-data-var roles (map principal (list (string-ascii 32))) (map))
(define-data-var paused bool false)
(define-data-var proposals (map uint {
  id: uint,
  proposer: principal,
  target: principal,
  value: uint,
  data: (buff 1024),
  description: (string-utf8 500),
  approvals: (list principal),
  executed: bool
}) (map))

(define-constant PROPOSAL_THRESHOLD u2)  ;; Number of approvals required

(impl-trait 'traits.access-control-trait.access-control-trait)

;; ===== Role Management =====

(define-public (has-role (who principal) (role (string-ascii 32)))
  (let ((user-roles (unwrap! (map-get? roles who) (list))))
    (ok (contains? role user-roles))
  )
)

(define-public (grant-role (who principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-admin tx-sender) (err u1001))  ;; ERR_NOT_ADMIN
    
    (let ((user-roles (unwrap! (map-get? roles who) (list))))
      (if (not (contains? role user-roles))
        (map-set roles who (append user-roles (list role)))
      )
    )
    
    (print {
      event: "role-granted",
      role: role,
      account: who,
      sender: tx-sender
    })
    
    (ok true)
  )
)

(define-public (revoke-role (who principal) (role (string-ascii 32)))
  (begin
    (asserts! (is-admin tx-sender) (err u1001))  ;; ERR_NOT_ADMIN
    
    (let ((user-roles (unwrap! (map-get? roles who) (list))))
      (if (contains? role user-roles)
        (map-set roles who (filter (
          lambda ((r (string-ascii 32))) (not (is-eq r role))
        ) user-roles))
      )
    )
    
    (print {
      event: "role-revoked",
      role: role,
      account: who
    })
    
    (ok true)
  )
)

;; ===== Access Control =====

(define-public (only-role (role (string-ascii 32)))
  (let ((has-role (unwrap! (contract-call? .self has-role tx-sender role) false)))
    (if has-role
      (ok true)
      (err u1002)  ;; ERR_MISSING_ROLE
    )
  )
)

(define-public (only-roles (required-roles (list (string-ascii 32))))
  (let ((has-any-role (any (
    lambda ((role (string-ascii 32))) 
    (unwrap! (contract-call? .self has-role tx-sender role) false)
  ) required-roles)))
    (if has-any-role
      (ok true)
      (err u1002)  ;; ERR_MISSING_ROLE
    )
  )
)

;; ===== Emergency Controls =====

(define-public (pause)
  (begin
    (asserts! (unwrap! (contract-call? .self has-role tx-sender ROLE_EMERGENCY) false) (err u1003))  ;; ERR_NOT_EMERGENCY_ADMIN
    (var-set paused true)
    (print {event: "paused", by: tx-sender})
    (ok true)
  )
)

(define-public (unpause)
  (begin
    (asserts! (unwrap! (contract-call? .self has-role tx-sender ROLE_EMERGENCY) false) (err u1003))  ;; ERR_NOT_EMERGENCY_ADMIN
    (var-set paused false)
    (print {event: "unpaused", by: tx-sender})
    (ok true)
  )
)

(define-read-only (paused)
  (ok (var-get paused))
)

;; ===== Multi-sig Operations =====

(define-public (propose (target principal) (value uint) (data (buff 1024)) (description (string-utf8 500)))
  (let (
      (proposal-id (+ (unwrap! (var-get last-proposal-id) u0) u1))
      (proposal {
        id: proposal-id,
        proposer: tx-sender,
        target: target,
        value: value,
        data: data,
        description: description,
        approvals: (list tx-sender),
        executed: false
      })
    )
    (map-set proposals proposal-id proposal)
    (var-set last-proposal-id proposal-id)
    
    (print {
      event: "proposal-created",
      id: proposal-id,
      proposer: tx-sender,
      description: description
    })
    
    (ok proposal-id)
  )
)

(define-public (approve (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1004))))  ;; ERR_PROPOSAL_NOT_FOUND
    (asserts! (not (contains? tx-sender (get approvals proposal))) (err u1005))  ;; ERR_ALREADY_APPROVED
    
    (map-set proposals proposal-id (merge proposal {
      approvals: (append (get approvals proposal) (list tx-sender))
    }))
    
    (print {
      event: "proposal-approved",
      id: proposal-id,
      approver: tx-sender,
      approvals: (len (get approvals proposal))
    })
    
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u1004))))  ;; ERR_PROPOSAL_NOT_FOUND
    (asserts! (not (get executed proposal)) (err u1006))  ;; ERR_ALREADY_EXECUTED
    (asserts! (>= (len (get approvals proposal)) PROPOSAL_THRESHOLD) (err u1007))  ;; ERR_NOT_ENOUGH_APPROVALS
    
    ;; Mark as executed before execution to prevent reentrancy
    (map-set proposals proposal-id (merge proposal {executed: true}))
    
    ;; Execute the proposal
    (let ((result (contract-call? 
      (get target proposal)
      (get value proposal)
      (get data proposal)
    )))
      (match result
        (ok success) (begin
          (print {
            event: "proposal-executed",
            id: proposal-id,
            executor: tx-sender
          })
          (ok success)
        )
        (err error) (begin
          ;; Revert execution status on failure
          (map-set proposals proposal-id (merge proposal {executed: false}))
          (err error)
        )
      )
    )
  )
)

;; ===== Helper Functions =====

(define-private (is-admin (who principal))
  (or
    (is-eq who (var-get owner))
    (unwrap! (contract-call? .self has-role who ROLE_ADMIN) false)
  )
)

(define-private (contains? (needle (string-ascii 32)) (haystack (list (string-ascii 32))))
  (any (lambda ((item (string-ascii 32))) (is-eq item needle)) haystack)
)



