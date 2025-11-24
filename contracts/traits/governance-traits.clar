;; Governance Traits

;; ===========================================
;; DAO TRAIT
;; ===========================================
(define-trait dao-trait
  (
    (get-voting-power (principal) (response uint uint))
    (propose ((string-utf8 500)) (response uint uint))
    (vote (uint bool uint) (response bool uint))
    (execute-proposal (uint) (response bool uint))
  )
)

;; ===========================================
;; PROPOSAL ENGINE TRAIT
;; ===========================================
(define-trait proposal-engine-trait
  (
    (create-proposal (principal (string-ascii 256) uint uint) (response uint uint))
    (get-proposal (uint) (response (optional {
      proposer: principal,
      start-block: uint,
      end-block: uint,
      votes-for: uint,
      votes-against: uint,
      executed: bool,
      details: (string-ascii 256)
    }) uint))
  )
)

;; ============================================
;; PROPOSAL TRAIT (Individual Proposal Interface)
;; ===========================================
(define-trait proposal-trait
  (
    (execute (principal) (response bool uint))
  )
)

;; ===========================================
;; GOVERNANCE TOKEN TRAIT
;; ===========================================
(define-trait governance-token-trait
  (
    (get-voting-power-at (principal uint) (response uint uint))
    (delegate (principal) (response bool uint))
    (has-voting-power (principal) (response bool uint))
    (get-total-supply () (response uint uint))
  )
)

;; ===========================================
;; VOTING TRAIT
;; ===========================================
(define-trait voting-trait
  (
    (vote (uint bool uint principal) (response bool uint))
    (get-vote (uint principal) (response (optional {
      support: bool,
      votes: uint
    }) uint))
  )
)
